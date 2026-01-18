import * as THREE from "three"

// Segment data for the strategy cycle
const SEGMENTS = {
  // Outer ring - OODA loop
  observe: {
    ring: "outer",
    label: "Observe",
    startAngle: Math.PI * 1.5,
    endAngle: Math.PI * 2,
    color: 0xe2e8f0,
    activeColor: 0x3b82f6,
    description: "Gather information about the landscape, climate, and environment. What is happening? What patterns exist?"
  },
  orient: {
    ring: "outer",
    label: "Orient",
    startAngle: Math.PI,
    endAngle: Math.PI * 1.5,
    color: 0xe2e8f0,
    activeColor: 0x3b82f6,
    description: "Analyze and synthesize observations. How does this relate to our position? What are our biases?"
  },
  decide: {
    ring: "outer",
    label: "Decide",
    startAngle: Math.PI * 0.5,
    endAngle: Math.PI,
    color: 0xe2e8f0,
    activeColor: 0x3b82f6,
    description: "Choose a course of action based on orientation. What options do we have? Which path forward?"
  },
  act: {
    ring: "outer",
    label: "Act",
    startAngle: 0,
    endAngle: Math.PI * 0.5,
    color: 0xe2e8f0,
    activeColor: 0x3b82f6,
    description: "Execute the decision. Take action and observe the results to begin the loop again."
  },

  // Middle ring - Strategy elements (5 segments, each 72° = 2π/5)
  landscape: {
    ring: "middle",
    label: "Landscape",
    startAngle: Math.PI * 1.5,
    endAngle: Math.PI * 1.9,
    color: 0xcbd5e1,
    activeColor: 0x22c55e,
    description: "The map itself - understanding position, movement, and the value chain. Where are we? Where are others?"
  },
  purpose_middle: {
    ring: "middle",
    label: "Purpose",
    startAngle: Math.PI * 1.9,
    endAngle: Math.PI * 2.3,
    color: 0xcbd5e1,
    activeColor: 0x22c55e,
    description: "The moral imperative and reason for being. Why do we exist? What do we serve? The foundation of all strategy."
  },
  leadership: {
    ring: "middle",
    label: "Leadership",
    startAngle: Math.PI * 0.3,
    endAngle: Math.PI * 0.7,
    color: 0xcbd5e1,
    activeColor: 0x22c55e,
    description: "Context-specific gameplay. What moves can we make? Attack, defend, position, accelerate, decelerate."
  },
  doctrine: {
    ring: "middle",
    label: "Doctrine",
    startAngle: Math.PI * 0.7,
    endAngle: Math.PI * 1.1,
    color: 0xcbd5e1,
    activeColor: 0x22c55e,
    description: "Universal principles of good practice. Focus on user needs, use appropriate methods, think small, be transparent."
  },
  climate: {
    ring: "middle",
    label: "Climate",
    startAngle: Math.PI * 1.1,
    endAngle: Math.PI * 1.5,
    color: 0xcbd5e1,
    activeColor: 0x22c55e,
    description: "External forces and patterns of change. What climatic patterns affect evolution? Competition, regulation, technology shifts."
  },

  // Inner ring - Why
  why_purpose: {
    ring: "inner",
    label: "Why of Purpose",
    startAngle: 0,
    endAngle: Math.PI,
    color: 0xf1f5f9,
    activeColor: 0xfbbf24,
    description: "The moral imperative. What is our reason for being? What do we serve? The core that guides all decisions."
  },
  why_movement: {
    ring: "inner",
    label: "Why of Movement",
    startAngle: Math.PI,
    endAngle: Math.PI * 2,
    color: 0xf1f5f9,
    activeColor: 0xfbbf24,
    description: "The direction of travel. Where are we going? What change do we seek? The vision that pulls us forward."
  }
}

// Ring radii
const OUTER_INNER = 3.5
const OUTER_OUTER = 4.5
const MIDDLE_INNER = 2.0
const MIDDLE_OUTER = 3.3
const INNER_INNER = 0.5
const INNER_OUTER = 1.8

function createArcShape(innerRadius, outerRadius, startAngle, endAngle) {
  const shape = new THREE.Shape()
  const segments = 32

  // Start at outer radius
  shape.moveTo(
    Math.cos(startAngle) * outerRadius,
    Math.sin(startAngle) * outerRadius
  )

  // Arc along outer edge
  for (let i = 0; i <= segments; i++) {
    const angle = startAngle + (endAngle - startAngle) * (i / segments)
    shape.lineTo(
      Math.cos(angle) * outerRadius,
      Math.sin(angle) * outerRadius
    )
  }

  // Line to inner radius
  shape.lineTo(
    Math.cos(endAngle) * innerRadius,
    Math.sin(endAngle) * innerRadius
  )

  // Arc back along inner edge
  for (let i = segments; i >= 0; i--) {
    const angle = startAngle + (endAngle - startAngle) * (i / segments)
    shape.lineTo(
      Math.cos(angle) * innerRadius,
      Math.sin(angle) * innerRadius
    )
  }

  shape.closePath()
  return shape
}

function getRadii(ring) {
  switch (ring) {
    case "outer":
      return { inner: OUTER_INNER, outer: OUTER_OUTER }
    case "middle":
      return { inner: MIDDLE_INNER, outer: MIDDLE_OUTER }
    case "inner":
      return { inner: INNER_INNER, outer: INNER_OUTER }
    default:
      return { inner: 1, outer: 2 }
  }
}

export function initGameplay() {
  const container = document.getElementById("threejs-canvas")
  if (!container) return

  const width = container.clientWidth
  const height = container.clientHeight

  // Scene setup
  const scene = new THREE.Scene()
  scene.background = new THREE.Color(0xf8fafc) // slate-50

  // Camera - orthographic for 2D-like view
  const aspect = width / height
  const viewSize = 6
  const camera = new THREE.OrthographicCamera(
    -viewSize * aspect,
    viewSize * aspect,
    viewSize,
    -viewSize,
    0.1,
    100
  )
  camera.position.z = 10

  // Renderer
  const renderer = new THREE.WebGLRenderer({ antialias: true })
  renderer.setSize(width, height)
  renderer.setPixelRatio(window.devicePixelRatio)
  container.appendChild(renderer.domElement)

  // State
  const activeSegments = new Set()
  const meshes = []
  const meshToSegment = new Map()

  // Create segment meshes
  for (const [key, segment] of Object.entries(SEGMENTS)) {
    const radii = getRadii(segment.ring)
    const shape = createArcShape(
      radii.inner,
      radii.outer,
      segment.startAngle,
      segment.endAngle
    )

    const geometry = new THREE.ShapeGeometry(shape)
    const material = new THREE.MeshBasicMaterial({
      color: segment.color,
      side: THREE.DoubleSide
    })

    const mesh = new THREE.Mesh(geometry, material)
    mesh.userData = { key, ...segment }
    scene.add(mesh)
    meshes.push(mesh)
    meshToSegment.set(mesh, key)

    // Add outline
    const edgeGeometry = new THREE.EdgesGeometry(geometry)
    const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x334155, linewidth: 1 })
    const edges = new THREE.LineSegments(edgeGeometry, edgeMaterial)
    scene.add(edges)
  }

  // Add center text
  const centerGroup = new THREE.Group()
  scene.add(centerGroup)

  // Create text labels using canvas
  function createTextSprite(text, fontSize, color, yOffset = 0) {
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
    const material = new THREE.SpriteMaterial({ map: texture })
    const sprite = new THREE.Sprite(material)
    sprite.scale.set(2, 0.5, 1)
    sprite.position.y = yOffset
    return sprite
  }


  // Add segment labels
  for (const [key, segment] of Object.entries(SEGMENTS)) {
    const radii = getRadii(segment.ring)
    const midAngle = (segment.startAngle + segment.endAngle) / 2
    const midRadius = (radii.inner + radii.outer) / 2

    const label = createTextSprite(segment.label, 16, "#1e293b")
    label.position.x = Math.cos(midAngle) * midRadius
    label.position.y = Math.sin(midAngle) * midRadius
    label.position.z = 0.1
    scene.add(label)
  }

  // Raycaster for interaction
  const raycaster = new THREE.Raycaster()
  const mouse = new THREE.Vector2()

  // Tooltip elements
  const tooltip = document.getElementById("tooltip")
  const tooltipTitle = document.getElementById("tooltip-title")
  const tooltipDesc = document.getElementById("tooltip-desc")
  const activeSegmentsEl = document.getElementById("active-segments")

  let hoveredMesh = null

  function updateActiveDisplay() {
    if (!activeSegmentsEl) return
    activeSegmentsEl.innerHTML = ""

    for (const key of activeSegments) {
      const segment = SEGMENTS[key]
      const badge = document.createElement("div")
      badge.className = "pointer-events-auto rounded-full bg-emerald-500 text-white px-3 py-1 text-xs font-medium shadow"
      badge.textContent = segment.label
      activeSegmentsEl.appendChild(badge)
    }
  }

  function onMouseMove(event) {
    const rect = renderer.domElement.getBoundingClientRect()
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1

    raycaster.setFromCamera(mouse, camera)
    const intersects = raycaster.intersectObjects(meshes)

    if (intersects.length > 0) {
      const mesh = intersects[0].object
      if (mesh !== hoveredMesh) {
        // Restore previous
        if (hoveredMesh && !activeSegments.has(hoveredMesh.userData.key)) {
          hoveredMesh.material.color.setHex(hoveredMesh.userData.color)
        }
        hoveredMesh = mesh

        // Highlight current (if not active)
        if (!activeSegments.has(mesh.userData.key)) {
          mesh.material.color.setHex(0x64748b)
        }

        // Show tooltip
        tooltipTitle.textContent = mesh.userData.label
        tooltipDesc.textContent = mesh.userData.description
        tooltip.classList.remove("hidden")
      }

      // Position tooltip
      tooltip.style.left = `${event.clientX + 15}px`
      tooltip.style.top = `${event.clientY + 15}px`
    } else {
      if (hoveredMesh && !activeSegments.has(hoveredMesh.userData.key)) {
        hoveredMesh.material.color.setHex(hoveredMesh.userData.color)
      }
      hoveredMesh = null
      tooltip.classList.add("hidden")
    }
  }

  function onClick(event) {
    const rect = renderer.domElement.getBoundingClientRect()
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1

    raycaster.setFromCamera(mouse, camera)
    const intersects = raycaster.intersectObjects(meshes)

    if (intersects.length > 0) {
      const mesh = intersects[0].object
      const key = mesh.userData.key
      const ring = mesh.userData.ring

      if (activeSegments.has(key)) {
        // Deselect this segment
        activeSegments.delete(key)
        mesh.material.color.setHex(mesh.userData.color)
      } else {
        // Deselect any other segment in the same ring first
        for (const otherKey of activeSegments) {
          const otherSegment = SEGMENTS[otherKey]
          if (otherSegment.ring === ring) {
            activeSegments.delete(otherKey)
            // Find and reset the mesh color
            const otherMesh = meshes.find(m => m.userData.key === otherKey)
            if (otherMesh) {
              otherMesh.material.color.setHex(otherSegment.color)
            }
          }
        }
        // Select this segment
        activeSegments.add(key)
        mesh.material.color.setHex(mesh.userData.activeColor)
      }

      updateActiveDisplay()
    }
  }

  renderer.domElement.addEventListener("mousemove", onMouseMove)
  renderer.domElement.addEventListener("click", onClick)

  // Handle resize
  function onResize() {
    const w = container.clientWidth
    const h = container.clientHeight
    const asp = w / h

    camera.left = -viewSize * asp
    camera.right = viewSize * asp
    camera.top = viewSize
    camera.bottom = -viewSize
    camera.updateProjectionMatrix()

    renderer.setSize(w, h)
  }

  window.addEventListener("resize", onResize)

  // Animation loop
  function animate() {
    requestAnimationFrame(animate)
    renderer.render(scene, camera)
  }

  animate()
}

// Auto-init
document.addEventListener("DOMContentLoaded", initGameplay)
