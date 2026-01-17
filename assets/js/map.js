import * as THREE from "three"
import * as dsl from "./wardley-dsl"
import * as github from "./github-sync"

const csrfToken = () => document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

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

// Map boundaries (in world units)
const MAP_WIDTH = 100
const MAP_HEIGHT = 100
const MAP_PADDING = 5

// Convert percentage coordinates to world coordinates
function worldFromPercent(x_pct, y_pct) {
  return {
    x: (x_pct / 100) * MAP_WIDTH,
    y: (y_pct / 100) * MAP_HEIGHT
  }
}

// Convert world coordinates to percentage
function percentFromWorld(x, y) {
  return {
    x_pct: Math.max(0, Math.min(100, (x / MAP_WIDTH) * 100)),
    y_pct: Math.max(0, Math.min(100, (y / MAP_HEIGHT) * 100))
  }
}

export function initMapPage() {
  const container = document.querySelector("#wardley-map")
  const canvasWrap = document.querySelector("#map-canvas")
  if (!container || !canvasWrap) return

  // Prevent multiple initializations
  if (canvasWrap.querySelector("canvas")) return

  const width = canvasWrap.clientWidth || 800
  const height = canvasWrap.clientHeight || 600

  if (width === 0 || height === 0) {
    setTimeout(initMapPage, 50)
    return
  }

  // Three.js setup
  const scene = new THREE.Scene()
  scene.background = new THREE.Color(0xf8fafc) // slate-50

  // Perspective camera for future 3D, but positioned for 2D view
  const camera = new THREE.PerspectiveCamera(60, width / height, 0.1, 1000)
  camera.position.set(MAP_WIDTH / 2, MAP_HEIGHT / 2, 100)
  camera.lookAt(MAP_WIDTH / 2, MAP_HEIGHT / 2, 0)

  // Renderer
  const renderer = new THREE.WebGLRenderer({ antialias: true })
  renderer.setSize(width, height)
  renderer.setPixelRatio(window.devicePixelRatio)
  canvasWrap.appendChild(renderer.domElement)

  // Layer stack model - unified state for all layers
  // The first layer (index 0) is always the active/editable layer
  const layerStack = []

  // Interaction state (not part of layer data)
  const interactionState = {
    linkMode: false,
    linkSource: null,
    selected: null
  }

  let lastDeleted = null
  let undoTimer = null

  // Forward declaration for DSL sync
  let syncCodeFromVisual = () => {}

  // Helper to get active layer
  function getActiveLayer() {
    return layerStack[0] || null
  }

  // Helper to get active layer state (for backward compatibility)
  const state = new Proxy({}, {
    get(target, prop) {
      const active = getActiveLayer()
      if (!active) {
        if (prop === 'nodes') return []
        if (prop === 'edges') return []
        if (prop === 'mapTitle') return null
        if (prop === 'mapId') return null
      }
      if (prop === 'nodes') return active?.nodes || []
      if (prop === 'edges') return active?.edges || []
      if (prop === 'mapTitle') return active?.name || null
      if (prop === 'mapId') return active?.mapId || null
      if (prop === 'linkMode') return interactionState.linkMode
      if (prop === 'linkSource') return interactionState.linkSource
      if (prop === 'selected') return interactionState.selected
      return undefined
    },
    set(target, prop, value) {
      const active = getActiveLayer()
      if (prop === 'nodes' && active) active.nodes = value
      else if (prop === 'edges' && active) active.edges = value
      else if (prop === 'mapTitle' && active) active.name = value
      else if (prop === 'mapId' && active) active.mapId = value
      else if (prop === 'linkMode') interactionState.linkMode = value
      else if (prop === 'linkSource') interactionState.linkSource = value
      else if (prop === 'selected') interactionState.selected = value
      return true
    }
  })

  // Three.js objects
  const nodeGroup = new THREE.Group()
  const edgeGroup = new THREE.Group()
  const gridGroup = new THREE.Group()
  const labelGroup = new THREE.Group()
  const layersGroup = new THREE.Group() // Read-only overlay layers

  scene.add(gridGroup)
  scene.add(layersGroup) // Layers render behind active map
  scene.add(edgeGroup)
  scene.add(nodeGroup)
  scene.add(labelGroup)

  // Node mesh references
  const nodeMeshes = new Map()
  const edgeMeshes = new Map()

  // Layer color palette for overlay layers
  const layerColors = [
    0x8b5cf6, // violet
    0xf59e0b, // amber
    0xef4444, // red
    0x06b6d4, // cyan
    0xec4899, // pink
    0x84cc16, // lime
  ]
  let nextColorIndex = 0

  // Track Three.js groups for each layer
  const layerGroups = new Map() // mapId -> THREE.Group

  // Raycaster for interaction
  const raycaster = new THREE.Raycaster()
  const mouse = new THREE.Vector2()

  // Camera controls state
  let isDraggingCamera = false
  let lastMousePos = { x: 0, y: 0 }
  let targetCameraZ = camera.position.z

  // Draw map grid and axes
  function drawGrid() {
    // Clear previous
    while (gridGroup.children.length > 0) {
      gridGroup.remove(gridGroup.children[0])
    }

    // Border
    const borderMaterial = new THREE.LineBasicMaterial({ color: 0xcbd5e1 })
    const borderGeometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(0, 0, 0),
      new THREE.Vector3(MAP_WIDTH, 0, 0),
      new THREE.Vector3(MAP_WIDTH, MAP_HEIGHT, 0),
      new THREE.Vector3(0, MAP_HEIGHT, 0),
      new THREE.Vector3(0, 0, 0)
    ])
    const border = new THREE.Line(borderGeometry, borderMaterial)
    gridGroup.add(border)

    // Vertical guide lines at 25%, 50%, 75%
    const guideMaterial = new THREE.LineDashedMaterial({
      color: 0xe2e8f0,
      dashSize: 2,
      gapSize: 2
    })

    const guides = [0.25, 0.5, 0.75]
    for (const pct of guides) {
      const x = pct * MAP_WIDTH
      const guideGeometry = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(x, 0, 0),
        new THREE.Vector3(x, MAP_HEIGHT, 0)
      ])
      const guide = new THREE.Line(guideGeometry, guideMaterial)
      guide.computeLineDistances()
      gridGroup.add(guide)
    }
  }

  // Create text labels using canvas sprites
  function createTextSprite(text, fontSize = 14, color = "#64748b") {
    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d")
    canvas.width = 256
    canvas.height = 64

    ctx.fillStyle = color
    ctx.font = `${fontSize}px ui-sans-serif, system-ui, sans-serif`
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText(text, 128, 32)

    const texture = new THREE.CanvasTexture(canvas)
    const material = new THREE.SpriteMaterial({ map: texture, depthTest: false })
    const sprite = new THREE.Sprite(material)
    sprite.scale.set(20, 5, 1)
    return sprite
  }

  function drawAxisLabels() {
    // Clear previous
    while (labelGroup.children.length > 0) {
      labelGroup.remove(labelGroup.children[0])
    }

    // X axis labels at bottom
    const xLabels = ["genesis", "custom", "product", "commodity"]
    for (let i = 0; i < xLabels.length; i++) {
      const sprite = createTextSprite(xLabels[i], 12, "#64748b")
      sprite.position.set((i * 0.25 + 0.125) * MAP_WIDTH, -5, 0)
      labelGroup.add(sprite)
    }

    // Y axis label
    const yLabel = createTextSprite("visibility", 12, "#64748b")
    yLabel.position.set(-10, MAP_HEIGHT / 2, 0)
    labelGroup.add(yLabel)
  }

  // Create a node mesh
  function createNodeMesh(node) {
    const { x, y } = worldFromPercent(node.x_pct, node.y_pct)

    // Node circle
    const geometry = new THREE.CircleGeometry(2, 32)
    const material = new THREE.MeshBasicMaterial({ color: 0x0f172a })
    const mesh = new THREE.Mesh(geometry, material)
    mesh.position.set(x, y, 1)

    // Outline ring
    const ringGeometry = new THREE.RingGeometry(2, 2.4, 32)
    const ringMaterial = new THREE.MeshBasicMaterial({
      color: 0xcbd5e1,
      side: THREE.DoubleSide
    })
    const ring = new THREE.Mesh(ringGeometry, ringMaterial)
    ring.position.set(0, 0, 0.1)
    mesh.add(ring)

    // Label sprite
    const label = createTextSprite(node.text || "Node", 14, "#334155")
    label.position.set(6, 0, 0)
    label.scale.set(15, 4, 1)
    mesh.add(label)

    mesh.userData = { node, ring, label }
    return mesh
  }

  // Update node mesh position and appearance
  function updateNodeMesh(mesh, node) {
    const { x, y } = worldFromPercent(node.x_pct, node.y_pct)
    mesh.position.set(x, y, 1)

    // Update selection state
    const ring = mesh.userData.ring
    if (state.selected && state.selected.id === node.id) {
      ring.material.color.setHex(0x0ea5e9) // sky-500
    } else {
      ring.material.color.setHex(0xcbd5e1) // slate-300
    }

    // Update label
    if (mesh.userData.label) {
      mesh.remove(mesh.userData.label)
    }
    const label = createTextSprite(node.text || "Node", 14, "#334155")
    label.position.set(6, 0, 0)
    label.scale.set(15, 4, 1)
    mesh.add(label)
    mesh.userData.label = label
  }

  // Create an edge line
  function createEdgeMesh(edge) {
    const sourceNode = state.nodes.find(n => n.id === edge.source_id)
    const targetNode = state.nodes.find(n => n.id === edge.target_id)
    if (!sourceNode || !targetNode) return null

    const start = worldFromPercent(sourceNode.x_pct, sourceNode.y_pct)
    const end = worldFromPercent(targetNode.x_pct, targetNode.y_pct)

    const material = new THREE.LineBasicMaterial({
      color: 0x94a3b8,
      linewidth: 1.5
    })
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(start.x, start.y, 0.5),
      new THREE.Vector3(end.x, end.y, 0.5)
    ])
    const line = new THREE.Line(geometry, material)
    line.userData = { edge }
    return line
  }

  // Update edge line positions
  function updateEdgeMesh(line, edge) {
    const sourceNode = state.nodes.find(n => n.id === edge.source_id)
    const targetNode = state.nodes.find(n => n.id === edge.target_id)
    if (!sourceNode || !targetNode) return

    const start = worldFromPercent(sourceNode.x_pct, sourceNode.y_pct)
    const end = worldFromPercent(targetNode.x_pct, targetNode.y_pct)

    const positions = line.geometry.attributes.position.array
    positions[0] = start.x
    positions[1] = start.y
    positions[2] = 0.5
    positions[3] = end.x
    positions[4] = end.y
    positions[5] = 0.5
    line.geometry.attributes.position.needsUpdate = true
  }

  // Preview line for link mode
  let previewLine = null
  function showPreviewLine(source) {
    if (previewLine) {
      scene.remove(previewLine)
    }
    const start = worldFromPercent(source.x_pct, source.y_pct)
    const material = new THREE.LineDashedMaterial({
      color: 0x94a3b8,
      dashSize: 2,
      gapSize: 2
    })
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(start.x, start.y, 0.5),
      new THREE.Vector3(start.x, start.y, 0.5)
    ])
    previewLine = new THREE.Line(geometry, material)
    previewLine.computeLineDistances()
    scene.add(previewLine)
  }

  function updatePreviewLine(worldX, worldY) {
    if (!previewLine) return
    const positions = previewLine.geometry.attributes.position.array
    positions[3] = worldX
    positions[4] = worldY
    positions[5] = 0.5
    previewLine.geometry.attributes.position.needsUpdate = true
    previewLine.computeLineDistances()
  }

  function hidePreviewLine() {
    if (previewLine) {
      scene.remove(previewLine)
      previewLine = null
    }
  }

  // Link mode badge
  const lineBadge = document.getElementById("line-mode-badge")
  function setLinkMode(on) {
    state.linkMode = on
    state.linkSource = null
    if (!on) hidePreviewLine()
    if (lineBadge) lineBadge.classList.toggle("hidden", !on)
  }

  // Render all nodes and edges
  function render() {
    // Update nodes
    for (const node of state.nodes) {
      let mesh = nodeMeshes.get(node.id)
      if (!mesh) {
        mesh = createNodeMesh(node)
        nodeMeshes.set(node.id, mesh)
        nodeGroup.add(mesh)
      } else {
        updateNodeMesh(mesh, node)
      }
    }

    // Remove deleted nodes
    for (const [id, mesh] of nodeMeshes) {
      if (!state.nodes.find(n => n.id === id)) {
        nodeGroup.remove(mesh)
        nodeMeshes.delete(id)
      }
    }

    // Update edges
    for (const edge of state.edges) {
      let line = edgeMeshes.get(edge.id)
      if (!line) {
        line = createEdgeMesh(edge)
        if (line) {
          edgeMeshes.set(edge.id, line)
          edgeGroup.add(line)
        }
      } else {
        updateEdgeMesh(line, edge)
      }
    }

    // Remove deleted edges
    for (const [id, line] of edgeMeshes) {
      if (!state.edges.find(e => e.id === id)) {
        edgeGroup.remove(line)
        edgeMeshes.delete(id)
      }
    }
  }

  // Get world position from mouse event
  function getWorldPosition(event) {
    const rect = renderer.domElement.getBoundingClientRect()
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1

    // Create a plane at z=0 for intersection
    const plane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0)
    raycaster.setFromCamera(mouse, camera)

    const intersection = new THREE.Vector3()
    raycaster.ray.intersectPlane(plane, intersection)

    return { x: intersection.x, y: intersection.y }
  }

  // Find node at position
  function findNodeAtPosition(event) {
    const rect = renderer.domElement.getBoundingClientRect()
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1

    raycaster.setFromCamera(mouse, camera)
    const intersects = raycaster.intersectObjects(nodeGroup.children, true)

    if (intersects.length > 0) {
      // Find the parent mesh (node)
      let obj = intersects[0].object
      while (obj.parent && obj.parent !== nodeGroup) {
        obj = obj.parent
      }
      if (obj.userData && obj.userData.node) {
        return obj.userData.node
      }
    }
    return null
  }

  // Drawer handling
  const drawerEmpty = document.getElementById("drawer-empty")
  const form = document.getElementById("node-form")
  const idEl = document.getElementById("node-id")
  const textEl = document.getElementById("node-text")
  const xEl = document.getElementById("node-x")
  const yEl = document.getElementById("node-y")
  const metaFieldsEl = document.getElementById("meta-fields")
  const metaAddBtn = document.getElementById("meta-add")
  const delBtn = document.getElementById("node-delete")
  const undoToast = document.getElementById("undo-toast")
  const undoBtn = document.getElementById("undo-button")
  const undoMsg = document.getElementById("undo-message")

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
    // Rebuild metadata fields
    if (metaFieldsEl) {
      metaFieldsEl.innerHTML = ""
      const md = state.selected.metadata || {}
      const keys = Object.keys(md)
      if (keys.length === 0) {
        metaFieldsEl.appendChild(buildMetaRow())
      } else {
        for (const k of keys) {
          metaFieldsEl.appendChild(buildMetaRow(k, toMetaString(md[k])))
        }
      }
    }
  }

  function buildMetaRow(key = "", value = "") {
    const row = document.createElement("div")
    row.className = "meta-row grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto] items-center gap-2"

    const k = document.createElement("input")
    k.type = "text"
    k.placeholder = "key"
    k.value = key
    k.className = "w-full min-w-0 rounded border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-2 py-1 text-sm"

    const v = document.createElement("input")
    v.type = "text"
    v.placeholder = "value"
    v.value = value
    v.className = "w-full min-w-0 rounded border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-2 py-1 text-sm"

    const del = document.createElement("button")
    del.type = "button"
    del.textContent = "✕"
    del.className = "rounded border border-slate-300 dark:border-slate-700 px-2 py-1 text-sm text-slate-600 dark:text-slate-300"
    del.addEventListener("click", () => {
      row.remove()
    })

    row.appendChild(k)
    row.appendChild(v)
    row.appendChild(del)
    return row
  }

  function toMetaString(val) {
    if (val == null) return ""
    if (typeof val === "object") return JSON.stringify(val)
    return String(val)
  }

  function parseMaybeJSON(str) {
    if (str === "") return ""
    try {
      const parsed = JSON.parse(str)
      return parsed
    } catch (_e) {
      return str
    }
  }

  if (metaAddBtn && metaFieldsEl) {
    metaAddBtn.addEventListener("click", () => {
      const row = buildMetaRow()
      metaFieldsEl.appendChild(row)
      const first = row.querySelector("input")
      if (first) first.focus()
    })
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
      // Gather metadata key/value pairs
      if (metaFieldsEl) {
        const md = {}
        metaFieldsEl.querySelectorAll(".meta-row").forEach(row => {
          const [kEl, vEl] = row.querySelectorAll("input")
          const key = (kEl?.value || "").trim()
          const value = (vEl?.value || "").trim()
          if (key !== "") md[key] = parseMaybeJSON(value)
        })
        payload.metadata = md
      }
      api("PATCH", `/api/nodes/${state.selected.id}`, payload)
        .then(updated => {
          Object.assign(state.selected, updated)
          render()
          updateDrawer()
          syncCodeFromVisual()
        })
        .catch(console.error)
    })
  }

  // Undo functionality
  function showUndo(message, payload) {
    if (!undoToast) return
    if (undoTimer) {
      clearTimeout(undoTimer)
      undoTimer = null
    }
    lastDeleted = payload
    if (undoMsg) undoMsg.textContent = message
    undoToast.classList.remove("hidden")
    undoTimer = setTimeout(() => {
      undoToast.classList.add("hidden")
      lastDeleted = null
      undoTimer = null
    }, 6000)
  }

  async function undoDelete() {
    if (!lastDeleted) return
    const { node, edges } = lastDeleted
    try {
      const recreated = await api("POST", "/api/nodes", {
        x_pct: node.x_pct,
        y_pct: node.y_pct,
        text: node.text,
        metadata: node.metadata || {}
      })
      const otherExists = id => state.nodes.some(n => n.id === id)
      for (const e of edges) {
        const source_id = e.source_id === node.id ? recreated.id : e.source_id
        const target_id = e.target_id === node.id ? recreated.id : e.target_id
        if (source_id === target_id) continue
        if ((source_id === recreated.id || otherExists(source_id)) && (target_id === recreated.id || otherExists(target_id))) {
          try {
            const newEdge = await api("POST", "/api/edges", { source_id, target_id, metadata: e.metadata || {} })
            state.edges.push(newEdge)
          } catch (_e) {}
        }
      }
      state.nodes.push(recreated)
      state.selected = recreated
      render()
      updateDrawer()
      syncCodeFromVisual()
    } finally {
      if (undoToast) undoToast.classList.add("hidden")
      lastDeleted = null
      if (undoTimer) clearTimeout(undoTimer)
      undoTimer = null
    }
  }

  if (undoBtn) {
    undoBtn.addEventListener("click", e => {
      e.preventDefault()
      undoDelete().catch(console.error)
    })
  }

  async function deleteSelected() {
    if (!state.selected) return
    const node = state.selected
    const relatedEdges = state.edges.filter(e => e.source_id === node.id || e.target_id === node.id)
    try {
      await api("DELETE", `/api/nodes/${node.id}`)
      state.nodes = state.nodes.filter(n => n.id !== node.id)
      state.edges = state.edges.filter(e => e.source_id !== node.id && e.target_id !== node.id)
      state.selected = null
      render()
      updateDrawer()
      syncCodeFromVisual()
      showUndo("Node deleted.", { node, edges: relatedEdges })
    } catch (err) {
      console.error(err)
    }
  }

  if (delBtn) {
    delBtn.addEventListener("click", () => {
      deleteSelected()
    })
  }

  // Node label editing
  let activeEditInput = null
  let activeEditNode = null

  function closeEditInput() {
    if (activeEditInput && activeEditInput.parentNode) {
      activeEditInput.parentNode.removeChild(activeEditInput)
    }
    activeEditInput = null
    activeEditNode = null
  }

  function startNodeLabelEdit(node) {
    if (activeEditNode && activeEditNode.id === node.id && activeEditInput) {
      activeEditInput.focus()
      activeEditInput.select()
      return
    }

    if (activeEditInput) {
      const prevNode = activeEditNode
      const prevInput = activeEditInput
      if (prevNode && prevInput) {
        const newText = prevInput.value.trim() || "Node"
        prevNode.text = newText
        api("PATCH", `/api/nodes/${prevNode.id}`, { text: prevNode.text }).catch(console.error)
      }
      closeEditInput()
      render()
    }

    // Get screen position of node relative to canvasWrap
    const mesh = nodeMeshes.get(node.id)
    if (!mesh) return

    const vector = new THREE.Vector3()
    mesh.getWorldPosition(vector)
    vector.project(camera)

    const rect = renderer.domElement.getBoundingClientRect()
    // Position relative to canvasWrap (not page), since input is appended there
    const x = ((vector.x + 1) / 2) * rect.width
    const y = ((-vector.y + 1) / 2) * rect.height

    const input = document.createElement("input")
    input.type = "text"
    input.value = node.text || ""
    input.placeholder = "Node"
    input.className = "absolute z-10 px-2 py-1 text-sm rounded border border-slate-300 bg-white text-slate-900 shadow-sm focus:outline-none focus:ring focus:ring-slate-200"
    input.style.left = `${x + 15}px`
    input.style.top = `${y - 10}px`
    input.style.minWidth = "120px"

    activeEditInput = input
    activeEditNode = node

    const save = () => {
      if (!activeEditInput) return
      const newText = input.value.trim() || "Node"
      node.text = newText
      api("PATCH", `/api/nodes/${node.id}`, { text: node.text }).catch(console.error)
      closeEditInput()
      render()
      syncCodeFromVisual()
    }

    const cancel = () => {
      closeEditInput()
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

  // Drag state
  let draggedNode = null
  let isDraggingNode = false

  // Mouse events
  renderer.domElement.addEventListener("mousedown", event => {
    if (event.button === 2 || event.shiftKey) {
      // Right click or shift+click for camera pan
      isDraggingCamera = true
      lastMousePos = { x: event.clientX, y: event.clientY }
      renderer.domElement.style.cursor = "grabbing"
      return
    }

    const node = findNodeAtPosition(event)
    if (node) {
      if (state.linkMode) {
        if (state.linkSource && state.linkSource.id !== node.id) {
          api("POST", "/api/edges", { source_id: state.linkSource.id, target_id: node.id })
            .then(edge => {
              state.edges.push(edge)
              setLinkMode(false)
              render()
              syncCodeFromVisual()
            })
            .catch(console.error)
        } else {
          state.linkSource = node
          showPreviewLine(node)
        }
      } else {
        draggedNode = node
        isDraggingNode = true
        setSelected(node)
      }
    }
  })

  renderer.domElement.addEventListener("mousemove", event => {
    if (isDraggingCamera) {
      const dx = event.clientX - lastMousePos.x
      const dy = event.clientY - lastMousePos.y

      // Pan camera (scale by zoom level)
      const scale = camera.position.z / 100
      camera.position.x -= dx * 0.2 * scale
      camera.position.y += dy * 0.2 * scale

      lastMousePos = { x: event.clientX, y: event.clientY }
      return
    }

    if (isDraggingNode && draggedNode) {
      const { x, y } = getWorldPosition(event)
      const { x_pct, y_pct } = percentFromWorld(x, y)
      draggedNode.x_pct = x_pct
      draggedNode.y_pct = y_pct
      render()
      return
    }

    if (state.linkMode && state.linkSource) {
      const { x, y } = getWorldPosition(event)
      updatePreviewLine(x, y)
    }

    // Hover cursor
    const node = findNodeAtPosition(event)
    if (node) {
      renderer.domElement.style.cursor = "pointer"
    } else if (state.linkMode) {
      renderer.domElement.style.cursor = "alias"
    } else {
      renderer.domElement.style.cursor = "crosshair"
    }
  })

  renderer.domElement.addEventListener("mouseup", event => {
    if (isDraggingCamera) {
      isDraggingCamera = false
      renderer.domElement.style.cursor = state.linkMode ? "alias" : "crosshair"
      return
    }

    if (isDraggingNode && draggedNode) {
      api("PATCH", `/api/nodes/${draggedNode.id}`, {
        x_pct: draggedNode.x_pct,
        y_pct: draggedNode.y_pct
      }).catch(console.error)
      syncCodeFromVisual()
      isDraggingNode = false
      draggedNode = null
    }
  })

  renderer.domElement.addEventListener("dblclick", event => {
    const node = findNodeAtPosition(event)
    if (node) {
      startNodeLabelEdit(node)
    }
  })

  renderer.domElement.addEventListener("click", event => {
    if (isDraggingNode || isDraggingCamera) return

    const node = findNodeAtPosition(event)
    if (!node && !state.linkMode) {
      // Click on empty space - create new node
      const { x, y } = getWorldPosition(event)
      const { x_pct, y_pct } = percentFromWorld(x, y)

      // Only create if within bounds
      if (x_pct >= 0 && x_pct <= 100 && y_pct >= 0 && y_pct <= 100) {
        api("POST", "/api/nodes", { x_pct, y_pct, text: "Node" })
          .then(newNode => {
            state.nodes.push(newNode)
            render()
            syncCodeFromVisual()
            startNodeLabelEdit(newNode)
          })
          .catch(console.error)
      }
    }
  })

  // Zoom with mouse wheel
  renderer.domElement.addEventListener("wheel", event => {
    event.preventDefault()

    const zoomSpeed = 0.1
    const delta = event.deltaY > 0 ? 1 + zoomSpeed : 1 - zoomSpeed

    targetCameraZ = Math.max(30, Math.min(200, camera.position.z * delta))
  }, { passive: false })

  // Prevent context menu on right-click
  renderer.domElement.addEventListener("contextmenu", event => {
    event.preventDefault()
  })

  // Keyboard shortcuts
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
    } else if ((k === "backspace" || k === "delete") && state.selected) {
      deleteSelected()
      e.preventDefault()
    }
  })

  // DSL Editor Integration
  const codeEditor = document.getElementById("code-editor")
  const parseStatus = document.getElementById("parse-status")
  const parseErrors = document.getElementById("parse-errors")
  const toggleCodeBtn = document.getElementById("toggle-code-panel")
  const codePanel = document.getElementById("code-panel")

  let updatingFromCode = false
  let updatingFromVisual = false
  let codeDebounceTimer = null

  syncCodeFromVisual = function() {
    if (updatingFromCode || !codeEditor) return
    updatingFromVisual = true

    const code = dsl.generate({
      title: state.mapTitle || null,
      nodes: state.nodes,
      edges: state.edges
    })

    codeEditor.value = code
    updatingFromVisual = false

    if (parseStatus) {
      parseStatus.textContent = "✓"
      parseStatus.className = "text-xs text-green-500"
    }
    if (parseErrors) {
      parseErrors.classList.add("hidden")
    }
  }

  async function updateStateFromCode() {
    if (updatingFromVisual || !codeEditor) return
    updatingFromCode = true

    const code = codeEditor.value
    const parsed = dsl.parse(code)
    const validationErrors = dsl.validate(parsed)
    const allErrors = [...parsed.errors, ...validationErrors]

    if (parseErrors) {
      if (allErrors.length > 0) {
        parseErrors.innerHTML = allErrors.map(e => `<div>Line ${e.line || '?'}: ${e.message}</div>`).join('')
        parseErrors.classList.remove("hidden")
      } else {
        parseErrors.classList.add("hidden")
      }
    }

    if (parseStatus) {
      parseStatus.textContent = allErrors.length > 0 ? `${allErrors.length} error(s)` : "✓"
      parseStatus.className = allErrors.length > 0 ? "text-xs text-red-500" : "text-xs text-green-500"
    }

    if (validationErrors.length === 0 && parsed.components.length > 0) {
      state.mapTitle = parsed.title

      const existingByName = new Map()
      for (const n of state.nodes) {
        existingByName.set(n.text, n)
      }

      const seenNodeIds = new Set()
      const nameToNode = new Map()

      for (const comp of parsed.components) {
        const existing = existingByName.get(comp.name)
        if (existing) {
          if (Math.abs(existing.x_pct - comp.x_pct) > 0.5 || Math.abs(existing.y_pct - comp.y_pct) > 0.5) {
            existing.x_pct = comp.x_pct
            existing.y_pct = comp.y_pct
            api("PATCH", `/api/nodes/${existing.id}`, { x_pct: comp.x_pct, y_pct: comp.y_pct }).catch(console.error)
          }
          seenNodeIds.add(existing.id)
          nameToNode.set(comp.name, existing)
        } else {
          try {
            const newNode = await api("POST", "/api/nodes", {
              text: comp.name,
              x_pct: comp.x_pct,
              y_pct: comp.y_pct,
              metadata: comp.type === 'anchor' ? { type: 'anchor' } : {}
            })
            state.nodes.push(newNode)
            seenNodeIds.add(newNode.id)
            nameToNode.set(comp.name, newNode)
          } catch (e) {
            console.error("Failed to create node:", e)
          }
        }
      }

      if (parsed.components.length > 0) {
        const toRemove = state.nodes.filter(n => !seenNodeIds.has(n.id))
        for (const n of toRemove) {
          try {
            await api("DELETE", `/api/nodes/${n.id}`)
          } catch (e) {
            console.error("Failed to delete node:", e)
          }
        }
        state.nodes = state.nodes.filter(n => seenNodeIds.has(n.id))
        state.edges = state.edges.filter(e =>
          seenNodeIds.has(e.source_id) && seenNodeIds.has(e.target_id)
        )
      }

      const existingEdgeKeys = new Set(
        state.edges.map(e => `${e.source_id}->${e.target_id}`)
      )

      for (const edge of parsed.edges) {
        const sourceNode = nameToNode.get(edge.source)
        const targetNode = nameToNode.get(edge.target)
        if (sourceNode && targetNode) {
          const key = `${sourceNode.id}->${targetNode.id}`
          if (!existingEdgeKeys.has(key)) {
            try {
              const newEdge = await api("POST", "/api/edges", {
                source_id: sourceNode.id,
                target_id: targetNode.id
              })
              state.edges.push(newEdge)
            } catch (e) {
              console.error("Failed to create edge:", e)
            }
          }
        }
      }

      const dslEdgeKeys = new Set()
      for (const edge of parsed.edges) {
        const sourceNode = nameToNode.get(edge.source)
        const targetNode = nameToNode.get(edge.target)
        if (sourceNode && targetNode) {
          dslEdgeKeys.add(`${sourceNode.id}->${targetNode.id}`)
        }
      }

      const edgesToRemove = state.edges.filter(e => {
        const key = `${e.source_id}->${e.target_id}`
        return !dslEdgeKeys.has(key)
      })

      for (const e of edgesToRemove) {
        try {
          await api("DELETE", `/api/edges/${e.id}`)
        } catch (err) {
          console.error("Failed to delete edge:", err)
        }
      }
      state.edges = state.edges.filter(e => {
        const key = `${e.source_id}->${e.target_id}`
        return dslEdgeKeys.has(key)
      })

      render()
    }

    updatingFromCode = false
  }

  if (codeEditor) {
    codeEditor.addEventListener("input", () => {
      if (codeDebounceTimer) clearTimeout(codeDebounceTimer)
      codeDebounceTimer = setTimeout(() => {
        updateStateFromCode()
      }, 500)
    })
  }

  if (toggleCodeBtn && codePanel) {
    toggleCodeBtn.addEventListener("click", () => {
      codePanel.classList.toggle("hidden")
    })
  }

  // Window resize
  function onResize() {
    const w = canvasWrap.clientWidth
    const h = canvasWrap.clientHeight
    if (w === 0 || h === 0) return

    camera.aspect = w / h
    camera.updateProjectionMatrix()
    renderer.setSize(w, h)
  }

  window.addEventListener("resize", onResize)

  // Animation loop
  function animate() {
    requestAnimationFrame(animate)

    // Smooth zoom
    camera.position.z += (targetCameraZ - camera.position.z) * 0.1

    renderer.render(scene, camera)
  }

  // === Layer Stack Management ===

  // Generate DSL code from nodes and edges
  function generateDslCode(mapName, nodes, edges) {
    return dsl.generate({
      title: mapName,
      nodes: nodes,
      edges: edges
    })
  }

  // Add a new layer to the stack (as overlay, not active)
  function addLayer(mapId, mapName, nodes, edges) {
    const color = layerColors[nextColorIndex % layerColors.length]
    nextColorIndex++

    const layer = {
      mapId: mapId,
      name: mapName,
      dslCode: generateDslCode(mapName, nodes, edges),
      nodes: nodes,
      edges: edges,
      isActive: false,
      visible: true,
      collapsed: true,
      color: color
    }

    layerStack.push(layer)
    renderLayerToThreeJS(layer)
    renderLayerStackUI()
    return color
  }

  // Remove a layer from the stack by index
  function removeLayer(index) {
    if (index < 1 || index >= layerStack.length) return // Can't remove active layer (index 0)

    const layer = layerStack[index]
    const group = layerGroups.get(layer.mapId)
    if (group) {
      layersGroup.remove(group)
      layerGroups.delete(layer.mapId)
    }

    layerStack.splice(index, 1)
    renderLayerStackUI()
  }

  // Promote a layer to be the active layer (swap with index 0)
  function promoteLayer(index) {
    if (index < 1 || index >= layerStack.length) return

    const active = layerStack[0]
    const promoted = layerStack[index]

    // Swap active status
    active.isActive = false
    active.color = layerColors[nextColorIndex % layerColors.length]
    nextColorIndex++
    promoted.isActive = true
    promoted.color = null

    // Swap positions
    layerStack[0] = promoted
    layerStack[index] = active

    // Re-render everything
    rebuildAllLayerVisuals()
    renderLayerStackUI()
    syncCodeFromVisual()
  }

  // Toggle layer collapsed state in UI
  function toggleLayerCollapsed(index) {
    if (index >= layerStack.length) return
    layerStack[index].collapsed = !layerStack[index].collapsed
    renderLayerStackUI()
  }

  // Toggle layer visibility in Three.js
  function toggleLayerVisible(index) {
    if (index < 1 || index >= layerStack.length) return // Active layer always visible

    const layer = layerStack[index]
    layer.visible = !layer.visible

    const group = layerGroups.get(layer.mapId)
    if (group) {
      group.visible = layer.visible
    }

    renderLayerStackUI()
  }

  // Create Three.js group for an overlay layer
  function renderLayerToThreeJS(layer) {
    if (layer.isActive) return // Active layer uses nodeGroup/edgeGroup

    // Remove existing group if any
    const existingGroup = layerGroups.get(layer.mapId)
    if (existingGroup) {
      layersGroup.remove(existingGroup)
    }

    const layerGroup = new THREE.Group()
    layerGroup.position.z = -0.5 - (layerGroups.size * 0.1)
    layerGroup.visible = layer.visible

    const color = layer.color

    // Create semi-transparent nodes (hollow rings)
    for (const node of layer.nodes) {
      const { x, y } = worldFromPercent(node.x_pct, node.y_pct)

      const ringGeometry = new THREE.RingGeometry(1.5, 2, 32)
      const ringMaterial = new THREE.MeshBasicMaterial({
        color: color,
        side: THREE.DoubleSide,
        transparent: true,
        opacity: 0.6
      })
      const ring = new THREE.Mesh(ringGeometry, ringMaterial)
      ring.position.set(x, y, 0)
      layerGroup.add(ring)

      // Label
      const label = createLayerTextSprite(node.text || "Node", 12, color)
      label.position.set(x + 5, y, 0.1)
      label.scale.set(12, 3, 1)
      layerGroup.add(label)
    }

    // Create semi-transparent edges
    for (const edge of layer.edges) {
      const sourceNode = layer.nodes.find(n => n.id === edge.source_id)
      const targetNode = layer.nodes.find(n => n.id === edge.target_id)
      if (!sourceNode || !targetNode) continue

      const start = worldFromPercent(sourceNode.x_pct, sourceNode.y_pct)
      const end = worldFromPercent(targetNode.x_pct, targetNode.y_pct)

      const material = new THREE.LineBasicMaterial({
        color: color,
        transparent: true,
        opacity: 0.4
      })
      const geometry = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(start.x, start.y, 0),
        new THREE.Vector3(end.x, end.y, 0)
      ])
      const line = new THREE.Line(geometry, material)
      layerGroup.add(line)
    }

    layersGroup.add(layerGroup)
    layerGroups.set(layer.mapId, layerGroup)
  }

  function createLayerTextSprite(text, fontSize, color) {
    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d")
    canvas.width = 256
    canvas.height = 64

    const cssColor = `#${color.toString(16).padStart(6, '0')}`
    ctx.fillStyle = cssColor
    ctx.globalAlpha = 0.7
    ctx.font = `${fontSize}px ui-sans-serif, system-ui, sans-serif`
    ctx.textAlign = "left"
    ctx.textBaseline = "middle"
    ctx.fillText(text, 10, 32)

    const texture = new THREE.CanvasTexture(canvas)
    const material = new THREE.SpriteMaterial({ map: texture, depthTest: false })
    return new THREE.Sprite(material)
  }

  // Rebuild all layer visuals (after swap, etc.)
  function rebuildAllLayerVisuals() {
    // Clear all layer groups
    while (layersGroup.children.length > 0) {
      layersGroup.remove(layersGroup.children[0])
    }
    layerGroups.clear()

    // Re-render overlay layers
    for (let i = 1; i < layerStack.length; i++) {
      renderLayerToThreeJS(layerStack[i])
    }

    // Active layer uses the main render() function
    render()
  }

  // Render the layer stack UI in the sidebar
  function renderLayerStackUI() {
    const activeLayer = getActiveLayer()
    const activeLayerName = document.getElementById("active-layer-name")
    const activeLayerContent = document.getElementById("active-layer-content")
    const activeLayerHeader = document.getElementById("active-layer-header")
    const activeLayerChevron = document.getElementById("active-layer-chevron")
    const overlayContainer = document.getElementById("overlay-layers-container")

    // Update active layer header
    if (activeLayerName && activeLayer) {
      activeLayerName.textContent = activeLayer.name || "Untitled Map"
    }

    // Handle active layer collapse/expand
    if (activeLayerHeader && activeLayerContent && activeLayerChevron) {
      const isCollapsed = activeLayer?.collapsed ?? false
      activeLayerContent.classList.toggle("hidden", isCollapsed)
      activeLayerChevron.style.transform = isCollapsed ? "rotate(-90deg)" : ""
    }

    // Render overlay layers
    if (!overlayContainer) return

    overlayContainer.innerHTML = ""

    for (let i = 1; i < layerStack.length; i++) {
      const layer = layerStack[i]
      const colorHex = `#${layer.color.toString(16).padStart(6, '0')}`

      const section = document.createElement("div")
      section.className = "border-b border-slate-200 dark:border-slate-800"
      section.dataset.layerIndex = i

      section.innerHTML = `
        <div class="flex items-center justify-between px-3 py-2 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors">
          <button
            type="button"
            class="layer-toggle flex items-center gap-2 flex-1 text-left"
          >
            <svg
              class="layer-chevron w-4 h-4 text-slate-400 transition-transform ${layer.collapsed ? '-rotate-90' : ''}"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
            </svg>
            <span
              class="w-3 h-3 rounded-full shrink-0"
              style="background-color: ${colorHex}"
            ></span>
            <span class="text-sm font-medium text-slate-700 dark:text-slate-300 truncate">
              ${layer.name}
            </span>
          </button>
          <div class="flex items-center gap-1">
            <button
              type="button"
              class="layer-visibility p-1 rounded text-slate-400 hover:text-slate-600 dark:hover:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700"
              title="${layer.visible ? 'Hide layer' : 'Show layer'}"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                ${layer.visible
                  ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>'
                  : '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>'
                }
              </svg>
            </button>
            <button
              type="button"
              class="layer-promote p-1 rounded text-slate-400 hover:text-emerald-600 dark:hover:text-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/20"
              title="Promote to active"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
              </svg>
            </button>
            <button
              type="button"
              class="layer-remove p-1 rounded text-slate-400 hover:text-red-500 hover:bg-red-50 dark:hover:bg-red-900/20"
              title="Remove layer"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
        <div class="layer-content ${layer.collapsed ? 'hidden' : ''}">
          <textarea
            class="w-full p-3 font-mono text-xs bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 border-none outline-none resize-none cursor-not-allowed"
            style="min-height: 120px;"
            readonly
            disabled
          >${layer.dslCode}</textarea>
        </div>
      `

      // Wire up event handlers
      section.querySelector(".layer-toggle").addEventListener("click", () => {
        toggleLayerCollapsed(i)
      })

      section.querySelector(".layer-visibility").addEventListener("click", (e) => {
        e.stopPropagation()
        toggleLayerVisible(i)
      })

      section.querySelector(".layer-promote").addEventListener("click", (e) => {
        e.stopPropagation()
        promoteLayer(i)
      })

      section.querySelector(".layer-remove").addEventListener("click", (e) => {
        e.stopPropagation()
        removeLayer(i)
      })

      overlayContainer.appendChild(section)
    }
  }

  // Load maps list for the selector modal
  async function loadMapsList() {
    const listEl = document.getElementById("map-selector-list")
    if (!listEl) return

    try {
      const { maps } = await api("GET", "/api/maps")
      const activeMapId = getActiveLayer()?.mapId
      const existingMapIds = new Set(layerStack.map(l => l.mapId))

      if (maps.length === 0) {
        listEl.innerHTML = '<p class="text-center text-slate-500 py-4">No other maps available</p>'
        return
      }

      listEl.innerHTML = ""
      for (const map of maps) {
        // Skip active map and already-added layers
        if (map.id === activeMapId || existingMapIds.has(map.id)) continue

        const item = document.createElement("button")
        item.type = "button"
        item.className = "w-full text-left px-3 py-2 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
        item.innerHTML = `
          <div class="font-medium text-slate-900 dark:text-slate-100">${map.name}</div>
          <div class="text-xs text-slate-500">${new Date(map.updated_at).toLocaleDateString()}</div>
        `

        item.addEventListener("click", async () => {
          try {
            const data = await api("GET", `/api/maps/${map.id}`)
            addLayer(map.id, data.map.name, data.nodes, data.edges)
            document.getElementById("map-selector-modal").classList.add("hidden")
          } catch (err) {
            console.error("Failed to load map:", err)
          }
        })

        listEl.appendChild(item)
      }

      if (listEl.children.length === 0) {
        listEl.innerHTML = '<p class="text-center text-slate-500 py-4">All maps already added as layers</p>'
      }
    } catch (err) {
      console.error("Failed to load maps list:", err)
      listEl.innerHTML = '<p class="text-center text-red-500 py-4">Failed to load maps</p>'
    }
  }

  // Wire up layer panel UI
  const addLayerBtn = document.getElementById("add-layer-btn")
  const mapSelectorModal = document.getElementById("map-selector-modal")
  const activeLayerHeader = document.getElementById("active-layer-header")

  if (addLayerBtn && mapSelectorModal) {
    addLayerBtn.addEventListener("click", () => {
      loadMapsList()
      mapSelectorModal.classList.remove("hidden")
    })
  }

  // Handle active layer collapse/expand
  if (activeLayerHeader) {
    activeLayerHeader.addEventListener("click", () => {
      const active = getActiveLayer()
      if (active) {
        active.collapsed = !active.collapsed
        renderLayerStackUI()
      }
    })
  }

  // === GitHub Sync ===

  const githubSettingsBtn = document.getElementById("github-settings-btn")
  const githubPushBtn = document.getElementById("github-push-btn")
  const githubPullBtn = document.getElementById("github-pull-btn")
  const githubSettingsModal = document.getElementById("github-settings-modal")
  const githubSettingsForm = document.getElementById("github-settings-form")
  const githubSyncStatus = document.getElementById("github-sync-status")
  const githubDisconnectBtn = document.getElementById("github-disconnect-btn")
  const githubSettingsError = document.getElementById("github-settings-error")
  const githubSettingsSuccess = document.getElementById("github-settings-success")

  // Update GitHub sync UI based on configuration state
  function updateGitHubSyncUI() {
    const config = github.getConfig()
    const isConfigured = github.isConfigured()

    if (isConfigured) {
      githubSyncStatus.textContent = `${config.owner}/${config.repo}`
      githubSyncStatus.title = `${config.path} on ${config.branch || 'main'}`
      githubPushBtn?.classList.remove("hidden")
      githubPullBtn?.classList.remove("hidden")
      githubDisconnectBtn?.classList.remove("hidden")
    } else {
      githubSyncStatus.textContent = "Not configured"
      githubSyncStatus.title = ""
      githubPushBtn?.classList.add("hidden")
      githubPullBtn?.classList.add("hidden")
      githubDisconnectBtn?.classList.add("hidden")
    }
  }

  // Open settings modal
  if (githubSettingsBtn && githubSettingsModal) {
    githubSettingsBtn.addEventListener("click", () => {
      // Populate form with existing config
      const config = github.getConfig() || {}
      document.getElementById("github-token").value = config.token || ""
      document.getElementById("github-owner").value = config.owner || ""
      document.getElementById("github-repo").value = config.repo || ""
      document.getElementById("github-branch").value = config.branch || "main"
      document.getElementById("github-path").value = config.path || ""

      // Clear messages
      githubSettingsError?.classList.add("hidden")
      githubSettingsSuccess?.classList.add("hidden")

      githubSettingsModal.classList.remove("hidden")
    })
  }

  // Handle settings form submission
  if (githubSettingsForm) {
    githubSettingsForm.addEventListener("submit", async (e) => {
      e.preventDefault()

      const token = document.getElementById("github-token").value.trim()
      const owner = document.getElementById("github-owner").value.trim()
      const repo = document.getElementById("github-repo").value.trim()
      const branch = document.getElementById("github-branch").value.trim() || "main"
      const path = document.getElementById("github-path").value.trim()

      // Clear messages
      githubSettingsError?.classList.add("hidden")
      githubSettingsSuccess?.classList.add("hidden")

      // Validate required fields
      if (!token || !owner || !repo || !path) {
        githubSettingsError.textContent = "All fields are required"
        githubSettingsError.classList.remove("hidden")
        return
      }

      // Validate token
      const validation = await github.validateToken(token)
      if (!validation.valid) {
        githubSettingsError.textContent = validation.message || "Invalid token"
        githubSettingsError.classList.remove("hidden")
        return
      }

      // Save config
      github.saveConfig({ token, owner, repo, branch, path })

      // Show success
      githubSettingsSuccess.textContent = `Connected as ${validation.user}`
      githubSettingsSuccess.classList.remove("hidden")

      // Update UI
      updateGitHubSyncUI()

      // Close modal after a short delay
      setTimeout(() => {
        githubSettingsModal.classList.add("hidden")
      }, 1000)
    })
  }

  // Handle disconnect
  if (githubDisconnectBtn) {
    githubDisconnectBtn.addEventListener("click", () => {
      github.clearConfig()
      updateGitHubSyncUI()

      // Clear form
      document.getElementById("github-token").value = ""
      document.getElementById("github-owner").value = ""
      document.getElementById("github-repo").value = ""
      document.getElementById("github-branch").value = "main"
      document.getElementById("github-path").value = ""

      githubSettingsError?.classList.add("hidden")
      githubSettingsSuccess.textContent = "Disconnected"
      githubSettingsSuccess.classList.remove("hidden")
    })
  }

  // Handle push to GitHub
  if (githubPushBtn) {
    githubPushBtn.addEventListener("click", async () => {
      const codeEditor = document.getElementById("code-editor")
      if (!codeEditor) return

      const code = codeEditor.value
      const mapName = getActiveLayer()?.name || "Untitled Map"

      // Update status
      githubSyncStatus.textContent = "Pushing..."
      githubPushBtn.disabled = true

      try {
        const result = await github.pushToGitHub(code, mapName)

        if (result.success) {
          githubSyncStatus.textContent = result.message
          if (result.url) {
            githubSyncStatus.title = result.url
          }
        } else {
          githubSyncStatus.textContent = `Error: ${result.message}`
        }
      } catch (err) {
        githubSyncStatus.textContent = `Error: ${err.message}`
      } finally {
        githubPushBtn.disabled = false

        // Reset status after a few seconds
        setTimeout(updateGitHubSyncUI, 3000)
      }
    })
  }

  // Handle pull from GitHub
  if (githubPullBtn) {
    githubPullBtn.addEventListener("click", async () => {
      const codeEditor = document.getElementById("code-editor")
      if (!codeEditor) return

      // Update status
      githubSyncStatus.textContent = "Pulling..."
      githubPullBtn.disabled = true

      try {
        const result = await github.pullFromGitHub()

        if (result.success && result.content !== undefined) {
          // Update code editor
          codeEditor.value = result.content

          // Trigger code parsing
          const event = new Event("input", { bubbles: true })
          codeEditor.dispatchEvent(event)

          githubSyncStatus.textContent = "Pulled from GitHub"
        } else {
          githubSyncStatus.textContent = `Error: ${result.message}`
        }
      } catch (err) {
        githubSyncStatus.textContent = `Error: ${err.message}`
      } finally {
        githubPullBtn.disabled = false

        // Reset status after a few seconds
        setTimeout(updateGitHubSyncUI, 3000)
      }
    })
  }

  // Initialize GitHub sync UI
  updateGitHubSyncUI()

  // Initialize
  drawGrid()
  drawAxisLabels()

  // Load existing data and initialize layer stack
  api("GET", "/api/map")
    .then(({ map, nodes, edges }) => {
      // Initialize the active layer as first item in layerStack
      const activeLayer = {
        mapId: map?.id,
        name: map?.name || "Untitled Map",
        dslCode: "",
        nodes: nodes,
        edges: edges,
        isActive: true,
        visible: true,
        collapsed: false,
        color: null // Active layer has no color overlay
      }
      layerStack.push(activeLayer)

      render()
      syncCodeFromVisual()
      renderLayerStackUI()
    })
    .catch(console.error)

  animate()
}

// Auto-init
document.addEventListener("DOMContentLoaded", initMapPage)
