import * as d3 from "d3"

const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

function percentFromEvent(svgEl, event) {
  const rect = svgEl.getBoundingClientRect()
  const x = (event.clientX - rect.left) / rect.width
  const y = (event.clientY - rect.top) / rect.height
  return { x_pct: Math.max(0, Math.min(100, x * 100)), y_pct: Math.max(0, Math.min(100, (1 - y) * 100)) }
}

async function api(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: { "content-type": "application/json", "x-csrf-token": csrfToken() },
    body: body ? JSON.stringify(body) : undefined
  })
  if (!res.ok) throw new Error(`API ${method} ${url} failed`)
  if (res.status === 204) return null
  return res.json()
}

function drawAxes(svg, width, height) {
  // X axis labels
  const xLabels = ["genesis", "custom", "product", "commodity"]
  svg
    .append("g")
    .attr("transform", `translate(0, ${height - 24})`)
    .selectAll("text")
    .data(xLabels)
    .join("text")
    .attr("x", (_, i) => (i / 3) * (width - 40) + 20)
    .attr("y", 0)
    .attr("fill", "#64748b") // slate-500
    .style("font", "12px ui-sans-serif, system-ui, sans-serif")
    .text(d => d)

  // Y axis label
  svg
    .append("text")
    .attr("x", 12)
    .attr("y", 20)
    .attr("fill", "#64748b")
    .style("font", "12px ui-sans-serif, system-ui, sans-serif")
    .text("users / visibility")

  // Border
  svg
    .append("rect")
    .attr("x", 20)
    .attr("y", 20)
    .attr("width", width - 40)
    .attr("height", height - 60)
    .attr("fill", "none")
    .attr("stroke", "#cbd5e1") // slate-300
}

function pxFromPercent(width, height, x_pct, y_pct) {
  const x = 20 + (x_pct / 100) * (width - 40)
  const y = 20 + (1 - y_pct / 100) * (height - 60)
  return { x, y }
}

export function initMapPage() {
  const container = document.querySelector("#wardley-map")
  if (!container) return

  // Create SVG
  const width = container.clientWidth
  const height = container.clientHeight
  const svg = d3
    .select(container)
    .append("svg")
    .attr("viewBox", [0, 0, width, height])
    .classed("w-full h-full", true)
    .style("cursor", "crosshair")

  drawAxes(svg, width, height)

  const state = {
    nodes: [],
    edges: [],
    linkMode: false,
    linkSource: null
  }

  const gLinks = svg.append("g").attr("stroke", "#94a3b8").attr("stroke-width", 1.5).attr("stroke-opacity", 0.7)
  const gNodes = svg.append("g")

  function render() {
    // Links
    const linkSel = gLinks.selectAll("line").data(state.edges, d => d.id)
    linkSel.join(
      enter =>
        enter
          .append("line")
          .attr("x1", d => pxFromPercent(width, height, getNode(d.source_id).x_pct, getNode(d.source_id).y_pct).x)
          .attr("y1", d => pxFromPercent(width, height, getNode(d.source_id).x_pct, getNode(d.source_id).y_pct).y)
          .attr("x2", d => pxFromPercent(width, height, getNode(d.target_id).x_pct, getNode(d.target_id).y_pct).x)
          .attr("y2", d => pxFromPercent(width, height, getNode(d.target_id).x_pct, getNode(d.target_id).y_pct).y)
          .on("click", (event, d) => {
            event.stopPropagation()
            if (event.altKey || event.metaKey || event.shiftKey) {
              const curr = JSON.stringify(d.metadata || {}, null, 2)
              const input = window.prompt("Edit edge metadata (JSON)", curr)
              if (input != null) {
                try {
                  const metadata = input.trim() === "" ? {} : JSON.parse(input)
                  api("PATCH", `/api/edges/${d.id}`, { metadata }).then(updated => {
                    Object.assign(d, updated)
                    render()
                  })
                } catch (e) {
                  console.error(e)
                  window.alert("Invalid JSON")
                }
              }
            }
          }),
      update =>
        update
          .attr("x1", d => pxFromPercent(width, height, getNode(d.source_id).x_pct, getNode(d.source_id).y_pct).x)
          .attr("y1", d => pxFromPercent(width, height, getNode(d.source_id).x_pct, getNode(d.source_id).y_pct).y)
          .attr("x2", d => pxFromPercent(width, height, getNode(d.target_id).x_pct, getNode(d.target_id).y_pct).x)
          .attr("y2", d => pxFromPercent(width, height, getNode(d.target_id).x_pct, getNode(d.target_id).y_pct).y),
      exit => exit.remove()
    )

    // Nodes
    const nodeSel = gNodes.selectAll("g.node").data(state.nodes, d => d.id)
    const nodeEnter = nodeSel.enter().append("g").attr("class", "node").style("cursor", "pointer")

    nodeEnter
      .append("circle")
      .attr("r", 10)
      .attr("fill", "#0f172a")
      .attr("stroke", "#cbd5e1")
      .attr("stroke-width", 1.5)

    nodeEnter
      .append("text")
      .attr("x", 14)
      .attr("y", 4)
      .attr("fill", "#334155")
      .style("font", "12px ui-sans-serif, system-ui, sans-serif")
      .text(d => d.text)

    const nodeAll = nodeEnter.merge(nodeSel)

    nodeAll
      .attr("transform", d => {
        const { x, y } = pxFromPercent(width, height, d.x_pct, d.y_pct)
        return `translate(${x}, ${y})`
      })
      .on("click", (event, d) => {
        event.stopPropagation()
        if (state.linkMode) {
          if (state.linkSource && state.linkSource.id !== d.id) {
            api("POST", "/api/edges", { source_id: state.linkSource.id, target_id: d.id })
              .then(edge => {
                state.edges.push(edge)
                state.linkMode = false
                state.linkSource = null
                render()
              })
              .catch(console.error)
          } else {
            state.linkSource = d
          }
        } else if (event.detail === 2) {
          const label = window.prompt("Edit label", d.text)
          if (label != null) {
            d.text = label
            api("PATCH", `/api/nodes/${d.id}`, { text: d.text }).catch(console.error)
            render()
          }
        } else if (event.altKey || event.metaKey) {
          const curr = JSON.stringify(d.metadata || {}, null, 2)
          const input = window.prompt("Edit node metadata (JSON)", curr)
          if (input != null) {
            try {
              const metadata = input.trim() === "" ? {} : JSON.parse(input)
              d.metadata = metadata
              api("PATCH", `/api/nodes/${d.id}`, { metadata }).catch(console.error)
              render()
            } catch (e) {
              console.error(e)
              window.alert("Invalid JSON")
            }
          }
        }
      })
      .call(
        d3
          .drag()
          .on("drag", (event, d) => {
            const rect = svg.node().getBoundingClientRect()
            const x_pct = Math.max(0, Math.min(100, ((event.x - 20) / (rect.width - 40)) * 100))
            const y_pct = Math.max(0, Math.min(100, (1 - (event.y - 20) / (rect.height - 60)) * 100))
            d.x_pct = x_pct
            d.y_pct = y_pct
            render()
          })
          .on("end", (_event, d) => {
            api("PATCH", `/api/nodes/${d.id}`, { x_pct: d.x_pct, y_pct: d.y_pct }).catch(console.error)
          })
      )

    nodeSel.exit().remove()
  }

  function getNode(id) {
    return state.nodes.find(n => n.id === id)
  }

  // Click to add node
  svg.on("click", event => {
    const { x_pct, y_pct } = percentFromEvent(svg.node(), event)
    const text = window.prompt("Node label:", "Node") || "Node"
    api("POST", "/api/nodes", { x_pct, y_pct, text })
      .then(node => {
        state.nodes.push(node)
        render()
      })
      .catch(console.error)
  })

  // Keyboard: E toggles edge mode
  window.addEventListener("keydown", e => {
    if (e.key.toLowerCase() === "e") {
      state.linkMode = !state.linkMode
      state.linkSource = null
      svg.style("cursor", state.linkMode ? "alias" : "crosshair")
    }
  })

  // Load existing
  api("GET", "/api/map")
    .then(({ nodes, edges }) => {
      state.nodes = nodes
      state.edges = edges
      render()
    })
    .catch(console.error)
}

// Auto-init on presence
document.addEventListener("DOMContentLoaded", initMapPage)
