/**
 * GitHub Sync Module
 *
 * Provides client-side sync of Wardley Map DSL code to a GitHub repository.
 * Uses GitHub's REST API with a Personal Access Token stored in localStorage.
 */

const STORAGE_KEY = 'wardley_github_config'

/**
 * Get stored GitHub configuration
 * @returns {{ token: string, owner: string, repo: string, branch: string, path: string } | null}
 */
export function getConfig() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY)
    return stored ? JSON.parse(stored) : null
  } catch (e) {
    console.error('Failed to parse GitHub config:', e)
    return null
  }
}

/**
 * Save GitHub configuration
 * @param {{ token: string, owner: string, repo: string, branch: string, path: string }} config
 */
export function saveConfig(config) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(config))
}

/**
 * Clear GitHub configuration
 */
export function clearConfig() {
  localStorage.removeItem(STORAGE_KEY)
}

/**
 * Check if GitHub sync is configured
 * @returns {boolean}
 */
export function isConfigured() {
  const config = getConfig()
  return !!(config?.token && config?.owner && config?.repo && config?.path)
}

/**
 * Make an authenticated GitHub API request
 * @param {string} endpoint - API endpoint (without base URL)
 * @param {object} options - Fetch options
 * @returns {Promise<Response>}
 */
async function githubFetch(endpoint, options = {}) {
  const config = getConfig()
  if (!config?.token) {
    throw new Error('GitHub token not configured')
  }

  const url = endpoint.startsWith('https://')
    ? endpoint
    : `https://api.github.com${endpoint}`

  const response = await fetch(url, {
    ...options,
    headers: {
      'Accept': 'application/vnd.github.v3+json',
      'Authorization': `Bearer ${config.token}`,
      'X-GitHub-Api-Version': '2022-11-28',
      ...options.headers
    }
  })

  return response
}

/**
 * Get file content and SHA from GitHub
 * @param {string} owner - Repository owner
 * @param {string} repo - Repository name
 * @param {string} path - File path
 * @param {string} branch - Branch name
 * @returns {Promise<{ content: string, sha: string } | null>}
 */
export async function getFile(owner, repo, path, branch = 'main') {
  try {
    const response = await githubFetch(
      `/repos/${owner}/${repo}/contents/${path}?ref=${branch}`
    )

    if (response.status === 404) {
      return null // File doesn't exist yet
    }

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.message || 'Failed to fetch file')
    }

    const data = await response.json()
    const content = atob(data.content.replace(/\n/g, ''))
    return { content, sha: data.sha }
  } catch (e) {
    if (e.message?.includes('404')) {
      return null
    }
    throw e
  }
}

/**
 * Create or update a file on GitHub
 * @param {string} owner - Repository owner
 * @param {string} repo - Repository name
 * @param {string} path - File path
 * @param {string} content - File content
 * @param {string} message - Commit message
 * @param {string} branch - Branch name
 * @param {string} [sha] - SHA of existing file (for updates)
 * @returns {Promise<{ sha: string, commit: object }>}
 */
export async function putFile(owner, repo, path, content, message, branch = 'main', sha = null) {
  const body = {
    message,
    content: btoa(content),
    branch
  }

  if (sha) {
    body.sha = sha
  }

  const response = await githubFetch(
    `/repos/${owner}/${repo}/contents/${path}`,
    {
      method: 'PUT',
      body: JSON.stringify(body)
    }
  )

  if (!response.ok) {
    const error = await response.json()
    throw new Error(error.message || 'Failed to save file')
  }

  return response.json()
}

/**
 * Push map code to GitHub
 * @param {string} code - DSL code content
 * @param {string} mapName - Name of the map (for commit message)
 * @returns {Promise<{ success: boolean, message: string, url?: string }>}
 */
export async function pushToGitHub(code, mapName) {
  const config = getConfig()
  if (!isConfigured()) {
    return { success: false, message: 'GitHub sync not configured' }
  }

  try {
    // Get existing file to get SHA (needed for updates)
    const existing = await getFile(config.owner, config.repo, config.path, config.branch || 'main')

    // Check if content is the same
    if (existing && existing.content === code) {
      return { success: true, message: 'Already up to date' }
    }

    // Create or update file
    const message = existing
      ? `Update ${mapName || 'map'}`
      : `Add ${mapName || 'map'}`

    const result = await putFile(
      config.owner,
      config.repo,
      config.path,
      code,
      message,
      config.branch || 'main',
      existing?.sha
    )

    const fileUrl = `https://github.com/${config.owner}/${config.repo}/blob/${config.branch || 'main'}/${config.path}`

    return {
      success: true,
      message: existing ? 'Pushed changes to GitHub' : 'Created file on GitHub',
      url: fileUrl
    }
  } catch (e) {
    console.error('GitHub push failed:', e)
    return { success: false, message: e.message || 'Push failed' }
  }
}

/**
 * Pull map code from GitHub
 * @returns {Promise<{ success: boolean, message: string, content?: string }>}
 */
export async function pullFromGitHub() {
  const config = getConfig()
  if (!isConfigured()) {
    return { success: false, message: 'GitHub sync not configured' }
  }

  try {
    const file = await getFile(config.owner, config.repo, config.path, config.branch || 'main')

    if (!file) {
      return { success: false, message: 'File not found on GitHub' }
    }

    return {
      success: true,
      message: 'Pulled from GitHub',
      content: file.content
    }
  } catch (e) {
    console.error('GitHub pull failed:', e)
    return { success: false, message: e.message || 'Pull failed' }
  }
}

/**
 * Validate GitHub token by making a test API call
 * @param {string} token - GitHub Personal Access Token
 * @returns {Promise<{ valid: boolean, user?: string, message?: string }>}
 */
export async function validateToken(token) {
  try {
    const response = await fetch('https://api.github.com/user', {
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'Authorization': `Bearer ${token}`,
        'X-GitHub-Api-Version': '2022-11-28'
      }
    })

    if (!response.ok) {
      return { valid: false, message: 'Invalid token' }
    }

    const user = await response.json()
    return { valid: true, user: user.login }
  } catch (e) {
    return { valid: false, message: e.message || 'Validation failed' }
  }
}

/**
 * List repositories for the authenticated user
 * @returns {Promise<Array<{ name: string, full_name: string, default_branch: string }>>}
 */
export async function listRepos() {
  const response = await githubFetch('/user/repos?sort=updated&per_page=100')

  if (!response.ok) {
    throw new Error('Failed to list repositories')
  }

  const repos = await response.json()
  return repos.map(r => ({
    name: r.name,
    full_name: r.full_name,
    default_branch: r.default_branch
  }))
}

/**
 * List branches for a repository
 * @param {string} owner - Repository owner
 * @param {string} repo - Repository name
 * @returns {Promise<Array<{ name: string }>>}
 */
export async function listBranches(owner, repo) {
  const response = await githubFetch(`/repos/${owner}/${repo}/branches`)

  if (!response.ok) {
    throw new Error('Failed to list branches')
  }

  return response.json()
}
