/**
 * Wardley Map DSL Parser
 *
 * Parses a text format compatible with OnlineWardleyMaps into a structured representation.
 *
 * Note: OnlineWardleyMaps uses [y, x] format where:
 *   y = visibility (0 = bottom/invisible, 1 = top/visible)
 *   x = evolution (0 = genesis, 1 = commodity)
 *
 * We convert to percentage format internally:
 *   y_pct = y * 100 (visibility)
 *   x_pct = x * 100 (evolution)
 */

/**
 * Parse a Wardley Map DSL string into structured data
 * @param {string} text - The DSL text
 * @returns {{ title: string|null, components: Array, edges: Array, errors: Array }}
 */
export function parse(text) {
  const lines = text.split('\n')
  const result = {
    title: null,
    components: [],
    edges: [],
    errors: []
  }

  // Map component names to their data for edge resolution
  const componentMap = new Map()

  // Evolve statements are resolved after all components are parsed, since the
  // statement may appear before or after the component it refers to.
  const evolveStatements = []

  for (let i = 0; i < lines.length; i++) {
    const lineNum = i + 1
    const line = lines[i].trim()

    // Skip empty lines and comments
    if (!line || line.startsWith('//') || line.startsWith('#')) {
      continue
    }

    try {
      // Title
      if (line.startsWith('title ')) {
        result.title = line.slice(6).trim()
        continue
      }

      // Anchor (user/customer node)
      const anchorMatch = line.match(/^anchor\s+(.+?)\s+\[([0-9.]+),\s*([0-9.]+)\]/)
      if (anchorMatch) {
        const [, name, y, x] = anchorMatch
        const component = {
          name: name.trim(),
          type: 'anchor',
          y_pct: parseFloat(y) * 100,
          x_pct: parseFloat(x) * 100,
          label: null
        }
        result.components.push(component)
        componentMap.set(component.name, component)
        continue
      }

      // Component with optional label
      const componentMatch = line.match(/^component\s+(.+?)\s+\[([0-9.]+),\s*([0-9.]+)\](?:\s+label\s+\[([0-9.-]+),\s*([0-9.-]+)\])?/)
      if (componentMatch) {
        const [, name, y, x, labelX, labelY] = componentMatch
        const component = {
          name: name.trim(),
          type: 'component',
          y_pct: parseFloat(y) * 100,
          x_pct: parseFloat(x) * 100,
          label: labelX !== undefined ? { x: parseFloat(labelX), y: parseFloat(labelY) } : null
        }
        result.components.push(component)
        componentMap.set(component.name, component)
        continue
      }

      // Edge (dependency): Source->Target or Source->Target; comment
      const edgeMatch = line.match(/^(.+?)->(.+?)(?:;.*)?$/)
      if (edgeMatch) {
        const [, source, targetPart] = edgeMatch
        const target = targetPart.split(';')[0].trim()
        result.edges.push({
          source: source.trim(),
          target: target
        })
        continue
      }

      // Evolve statement: `evolve <Component Name> <evolution 0-1>`
      const evolveMatch = line.match(/^evolve\s+(.+?)\s+([0-9.]+)\s*$/)
      if (evolveMatch) {
        const [, name, evo] = evolveMatch
        evolveStatements.push({ name: name.trim(), x_pct: parseFloat(evo) * 100 })
        continue
      }

      // Annotation (for future use)
      if (line.startsWith('annotation ') || line.startsWith('annotations ')) {
        // TODO: implement annotations
        continue
      }

      // Note (for future use)
      if (line.startsWith('note ')) {
        // TODO: implement notes
        continue
      }

      // Style (for future use)
      if (line.startsWith('style ')) {
        // TODO: implement styles
        continue
      }

      // Unknown line - add as warning
      result.errors.push({ line: lineNum, message: `Unknown syntax: ${line}` })

    } catch (e) {
      result.errors.push({ line: lineNum, message: e.message })
    }
  }

  // Resolve evolve statements onto their components (target evolution as %).
  for (const { name, x_pct } of evolveStatements) {
    const component = componentMap.get(name)
    if (component) {
      component.evolve_x = x_pct
    } else {
      result.errors.push({ message: `Evolve target "${name}" not found` })
    }
  }

  return result
}

/**
 * Read a node's movement target (evolution %) from metadata, or null.
 * Tolerates numeric or string values.
 * @param {object} node
 * @returns {number|null}
 */
function evolveTarget(node) {
  const raw = node?.metadata?.evolve_x ?? node?.evolve_x
  if (raw === undefined || raw === null || raw === '') return null
  const n = typeof raw === 'number' ? raw : parseFloat(raw)
  return Number.isFinite(n) ? n : null
}

/**
 * Generate DSL text from nodes and edges
 * @param {{ nodes: Array, edges: Array, title?: string }} data
 * @returns {string}
 */
export function generate(data) {
  const lines = []

  // Title
  if (data.title) {
    lines.push(`title ${data.title}`)
    lines.push('')
  }

  // Sort nodes by visibility (y_pct) descending, then by evolution (x_pct)
  const sortedNodes = [...data.nodes].sort((a, b) => {
    if (b.y_pct !== a.y_pct) return b.y_pct - a.y_pct
    return a.x_pct - b.x_pct
  })

  // Components
  for (const node of sortedNodes) {
    const y = (node.y_pct / 100).toFixed(2)
    const x = (node.x_pct / 100).toFixed(2)
    const type = node.metadata?.type === 'anchor' ? 'anchor' : 'component'
    lines.push(`${type} ${node.text} [${y}, ${x}]`)
  }

  if (data.edges.length > 0) {
    lines.push('')
  }

  // Evolve statements (movement targets), emitted after components.
  const evolveLines = []
  for (const node of sortedNodes) {
    const evolveX = evolveTarget(node)
    if (evolveX !== null) {
      evolveLines.push(`evolve ${node.text} ${(evolveX / 100).toFixed(2)}`)
    }
  }

  if (evolveLines.length > 0) {
    if (data.edges.length === 0) lines.push('')
    lines.push(...evolveLines)
  }

  // Build a map of node IDs to names for edge generation
  const nodeIdToName = new Map()
  for (const node of data.nodes) {
    nodeIdToName.set(node.id, node.text)
  }

  // Edges
  for (const edge of data.edges) {
    const sourceName = nodeIdToName.get(edge.source_id)
    const targetName = nodeIdToName.get(edge.target_id)
    if (sourceName && targetName) {
      lines.push(`${sourceName}->${targetName}`)
    }
  }

  return lines.join('\n')
}

/**
 * Validate that all edge references exist in components
 * @param {{ components: Array, edges: Array }} parsed
 * @returns {Array} - Array of error objects
 */
export function validate(parsed) {
  const errors = []
  const componentNames = new Set(parsed.components.map(c => c.name))

  for (const edge of parsed.edges) {
    if (!componentNames.has(edge.source)) {
      errors.push({ message: `Edge source "${edge.source}" not found` })
    }
    if (!componentNames.has(edge.target)) {
      errors.push({ message: `Edge target "${edge.target}" not found` })
    }
  }

  return errors
}
