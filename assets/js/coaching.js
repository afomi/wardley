/**
 * Coaching Modal - Step navigation and interaction
 *
 * This module handles the coaching modal UI interactions.
 * LLM integration will be added later to provide intelligent coaching.
 */

export function initCoaching() {
  const modal = document.getElementById("coaching-modal")
  if (!modal) return

  const stepsNav = document.getElementById("coaching-steps")
  const contentArea = document.getElementById("coaching-content")
  const messagesArea = document.getElementById("coach-messages")
  const input = document.getElementById("coach-input")
  const sendBtn = document.getElementById("coach-send-btn")
  const exampleBtn = document.getElementById("coach-example-btn")
  const clearBtn = document.getElementById("coach-clear-btn")

  let currentStep = 1

  // Step navigation
  function showStep(stepNum) {
    currentStep = stepNum

    // Update step buttons
    stepsNav.querySelectorAll(".coaching-step").forEach(btn => {
      const btnStep = parseInt(btn.dataset.step, 10)
      btn.classList.remove("active", "completed")
      if (btnStep === stepNum) {
        btn.classList.add("active")
      } else if (btnStep < stepNum) {
        btn.classList.add("completed")
      }
    })

    // Update content panels
    contentArea.querySelectorAll(".step-content").forEach(panel => {
      const panelStep = parseInt(panel.dataset.stepContent, 10)
      panel.classList.toggle("hidden", panelStep !== stepNum)
    })

    // Update coach message for the step
    updateCoachMessage(stepNum)
  }

  // Coach messages for each step
  const stepMessages = {
    1: `Let's start by identifying who you're creating this map for. <strong>Who is the primary user of the system or service you want to map?</strong> (e.g., "customer", "developer", "business owner")`,
    2: `Now that we have a user, let's identify their needs. <strong>What does your user need from this system?</strong> Think about outcomes, not solutions. What problem are they trying to solve?`,
    3: `Let's build out the value chain. <strong>What components or capabilities are needed to deliver those user needs?</strong> Think about the products, services, data, and skills involved.`,
    4: `Now position each component on the evolution axis. <strong>For each component, is it novel (genesis), custom-built, a product/service, or a commodity?</strong> I can help you assess this.`,
    5: `Consider movement and change. <strong>Which components are evolving?</strong> Are there signs of commoditization, new entrants, or emerging standards?`,
    6: `Your map is taking shape! Now let's analyze it. <strong>What patterns do you see?</strong> Where are the opportunities and risks? What strategic options emerge?`
  }

  function updateCoachMessage(stepNum) {
    const message = stepMessages[stepNum]
    if (message) {
      addCoachMessage(message)
    }
  }

  function addCoachMessage(html) {
    const msgDiv = document.createElement("div")
    msgDiv.className = "flex gap-3"
    msgDiv.innerHTML = `
      <div class="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-cyan-500 flex items-center justify-center shrink-0">
        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
      </div>
      <div class="flex-1">
        <p class="text-sm text-slate-600 dark:text-slate-300">${html}</p>
      </div>
    `
    messagesArea.appendChild(msgDiv)
    messagesArea.scrollTop = messagesArea.scrollHeight
  }

  function addUserMessage(text) {
    const msgDiv = document.createElement("div")
    msgDiv.className = "flex gap-3 justify-end"
    msgDiv.innerHTML = `
      <div class="flex-1 text-right">
        <p class="inline-block text-sm text-slate-900 dark:text-slate-100 bg-slate-100 dark:bg-slate-800 rounded-lg px-3 py-2">${escapeHtml(text)}</p>
      </div>
      <div class="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center shrink-0">
        <svg class="w-4 h-4 text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
      </div>
    `
    messagesArea.appendChild(msgDiv)
    messagesArea.scrollTop = messagesArea.scrollHeight
  }

  function escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // Handle step button clicks
  stepsNav.addEventListener("click", e => {
    const btn = e.target.closest(".coaching-step")
    if (btn) {
      const step = parseInt(btn.dataset.step, 10)
      showStep(step)
    }
  })

  // Handle user input
  function handleUserInput() {
    const text = input.value.trim()
    if (!text) return

    addUserMessage(text)
    input.value = ""

    // For now, provide helpful responses based on current step
    // This will be replaced with LLM integration
    setTimeout(() => {
      processUserInput(text)
    }, 500)
  }

  function processUserInput(text) {
    // Simple pattern matching for demo - will be replaced by LLM
    const lowerText = text.toLowerCase()

    if (currentStep === 1) {
      // User identification step
      addCoachMessage(`Great! "<strong>${escapeHtml(text)}</strong>" will be your anchor user. I'll add them to your map at the top. Now let's move to defining their needs.`)

      // Add to map via DSL
      addToMap(`anchor ${text} [0.95, 0.50]`)

      setTimeout(() => showStep(2), 1000)
    } else if (currentStep === 2) {
      // User needs step
      addCoachMessage(`"<strong>${escapeHtml(text)}</strong>" is a good user need. I'll add it to your map connected to the user. What other needs does your user have? Or type "next" to continue.`)

      addToMap(`component ${text} [0.85, 0.50]`)

      if (lowerText === "next" || lowerText === "done") {
        setTimeout(() => showStep(3), 1000)
      }
    } else if (currentStep === 3) {
      // Value chain step
      addCoachMessage(`Adding "<strong>${escapeHtml(text)}</strong>" to your value chain. What does this component depend on? Or type "next" to position components.`)

      addToMap(`component ${text} [0.60, 0.50]`)

      if (lowerText === "next" || lowerText === "done") {
        setTimeout(() => showStep(4), 1000)
      }
    } else if (currentStep === 4) {
      // Evolution positioning
      addCoachMessage(`Good thinking about evolution. Remember: Genesis (novel, uncertain) → Custom (understood, bespoke) → Product (standardized) → Commodity (utility). Type "next" when you're ready to identify movement.`)

      if (lowerText === "next" || lowerText === "done") {
        setTimeout(() => showStep(5), 1000)
      }
    } else if (currentStep === 5) {
      // Movement identification
      addCoachMessage(`Movement and evolution are key to strategy. Components naturally evolve from genesis toward commodity. Type "next" when ready to analyze.`)

      if (lowerText === "next" || lowerText === "done") {
        setTimeout(() => showStep(6), 1000)
      }
    } else {
      // Analysis step
      addCoachMessage(`That's a good observation. Consider: Where can you differentiate? What's becoming commoditized? Where are the risks? Keep iterating on your map as your understanding deepens.`)
    }
  }

  function addToMap(dslLine) {
    // Add line to the code editor
    const codeEditor = document.getElementById("code-editor")
    if (codeEditor) {
      const currentCode = codeEditor.value.trim()
      codeEditor.value = currentCode ? `${currentCode}\n${dslLine}` : dslLine
      // Trigger input event to sync with map
      codeEditor.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  if (sendBtn) {
    sendBtn.addEventListener("click", handleUserInput)
  }

  if (input) {
    input.addEventListener("keydown", e => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        handleUserInput()
      }
    })
  }

  // Check if map has user content
  function mapHasContent() {
    const codeEditor = document.getElementById("code-editor")
    if (!codeEditor) return false
    const code = codeEditor.value.trim()
    // Consider it has content if there's more than just whitespace or comments
    const lines = code.split("\n").filter(line => {
      const trimmed = line.trim()
      return trimmed && !trimmed.startsWith("//") && !trimmed.startsWith("#")
    })
    return lines.length > 0
  }

  // Example map
  if (exampleBtn) {
    exampleBtn.addEventListener("click", () => {
      // Warn if map has content
      if (mapHasContent()) {
        const confirmed = window.confirm(
          "This will replace your current map with the example. Your existing map will be lost.\n\nAre you sure you want to continue?"
        )
        if (!confirmed) return
      }

      const exampleCode = `title Tea Shop
anchor Customer [0.95, 0.65]
component Cup of Tea [0.79, 0.61]
component Tea [0.63, 0.81]
component Hot Water [0.52, 0.89]
component Cup [0.47, 0.72]
component Kettle [0.35, 0.56]
component Power [0.1, 0.89]
component Water [0.17, 0.91]
Customer->Cup of Tea
Cup of Tea->Tea
Cup of Tea->Hot Water
Cup of Tea->Cup
Hot Water->Kettle
Hot Water->Water
Kettle->Power`

      const codeEditor = document.getElementById("code-editor")
      if (codeEditor) {
        codeEditor.value = exampleCode
        codeEditor.dispatchEvent(new Event("input", { bubbles: true }))
      }

      addCoachMessage(`I've loaded the classic "Tea Shop" example map. This shows a simple value chain from Customer through Cup of Tea down to commodities like Power and Water. Notice how components at the bottom-right are more evolved (commodities), while custom elements are further left.`)
    })
  }

  // Clear/start fresh
  if (clearBtn) {
    clearBtn.addEventListener("click", () => {
      // Warn if map has content
      if (mapHasContent()) {
        const confirmed = window.confirm(
          "This will clear your current map. All components and connections will be deleted.\n\nAre you sure you want to start fresh?"
        )
        if (!confirmed) return
      }

      const codeEditor = document.getElementById("code-editor")
      if (codeEditor) {
        codeEditor.value = ""
        codeEditor.dispatchEvent(new Event("input", { bubbles: true }))
      }

      // Reset to step 1
      showStep(1)

      // Clear messages except the first one
      while (messagesArea.children.length > 1) {
        messagesArea.removeChild(messagesArea.lastChild)
      }

      addCoachMessage(`Let's start fresh! Who is the primary user of the system or service you want to map?`)
    })
  }

  // Keyboard shortcut to open modal
  document.addEventListener("keydown", e => {
    if (e.key === "?" && !e.target.matches("input, textarea")) {
      e.preventDefault()
      modal.classList.toggle("hidden")
    }
    if (e.key === "Escape" && !modal.classList.contains("hidden")) {
      modal.classList.add("hidden")
    }
  })
}

// Auto-init
document.addEventListener("DOMContentLoaded", initCoaching)
