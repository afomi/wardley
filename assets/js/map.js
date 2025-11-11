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

  // Vertical guide lines at 25%, 50%, 75%
  const innerW = width - 40
  const innerH = height - 60
  const xAt = p => 20 + p * innerW
  const guides = [0.25, 0.5, 0.75]
  svg
    .append("g")
    .attr("stroke", "#e2e8f0") // slate-200
    .attr("stroke-dasharray", "4,4")
    .selectAll("line")
    .data(guides)
    .join("line")
    .attr("x1", d => xAt(d))
    .attr("x2", d => xAt(d))
    .attr("y1", 20)
    .attr("y2", 20 + innerH)
}

function pxFromPercent(width, height, x_pct, y_pct) {
  const x = 20 + (x_pct / 100) * (width - 40)
  const y = 20 + (1 - y_pct / 100) * (height - 60)
  return { x, y }
}

export function initMapPage() {
  const container = document.querySelector("#wardley-map")
  const canvasWrap = document.querySelector("#map-canvas")
  if (!container || !canvasWrap) return

  // Create SVG
  const width = canvasWrap.clientWidth
  const height = canvasWrap.clientHeight
  const svg = d3
    .select(canvasWrap)
    .append("svg")
    .attr("viewBox", [0, 0, width, height])
    .classed("w-full h-full", true)
    .style("cursor", "crosshair")

  drawAxes(svg, width, height)

  const state = {
    nodes: [],
    edges: [],
    linkMode: false,
    linkSource: null,
    selected: null
  }

  const gLinks = svg.append("g").attr("stroke", "#94a3b8").attr("stroke-width", 1.5).attr("stroke-opacity", 0.7)
  const gNodes = svg.append("g")
  const gOverlay = svg.append("g").style("pointer-events", "none")
  const previewLine = gOverlay
    .append("line")
    .attr("stroke", "#94a3b8")
    .attr("stroke-dasharray", "4,4")
    .attr("stroke-width", 1.5)
    .attr("opacity", 0)

  function showPreviewFromSource(source) {
    const { x, y } = pxFromPercent(width, height, source.x_pct, source.y_pct)
    previewLine
      .attr("x1", x)
      .attr("y1", y)
      .attr("x2", x)
      .attr("y2", y)
      .attr("opacity", 1)

    svg.on("mousemove.preview", (event) => {
      const { x_pct, y_pct } = percentFromEvent(svg.node(), event)
      const p = pxFromPercent(width, height, x_pct, y_pct)
      previewLine.attr("x2", p.x).attr("y2", p.y)
    })
  }

  function hidePreview() {
    previewLine.attr("opacity", 0)
    svg.on("mousemove.preview", null)
  }

  const lineBadge = document.getElementById("line-mode-badge")
  function setLinkMode(on) {
    state.linkMode = on
    state.linkSource = null
    svg.style("cursor", state.linkMode ? "alias" : "crosshair")
    if (!on) hidePreview()
    if (lineBadge) lineBadge.classList.toggle("hidden", !on)
  }

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
    // ensure label updates immediately when text changes
    nodeAll
      .select("text")
      .text(d => d.text)

    nodeAll
      .select("circle")
      .attr("stroke", d => (state.selected && state.selected.id === d.id ? "#0ea5e9" : "#cbd5e1"))
      .attr("stroke-width", d => (state.selected && state.selected.id === d.id ? 2.5 : 1.5))

    nodeAll
      .on("click", (event, d) => {
        event.stopPropagation()
        if (state.linkMode) {
          if (state.linkSource && state.linkSource.id !== d.id) {
            api("POST", "/api/edges", { source_id: state.linkSource.id, target_id: d.id })
              .then(edge => {
                state.edges.push(edge)
                setLinkMode(false)
                render()
              })
              .catch(console.error)
          } else {
            state.linkSource = d
            showPreviewFromSource(d)
          }
        } else if (event.detail === 2) {
          startNodeLabelEdit(d)
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
        } else {
          setSelected(d)
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

  // Drawer handling
  const drawerEmpty = document.getElementById("drawer-empty")
  const form = document.getElementById("node-form")
  const idEl = document.getElementById("node-id")
  const textEl = document.getElementById("node-text")
  const xEl = document.getElementById("node-x")
  const yEl = document.getElementById("node-y")
  const metaEl = document.getElementById("node-metadata")
  const delBtn = document.getElementById("node-delete")

  function setSelected(node) {
    state.selected = node
    updateDrawer()
    render()
  }

  function updateDrawer() {
    if (!form || !drawerEmpty) return
    if (!state.selected) {
      form.classList.add("hidden")
      drawerEmpty.classList.remove("hidden")
      return
    }
    drawerEmpty.classList.add("hidden")
    form.classList.remove("hidden")
    idEl.value = state.selected.id
    textEl.value = state.selected.text || ""
    xEl.value = Number(state.selected.x_pct).toFixed(1)
    yEl.value = Number(state.selected.y_pct).toFixed(1)
    metaEl.value = JSON.stringify(state.selected.metadata || {}, null, 2)
  }

  if (form) {
    form.addEventListener("submit", e => {
      e.preventDefault()
      if (!state.selected) return
      const payload = {
        text: textEl.value.trim() || "Node",
        x_pct: Math.max(0, Math.min(100, parseFloat(xEl.value) || 0)),
        y_pct: Math.max(0, Math.min(100, parseFloat(yEl.value) || 0))
      }
      try {
        const m = metaEl.value.trim()
        payload.metadata = m ? JSON.parse(m) : {}
      } catch (_e) {
        alert("Invalid JSON in metadata")
        return
      }
      api("PATCH", `/api/nodes/${state.selected.id}`, payload)
        .then(updated => {
          Object.assign(state.selected, updated)
          render()
          updateDrawer()
        })
        .catch(console.error)
    })
  }

  if (delBtn) {
    delBtn.addEventListener("click", () => {
      if (!state.selected) return
      if (!confirm("Delete this node?")) return
      api("DELETE", `/api/nodes/${state.selected.id}`)
        .then(() => {
          state.nodes = state.nodes.filter(n => n.id !== state.selected.id)
          state.edges = state.edges.filter(e => e.source_id !== state.selected.id && e.target_id !== state.selected.id)
          state.selected = null
          render()
          updateDrawer()
        })
        .catch(console.error)
    })
  }

  function startNodeLabelEdit(node) {
    const { x, y } = pxFromPercent(width, height, node.x_pct, node.y_pct)
    const input = document.createElement("input")
    input.type = "text"
    input.value = node.text || ""
    input.placeholder = "Node"
    input.className = "absolute z-10 px-2 py-1 text-sm rounded border border-slate-300 bg-white text-slate-900 shadow-sm focus:outline-none focus:ring focus:ring-slate-200"
    input.style.left = `${x + 14}px`
    input.style.top = `${y - 10}px`
    input.style.minWidth = "120px"

    const save = () => {
      const newText = input.value.trim() || "Node"
      node.text = newText
      api("PATCH", `/api/nodes/${node.id}`, { text: node.text }).catch(console.error)
      container.removeChild(input)
      render()
    }

    const cancel = () => {
      container.removeChild(input)
      render()
    }

    input.addEventListener("keydown", e => {
      if (e.key === "Enter") {
        e.preventDefault()
        save()
      } else if (e.key === "Escape") {
        e.preventDefault()
        cancel()
      }
    })
    input.addEventListener("blur", save)

    canvasWrap.appendChild(input)
    input.focus()
    input.select()
  }

  // Click to add node
  svg.on("click", event => {
    if (state.linkMode) return
    const { x_pct, y_pct } = percentFromEvent(svg.node(), event)
    api("POST", "/api/nodes", { x_pct, y_pct, text: "Node" })
      .then(node => {
        state.nodes.push(node)
        render()
        startNodeLabelEdit(node)
      })
      .catch(console.error)
  })

  // Keyboard: toggle line mode; ignore repeats and typing targets
  function isTypingTarget(e) {
    const t = e.target
    return t && (t.tagName === "INPUT" || t.tagName === "TEXTAREA" || t.isContentEditable)
  }

  window.addEventListener("keydown", e => {
    if (e.repeat || isTypingTarget(e)) return
    const k = e.key.toLowerCase()
    if (k === "e" || k === "l") {
      setLinkMode(!state.linkMode)
      e.preventDefault()
    } else if (k === "escape") {
      setLinkMode(false)
      e.preventDefault()
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
