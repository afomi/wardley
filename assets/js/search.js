/**
 * Search Modal Functionality
 *
 * Provides a command palette-style search modal with:
 * - Keyboard shortcut (Ctrl+K / Cmd+K)
 * - Real-time search results from API
 * - Navigation to full results page
 */

let searchTimeout = null
let currentQuery = ''

/**
 * Open the search modal and focus the input
 */
window.openSearchModal = function() {
  const modal = document.getElementById('search-modal')
  const input = document.getElementById('search-input')

  if (modal && input) {
    modal.classList.remove('hidden')
    input.focus()
    input.select()
  }
}

/**
 * Close the search modal and clear results
 */
window.closeSearchModal = function() {
  const modal = document.getElementById('search-modal')
  const input = document.getElementById('search-input')
  const results = document.getElementById('search-results')
  const viewAll = document.getElementById('search-view-all')

  if (modal) {
    modal.classList.add('hidden')
  }

  if (input) {
    input.value = ''
  }

  if (results) {
    results.innerHTML = '<p class="px-3 py-8 text-center text-sm text-slate-500">Type to search...</p>'
  }

  if (viewAll) {
    viewAll.classList.add('hidden')
    viewAll.href = '/search'
  }

  currentQuery = ''
}

/**
 * Handle search input with debouncing
 */
window.handleSearchInput = function(value) {
  currentQuery = value.trim()

  // Clear any pending search
  if (searchTimeout) {
    clearTimeout(searchTimeout)
  }

  if (currentQuery.length < 1) {
    const results = document.getElementById('search-results')
    const viewAll = document.getElementById('search-view-all')
    if (results) {
      results.innerHTML = '<p class="px-3 py-8 text-center text-sm text-slate-500">Type to search...</p>'
    }
    if (viewAll) {
      viewAll.classList.add('hidden')
    }
    return
  }

  // Debounce: wait 200ms before searching
  searchTimeout = setTimeout(() => {
    performSearch(currentQuery)
  }, 200)
}

/**
 * Perform the actual search API call
 */
async function performSearch(query) {
  const results = document.getElementById('search-results')
  const viewAll = document.getElementById('search-view-all')

  if (!results) return

  // Show loading state
  results.innerHTML = '<p class="px-3 py-4 text-center text-sm text-slate-500">Searching...</p>'

  try {
    const response = await fetch(`/api/search?q=${encodeURIComponent(query)}&limit=5`)
    const data = await response.json()

    renderResults(data, query)

    // Update "View all" link
    if (viewAll) {
      viewAll.href = `/search?q=${encodeURIComponent(query)}`
      const hasResults = data.nodes?.length > 0 || data.maps?.length > 0 || data.personas?.length > 0
      viewAll.classList.toggle('hidden', !hasResults)
    }
  } catch (error) {
    console.error('Search error:', error)
    results.innerHTML = '<p class="px-3 py-4 text-center text-sm text-red-500">Search failed. Please try again.</p>'
  }
}

/**
 * Render search results grouped by type
 */
function renderResults(data, query) {
  const results = document.getElementById('search-results')
  if (!results) return

  const hasNodes = data.nodes && data.nodes.length > 0
  const hasMaps = data.maps && data.maps.length > 0
  const hasPersonas = data.personas && data.personas.length > 0

  if (!hasNodes && !hasMaps && !hasPersonas) {
    results.innerHTML = `<p class="px-3 py-8 text-center text-sm text-slate-500">No results for "${escapeHtml(query)}"</p>`
    return
  }

  let html = ''

  // Nodes section
  if (hasNodes) {
    html += `
      <div class="mb-2">
        <h3 class="px-3 py-1 text-xs font-semibold text-slate-500 uppercase tracking-wider">Components</h3>
        ${data.nodes.map(node => `
          <a
            href="/map?node=${node.id}"
            class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition cursor-pointer"
          >
            <span class="flex-shrink-0 w-8 h-8 rounded-lg bg-blue-100 dark:bg-blue-900/50 flex items-center justify-center">
              <svg class="w-4 h-4 text-blue-600 dark:text-blue-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-slate-900 dark:text-white truncate">${escapeHtml(node.text)}</p>
              <p class="text-xs text-slate-500 truncate">${escapeHtml(node.map_name)} · ${node.metadata?.category || 'No category'}</p>
            </div>
          </a>
        `).join('')}
      </div>
    `
  }

  // Maps section
  if (hasMaps) {
    html += `
      <div class="mb-2">
        <h3 class="px-3 py-1 text-xs font-semibold text-slate-500 uppercase tracking-wider">Maps</h3>
        ${data.maps.map(map => `
          <a
            href="/map?id=${map.id}"
            class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition cursor-pointer"
          >
            <span class="flex-shrink-0 w-8 h-8 rounded-lg bg-green-100 dark:bg-green-900/50 flex items-center justify-center">
              <svg class="w-4 h-4 text-green-600 dark:text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
              </svg>
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-slate-900 dark:text-white truncate">${escapeHtml(map.name)}</p>
              <p class="text-xs text-slate-500">${map.node_count} components</p>
            </div>
          </a>
        `).join('')}
      </div>
    `
  }

  // Personas section
  if (hasPersonas) {
    html += `
      <div class="mb-2">
        <h3 class="px-3 py-1 text-xs font-semibold text-slate-500 uppercase tracking-wider">Personas</h3>
        ${data.personas.map(persona => `
          <a
            href="/personas/${persona.id}"
            class="flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition cursor-pointer"
          >
            <span class="flex-shrink-0 w-8 h-8 rounded-lg bg-purple-100 dark:bg-purple-900/50 flex items-center justify-center">
              <svg class="w-4 h-4 text-purple-600 dark:text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-slate-900 dark:text-white truncate">
                ${escapeHtml(persona.name)}
                ${persona.is_default ? '<span class="ml-1 px-1.5 py-0.5 text-xs bg-slate-200 dark:bg-slate-700 rounded">Default</span>' : ''}
              </p>
              <p class="text-xs text-slate-500 truncate">${escapeHtml(persona.description || 'No description')}</p>
            </div>
          </a>
        `).join('')}
      </div>
    `
  }

  results.innerHTML = html
}

/**
 * Escape HTML to prevent XSS
 */
function escapeHtml(text) {
  if (!text) return ''
  const div = document.createElement('div')
  div.textContent = text
  return div.innerHTML
}

/**
 * Initialize keyboard shortcuts
 */
document.addEventListener('DOMContentLoaded', () => {
  // Ctrl+K / Cmd+K to open search
  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault()
      window.openSearchModal()
    }
  })

  // Escape to close search modal
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      const modal = document.getElementById('search-modal')
      if (modal && !modal.classList.contains('hidden')) {
        window.closeSearchModal()
      }
    }
  })

  // Enter to navigate to first result or full search page
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      const modal = document.getElementById('search-modal')
      if (modal && !modal.classList.contains('hidden')) {
        const firstResult = document.querySelector('#search-results a')
        if (firstResult) {
          window.location.href = firstResult.href
        } else if (currentQuery) {
          window.location.href = `/search?q=${encodeURIComponent(currentQuery)}`
        }
      }
    }
  })
})
