defmodule WardleyWeb.MapComponents do
  @moduledoc """
  Shared components for Wardley Map editors.
  """
  use Phoenix.Component

  @doc """
  Renders a large coaching modal for guiding users through Wardley Mapping.

  The modal includes step-by-step progression through mapping concepts,
  a chat interface for LLM coaching, and contextual help.
  """
  attr :id, :string, default: "coaching-modal"

  def coaching_modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="hidden fixed inset-0 z-50"
      role="dialog"
      aria-modal="true"
      aria-labelledby="coaching-modal-title"
    >
      <!-- Backdrop -->
      <div
        id={"#{@id}-backdrop"}
        class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm"
        onclick={"document.getElementById('#{@id}').classList.add('hidden')"}
      >
      </div>
      <!-- Modal -->
      <div class="fixed inset-4 md:inset-8 lg:inset-12 flex items-center justify-center">
        <div class="relative w-full h-full max-w-6xl bg-white dark:bg-slate-900 rounded-xl shadow-2xl flex flex-col overflow-hidden">
          <!-- Header -->
          <div class="flex items-center justify-between px-6 py-4 border-b border-slate-200 dark:border-slate-800">
            <div class="flex items-center gap-3">
              <div class="w-10 h-10 rounded-full bg-gradient-to-br from-emerald-400 to-cyan-500 flex items-center justify-center">
                <svg
                  class="w-6 h-6 text-white"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
                  />
                </svg>
              </div>
              <div>
                <h2
                  id="coaching-modal-title"
                  class="text-lg font-semibold text-slate-900 dark:text-slate-100"
                >
                  Mapping Coach
                </h2>
                <p class="text-sm text-slate-500 dark:text-slate-400">
                  Learn to create effective Wardley Maps
                </p>
              </div>
            </div>
            <button
              type="button"
              onclick={"document.getElementById('#{@id}').classList.add('hidden')"}
              class="p-2 rounded-lg text-slate-400 hover:text-slate-600 hover:bg-slate-100 dark:hover:text-slate-300 dark:hover:bg-slate-800"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <!-- Content -->
          <div class="flex-1 flex overflow-hidden">
            <!-- Sidebar: Steps -->
            <aside class="w-64 shrink-0 border-r border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950 p-4 overflow-y-auto">
              <h3 class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-3">
                Mapping Journey
              </h3>
              <nav
                id="coaching-steps"
                class="space-y-1"
              >
                <button
                  type="button"
                  data-step="1"
                  class="coaching-step active w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  <span class="flex items-center gap-2">
                    <span class="w-6 h-6 rounded-full bg-emerald-500 text-white text-xs flex items-center justify-center">
                      1
                    </span>
                    Identify the User
                  </span>
                </button>
                <button
                  type="button"
                  data-step="2"
                  class="coaching-step w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  <span class="flex items-center gap-2">
                    <span class="w-6 h-6 rounded-full bg-slate-300 dark:bg-slate-700 text-slate-600 dark:text-slate-400 text-xs flex items-center justify-center">
                      2
                    </span>
                    Define User Needs
                  </span>
                </button>
                <button
                  type="button"
                  data-step="3"
                  class="coaching-step w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  <span class="flex items-center gap-2">
                    <span class="w-6 h-6 rounded-full bg-slate-300 dark:bg-slate-700 text-slate-600 dark:text-slate-400 text-xs flex items-center justify-center">
                      3
                    </span>
                    Map the Value Chain
                  </span>
                </button>
                <button
                  type="button"
                  data-step="4"
                  class="coaching-step w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  <span class="flex items-center gap-2">
                    <span class="w-6 h-6 rounded-full bg-slate-300 dark:bg-slate-700 text-slate-600 dark:text-slate-400 text-xs flex items-center justify-center">
                      4
                    </span>
                    Position by Evolution
                  </span>
                </button>
                <button
                  type="button"
                  data-step="5"
                  class="coaching-step w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  <span class="flex items-center gap-2">
                    <span class="w-6 h-6 rounded-full bg-slate-300 dark:bg-slate-700 text-slate-600 dark:text-slate-400 text-xs flex items-center justify-center">
                      5
                    </span>
                    Identify Movement
                  </span>
                </button>
                <button
                  type="button"
                  data-step="6"
                  class="coaching-step w-full text-left px-3 py-2 rounded-lg text-sm font-medium transition-colors"
                >
                  <span class="flex items-center gap-2">
                    <span class="w-6 h-6 rounded-full bg-slate-300 dark:bg-slate-700 text-slate-600 dark:text-slate-400 text-xs flex items-center justify-center">
                      6
                    </span>
                    Analyze &amp; Decide
                  </span>
                </button>
              </nav>
              <div class="mt-6 pt-4 border-t border-slate-200 dark:border-slate-800">
                <h3 class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-3">
                  Quick Actions
                </h3>
                <div class="space-y-2">
                  <button
                    type="button"
                    id="coach-example-btn"
                    class="w-full text-left px-3 py-2 rounded-lg text-sm text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    Load example map
                  </button>
                  <button
                    type="button"
                    id="coach-clear-btn"
                    class="w-full text-left px-3 py-2 rounded-lg text-sm text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
                  >
                    Start fresh
                  </button>
                </div>
              </div>
            </aside>
            <!-- Main content area -->
            <div class="flex-1 flex flex-col overflow-hidden">
              <!-- Step content -->
              <div
                id="coaching-content"
                class="flex-1 overflow-y-auto p-6"
              >
                <!-- Step 1: Identify the User -->
                <div
                  data-step-content="1"
                  class="step-content"
                >
                  <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
                    Step 1: Identify the User
                  </h3>
                  <div class="prose dark:prose-invert max-w-none">
                    <p class="text-slate-600 dark:text-slate-300">
                      Every map starts with a <strong>user</strong> - the person or entity whose needs you're trying to serve. This anchors your map and gives it purpose.
                    </p>
                    <div class="mt-4 p-4 bg-emerald-50 dark:bg-emerald-900/20 rounded-lg border border-emerald-200 dark:border-emerald-800">
                      <h4 class="font-medium text-emerald-800 dark:text-emerald-300 mb-2">
                        Ask yourself:
                      </h4>
                      <ul class="text-sm text-emerald-700 dark:text-emerald-400 space-y-1">
                        <li>Who is the primary user of this system or service?</li>
                        <li>What role do they play?</li>
                        <li>Are there multiple user types to consider?</li>
                      </ul>
                    </div>
                    <div class="mt-4 p-4 bg-slate-100 dark:bg-slate-800 rounded-lg">
                      <h4 class="font-medium text-slate-700 dark:text-slate-200 mb-2">
                        Example users:
                      </h4>
                      <div class="flex flex-wrap gap-2">
                        <span class="px-3 py-1 bg-white dark:bg-slate-700 rounded-full text-sm text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-600">
                          Customer
                        </span>
                        <span class="px-3 py-1 bg-white dark:bg-slate-700 rounded-full text-sm text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-600">
                          Developer
                        </span>
                        <span class="px-3 py-1 bg-white dark:bg-slate-700 rounded-full text-sm text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-600">
                          Business Owner
                        </span>
                        <span class="px-3 py-1 bg-white dark:bg-slate-700 rounded-full text-sm text-slate-600 dark:text-slate-300 border border-slate-200 dark:border-slate-600">
                          End User
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
                <!-- Step 2: Define User Needs -->
                <div
                  data-step-content="2"
                  class="step-content hidden"
                >
                  <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
                    Step 2: Define User Needs
                  </h3>
                  <div class="prose dark:prose-invert max-w-none">
                    <p class="text-slate-600 dark:text-slate-300">
                      What does your user actually need? These needs sit at the top of your map, directly connected to the user. They should be expressed as outcomes, not solutions.
                    </p>
                    <div class="mt-4 p-4 bg-emerald-50 dark:bg-emerald-900/20 rounded-lg border border-emerald-200 dark:border-emerald-800">
                      <h4 class="font-medium text-emerald-800 dark:text-emerald-300 mb-2">
                        Good needs are:
                      </h4>
                      <ul class="text-sm text-emerald-700 dark:text-emerald-400 space-y-1">
                        <li>
                          <strong>Outcome-focused</strong>
                          - "fast checkout" not "payment system"
                        </li>
                        <li>
                          <strong>Visible to the user</strong>
                          - things they can perceive
                        </li>
                        <li>
                          <strong>Valuable</strong>
                          - something they'd pay for or care about
                        </li>
                      </ul>
                    </div>
                  </div>
                </div>
                <!-- Step 3: Map the Value Chain -->
                <div
                  data-step-content="3"
                  class="step-content hidden"
                >
                  <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
                    Step 3: Map the Value Chain
                  </h3>
                  <div class="prose dark:prose-invert max-w-none">
                    <p class="text-slate-600 dark:text-slate-300">
                      Now work downward: what components are needed to fulfill each user need? Each component depends on others below it, forming a chain of value.
                    </p>
                    <div class="mt-4 p-4 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-800">
                      <h4 class="font-medium text-amber-800 dark:text-amber-300 mb-2">
                        Keep asking:
                      </h4>
                      <p class="text-sm text-amber-700 dark:text-amber-400">
                        "What does this component need to exist?" Keep going until you reach fundamental building blocks like compute, data, or skills.
                      </p>
                    </div>
                  </div>
                </div>
                <!-- Step 4: Position by Evolution -->
                <div
                  data-step-content="4"
                  class="step-content hidden"
                >
                  <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
                    Step 4: Position by Evolution
                  </h3>
                  <div class="prose dark:prose-invert max-w-none">
                    <p class="text-slate-600 dark:text-slate-300">
                      Place each component along the evolution axis based on how mature it is. This is the X-axis of your map.
                    </p>
                    <div class="mt-4 grid grid-cols-4 gap-2 text-center text-sm">
                      <div class="p-3 bg-purple-100 dark:bg-purple-900/30 rounded-lg">
                        <div class="font-semibold text-purple-800 dark:text-purple-300">
                          Genesis
                        </div>
                        <div class="text-xs text-purple-600 dark:text-purple-400 mt-1">
                          Novel, uncertain, requires exploration
                        </div>
                      </div>
                      <div class="p-3 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                        <div class="font-semibold text-blue-800 dark:text-blue-300">
                          Custom
                        </div>
                        <div class="text-xs text-blue-600 dark:text-blue-400 mt-1">
                          Understood but bespoke, built for specific needs
                        </div>
                      </div>
                      <div class="p-3 bg-green-100 dark:bg-green-900/30 rounded-lg">
                        <div class="font-semibold text-green-800 dark:text-green-300">
                          Product
                        </div>
                        <div class="text-xs text-green-600 dark:text-green-400 mt-1">
                          Standardized, available as products/services
                        </div>
                      </div>
                      <div class="p-3 bg-slate-100 dark:bg-slate-800 rounded-lg">
                        <div class="font-semibold text-slate-800 dark:text-slate-300">
                          Commodity
                        </div>
                        <div class="text-xs text-slate-600 dark:text-slate-400 mt-1">
                          Ubiquitous, utility, taken for granted
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
                <!-- Step 5: Identify Movement -->
                <div
                  data-step-content="5"
                  class="step-content hidden"
                >
                  <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
                    Step 5: Identify Movement
                  </h3>
                  <div class="prose dark:prose-invert max-w-none">
                    <p class="text-slate-600 dark:text-slate-300">
                      Everything evolves. Identify which components are moving and in what direction. This reveals opportunities and threats.
                    </p>
                    <div class="mt-4 p-4 bg-cyan-50 dark:bg-cyan-900/20 rounded-lg border border-cyan-200 dark:border-cyan-800">
                      <h4 class="font-medium text-cyan-800 dark:text-cyan-300 mb-2">
                        Signs of movement:
                      </h4>
                      <ul class="text-sm text-cyan-700 dark:text-cyan-400 space-y-1">
                        <li>New competitors entering with simpler solutions</li>
                        <li>Increasing standardization or APIs emerging</li>
                        <li>Prices dropping while capability increases</li>
                        <li>Open source alternatives appearing</li>
                      </ul>
                    </div>
                  </div>
                </div>
                <!-- Step 6: Analyze & Decide -->
                <div
                  data-step-content="6"
                  class="step-content hidden"
                >
                  <h3 class="text-xl font-semibold text-slate-900 dark:text-slate-100 mb-4">
                    Step 6: Analyze &amp; Decide
                  </h3>
                  <div class="prose dark:prose-invert max-w-none">
                    <p class="text-slate-600 dark:text-slate-300">
                      Your map is now a tool for strategic thinking. Look for patterns, opportunities, and risks.
                    </p>
                    <div class="mt-4 grid grid-cols-2 gap-4">
                      <div class="p-4 bg-emerald-50 dark:bg-emerald-900/20 rounded-lg border border-emerald-200 dark:border-emerald-800">
                        <h4 class="font-medium text-emerald-800 dark:text-emerald-300 mb-2">
                          Opportunities
                        </h4>
                        <ul class="text-sm text-emerald-700 dark:text-emerald-400 space-y-1">
                          <li>Components ripe for commoditization</li>
                          <li>Gaps in the value chain</li>
                          <li>Areas for differentiation</li>
                        </ul>
                      </div>
                      <div class="p-4 bg-red-50 dark:bg-red-900/20 rounded-lg border border-red-200 dark:border-red-800">
                        <h4 class="font-medium text-red-800 dark:text-red-300 mb-2">
                          Risks
                        </h4>
                        <ul class="text-sm text-red-700 dark:text-red-400 space-y-1">
                          <li>Dependencies on evolving components</li>
                          <li>Inertia in your organization</li>
                          <li>Competitor movement</li>
                        </ul>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
              <!-- Chat interface -->
              <div class="border-t border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-950">
                <div
                  id="coach-messages"
                  class="h-32 overflow-y-auto p-4 space-y-3"
                >
                  <div class="flex gap-3">
                    <div class="w-8 h-8 rounded-full bg-gradient-to-br from-emerald-400 to-cyan-500 flex items-center justify-center shrink-0">
                      <svg
                        class="w-4 h-4 text-white"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
                        />
                      </svg>
                    </div>
                    <div class="flex-1">
                      <p class="text-sm text-slate-600 dark:text-slate-300">
                        Welcome! I'm here to help you create your Wardley Map. Let's start by identifying who you're creating this map for. <strong>Who is the primary user of the system or service you want to map?</strong>
                      </p>
                    </div>
                  </div>
                </div>
                <div class="p-4 pt-0">
                  <div class="flex gap-2">
                    <input
                      type="text"
                      id="coach-input"
                      placeholder="Describe your user, need, or ask a question..."
                      class="flex-1 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-4 py-2 text-sm text-slate-900 dark:text-slate-100 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-emerald-500 focus:border-transparent"
                    />
                    <button
                      type="button"
                      id="coach-send-btn"
                      class="px-4 py-2 bg-emerald-500 hover:bg-emerald-600 text-white rounded-lg text-sm font-medium transition-colors"
                    >
                      Send
                    </button>
                  </div>
                  <p class="mt-2 text-xs text-slate-400">
                    Tip: Describe what you're mapping and I'll help translate it into map components.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <style>
      .coaching-step {
        color: rgb(100 116 139); /* slate-500 */
      }
      .coaching-step:hover {
        background-color: rgb(241 245 249); /* slate-100 */
      }
      .dark .coaching-step:hover {
        background-color: rgb(30 41 59); /* slate-800 */
      }
      .coaching-step.active {
        background-color: rgb(236 253 245); /* emerald-50 */
        color: rgb(6 95 70); /* emerald-800 */
      }
      .dark .coaching-step.active {
        background-color: rgba(16, 185, 129, 0.1); /* emerald-500/10 */
        color: rgb(110 231 183); /* emerald-300 */
      }
      .coaching-step.completed span:first-child span:first-child {
        background-color: rgb(16 185 129); /* emerald-500 */
        color: white;
      }
    </style>
    """
  end

  @doc """
  Renders the layer editor panel with stacked textareas for multi-map editing.
  The active map (top) is editable, overlay layers below are read-only.
  """
  attr :class, :string, default: nil

  def layer_editor_panel(assigns) do
    ~H"""
    <aside
      id="code-panel"
      class={[
        "w-[400px] shrink-0 border-r border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex flex-col",
        @class
      ]}
    >
      <div class="flex items-center justify-between px-3 py-2 border-b border-slate-200 dark:border-slate-800">
        <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          Map Code
        </h3>
        <div class="flex items-center gap-2">
          <span
            id="parse-status"
            class="text-xs text-slate-500"
          >
          </span>
          <button
            id="toggle-code-panel"
            type="button"
            class="p-1 rounded text-slate-500 hover:text-slate-700 hover:bg-slate-100 dark:hover:text-slate-300 dark:hover:bg-slate-800"
            title="Toggle code panel"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 19l-7-7 7-7m8 14l-7-7 7-7"
              />
            </svg>
          </button>
        </div>
      </div>
      <!-- Dynamic layer stack container - populated by JS -->
      <div
        id="layer-stack"
        class="flex-1 overflow-y-auto"
      >
        <!-- Active layer section (will be first) -->
        <div
          id="active-layer-section"
          class="border-b border-slate-200 dark:border-slate-800"
        >
          <button
            type="button"
            id="active-layer-header"
            class="w-full flex items-center justify-between px-3 py-2 bg-emerald-50 dark:bg-emerald-900/20 hover:bg-emerald-100 dark:hover:bg-emerald-900/30 transition-colors"
          >
            <div class="flex items-center gap-2">
              <svg
                id="active-layer-chevron"
                class="w-4 h-4 text-emerald-600 dark:text-emerald-400 transition-transform"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M19 9l-7 7-7-7"
                />
              </svg>
              <span
                id="active-layer-name"
                class="text-sm font-medium text-emerald-700 dark:text-emerald-300"
              >
                Loading...
              </span>
              <span class="text-xs text-emerald-600 dark:text-emerald-400">
                (active)
              </span>
            </div>
            <svg
              class="w-4 h-4 text-emerald-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
              />
            </svg>
          </button>
          <div
            id="active-layer-content"
            class="relative"
          >
            <textarea
              id="code-editor"
              class="w-full p-3 font-mono text-sm bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-200 border-none outline-none resize-none"
              style="min-height: 200px; height: auto;"
              placeholder={"title My Map\n\nanchor User [0.95, 0.50]\ncomponent Need [0.80, 0.50]\nUser->Need"}
              spellcheck="false"
            ></textarea>
            <div
              id="parse-errors"
              class="hidden px-3 py-2 border-t border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20 text-xs text-red-700 dark:text-red-400 max-h-24 overflow-y-auto"
            >
            </div>
          </div>
        </div>
        <!-- Overlay layers will be inserted here by JS -->
        <div id="overlay-layers-container">
        </div>
        <!-- Add layer button -->
        <div class="p-3 border-t border-slate-200 dark:border-slate-800">
          <button
            type="button"
            id="add-layer-btn"
            class="w-full flex items-center justify-center gap-2 px-3 py-2 rounded border border-dashed border-slate-300 dark:border-slate-700 text-sm text-slate-600 dark:text-slate-400 hover:border-slate-400 hover:text-slate-700 dark:hover:border-slate-600 dark:hover:text-slate-300 transition-colors"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M12 4v16m8-8H4"
              />
            </svg>
            Add Layer
          </button>
        </div>
      </div>
      <!-- GitHub sync status and buttons (pinned to bottom) -->
      <div
        id="github-sync-bar"
        class="shrink-0 flex items-center justify-between px-3 py-2 border-t border-slate-200 dark:border-slate-800 bg-slate-100 dark:bg-slate-800/50"
      >
        <div class="flex items-center gap-2">
          <svg
            class="w-4 h-4 text-slate-500"
            fill="currentColor"
            viewBox="0 0 24 24"
          >
            <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
          </svg>
          <span
            id="github-sync-status"
            class="text-xs text-slate-500 dark:text-slate-400"
          >
            Not configured
          </span>
        </div>
        <div class="flex items-center gap-1">
          <button
            type="button"
            id="github-pull-btn"
            class="hidden p-1.5 rounded text-slate-500 hover:text-slate-700 hover:bg-slate-200 dark:hover:text-slate-300 dark:hover:bg-slate-700 transition-colors"
            title="Pull from GitHub"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
              />
            </svg>
          </button>
          <button
            type="button"
            id="github-push-btn"
            class="hidden p-1.5 rounded text-slate-500 hover:text-slate-700 hover:bg-slate-200 dark:hover:text-slate-300 dark:hover:bg-slate-700 transition-colors"
            title="Push to GitHub"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12"
              />
            </svg>
          </button>
          <button
            type="button"
            id="github-settings-btn"
            class="p-1.5 rounded text-slate-500 hover:text-slate-700 hover:bg-slate-200 dark:hover:text-slate-300 dark:hover:bg-slate-700 transition-colors"
            title="GitHub settings"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
              />
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
              />
            </svg>
          </button>
        </div>
      </div>
    </aside>
    <!-- Map selector modal -->
    <.map_selector_modal />
    <!-- GitHub settings modal -->
    <.github_settings_modal />
    """
  end

  @doc """
  Renders the GitHub settings modal for configuring repository sync.
  """
  def github_settings_modal(assigns) do
    ~H"""
    <div
      id="github-settings-modal"
      class="hidden fixed inset-0 z-50"
    >
      <div
        class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm"
        onclick="document.getElementById('github-settings-modal').classList.add('hidden')"
      >
      </div>
      <div class="fixed inset-0 flex items-center justify-center p-4">
        <div class="bg-white dark:bg-slate-900 rounded-xl shadow-xl w-full max-w-md overflow-hidden">
          <div class="px-4 py-3 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <svg
                class="w-5 h-5 text-slate-700 dark:text-slate-300"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" />
              </svg>
              <h3 class="font-semibold text-slate-900 dark:text-slate-100">
                GitHub Sync Settings
              </h3>
            </div>
            <button
              type="button"
              onclick="document.getElementById('github-settings-modal').classList.add('hidden')"
              class="p-1 rounded text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <form
            id="github-settings-form"
            class="p-4 space-y-4"
          >
            <div>
              <label
                for="github-token"
                class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
              >
                Personal Access Token
              </label>
              <input
                type="password"
                id="github-token"
                name="token"
                placeholder="ghp_xxxxxxxxxxxxxxxxxxxx"
                class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
              />
              <p class="mt-1 text-xs text-slate-500">
                Requires <code class="bg-slate-100 dark:bg-slate-800 px-1 rounded">repo</code> scope.
                <a
                  href="https://github.com/settings/tokens/new?scopes=repo&description=Wardley.app"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-blue-600 dark:text-blue-400 hover:underline"
                >
                  Create token
                </a>
              </p>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label
                  for="github-owner"
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
                >
                  Owner
                </label>
                <input
                  type="text"
                  id="github-owner"
                  name="owner"
                  placeholder="username or org"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                />
              </div>
              <div>
                <label
                  for="github-repo"
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
                >
                  Repository
                </label>
                <input
                  type="text"
                  id="github-repo"
                  name="repo"
                  placeholder="my-maps"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                />
              </div>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label
                  for="github-branch"
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
                >
                  Branch
                </label>
                <input
                  type="text"
                  id="github-branch"
                  name="branch"
                  placeholder="main"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                />
              </div>
              <div>
                <label
                  for="github-path"
                  class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
                >
                  File Path
                </label>
                <input
                  type="text"
                  id="github-path"
                  name="path"
                  placeholder="maps/my-map.wm"
                  class="w-full px-3 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-800 text-slate-900 dark:text-white placeholder-slate-400 focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
                />
              </div>
            </div>
            <div
              id="github-settings-error"
              class="hidden text-sm text-red-600 dark:text-red-400"
            >
            </div>
            <div
              id="github-settings-success"
              class="hidden text-sm text-green-600 dark:text-green-400"
            >
            </div>
            <div class="flex items-center justify-between pt-2">
              <button
                type="button"
                id="github-disconnect-btn"
                class="hidden text-sm text-red-600 dark:text-red-400 hover:underline"
              >
                Disconnect
              </button>
              <div class="flex items-center gap-2 ml-auto">
                <button
                  type="button"
                  onclick="document.getElementById('github-settings-modal').classList.add('hidden')"
                  class="px-4 py-2 text-sm text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 text-sm bg-slate-900 dark:bg-slate-100 text-white dark:text-slate-900 rounded-lg hover:bg-slate-800 dark:hover:bg-white transition-colors"
                >
                  Save
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the map selector modal for choosing maps to overlay as layers.
  """
  def map_selector_modal(assigns) do
    ~H"""
    <div
      id="map-selector-modal"
      class="hidden fixed inset-0 z-50"
    >
      <div
        class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm"
        onclick="document.getElementById('map-selector-modal').classList.add('hidden')"
      >
      </div>
      <div class="fixed inset-0 flex items-center justify-center p-4">
        <div class="bg-white dark:bg-slate-900 rounded-xl shadow-xl w-full max-w-md overflow-hidden">
          <div class="px-4 py-3 border-b border-slate-200 dark:border-slate-800 flex items-center justify-between">
            <h3 class="font-semibold text-slate-900 dark:text-slate-100">
              Select Map to Overlay
            </h3>
            <button
              type="button"
              onclick="document.getElementById('map-selector-modal').classList.add('hidden')"
              class="p-1 rounded text-slate-400 hover:text-slate-600 dark:hover:text-slate-300"
            >
              <svg
                class="w-5 h-5"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
          <div
            id="map-selector-list"
            class="p-2 max-h-80 overflow-y-auto"
          >
            <p class="text-center text-slate-500 py-4">
              Loading maps...
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders the code editor panel for DSL input.
  Deprecated: Use layer_editor_panel instead.
  """
  attr :class, :string, default: nil

  def code_editor_panel(assigns) do
    ~H"""
    <aside
      id="code-panel"
      class={[
        "w-[400px] shrink-0 border-r border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 flex flex-col",
        @class
      ]}
    >
      <div class="flex items-center justify-between px-3 py-2 border-b border-slate-200 dark:border-slate-800">
        <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
          Map Code
        </h3>
        <div class="flex items-center gap-2">
          <span
            id="parse-status"
            class="text-xs text-slate-500"
          >
          </span>
          <button
            id="toggle-code-panel"
            type="button"
            class="p-1 rounded text-slate-500 hover:text-slate-700 hover:bg-slate-100 dark:hover:text-slate-300 dark:hover:bg-slate-800"
            title="Toggle code panel"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M11 19l-7-7 7-7m8 14l-7-7 7-7"
              />
            </svg>
          </button>
        </div>
      </div>
      <div class="flex-1 overflow-hidden">
        <textarea
          id="code-editor"
          class="w-full h-full p-3 font-mono text-sm bg-slate-50 dark:bg-slate-950 text-slate-800 dark:text-slate-200 border-none outline-none resize-none"
          placeholder={"title My Map\n\nanchor User [0.95, 0.50]\ncomponent Need [0.80, 0.50]\nUser->Need"}
          spellcheck="false"
        ></textarea>
      </div>
      <div
        id="parse-errors"
        class="hidden px-3 py-2 border-t border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20 text-xs text-red-700 dark:text-red-400 max-h-24 overflow-y-auto"
      >
      </div>
    </aside>
    """
  end

  @doc """
  Renders the node details panel for editing node properties.
  """
  attr :class, :string, default: nil

  def node_details_panel(assigns) do
    ~H"""
    <aside class={[
      "w-[280px] shrink-0 border-l border-slate-200 dark:border-slate-800 bg-white/70 dark:bg-slate-900/40 backdrop-blur p-4",
      @class
    ]}>
      <h3 class="text-sm font-semibold text-slate-700 dark:text-slate-200">
        Node details
      </h3>
      <p
        id="drawer-empty"
        class="mt-2 text-xs text-slate-500"
      >
        Click a node to view and edit details.
      </p>
      <form
        id="node-form"
        class="mt-3 space-y-3 hidden"
      >
        <input
          type="hidden"
          id="node-id"
        />
        <div>
          <label
            for="node-text"
            class="block text-xs font-medium text-slate-600 dark:text-slate-300"
          >
            Label
          </label>
          <input
            id="node-text"
            type="text"
            class="mt-1 w-full rounded border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-2 py-1 text-sm"
          />
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label
              for="node-x"
              class="block text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              X (evolution %)
            </label>
            <input
              id="node-x"
              type="number"
              min="0"
              max="100"
              step="0.1"
              class="mt-1 w-full rounded border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-2 py-1 text-sm"
            />
          </div>
          <div>
            <label
              for="node-y"
              class="block text-xs font-medium text-slate-600 dark:text-slate-300"
            >
              Y (visibility %)
            </label>
            <input
              id="node-y"
              type="number"
              min="0"
              max="100"
              step="0.1"
              class="mt-1 w-full rounded border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-2 py-1 text-sm"
            />
          </div>
        </div>
        <div>
          <div class="flex items-center justify-between">
            <label class="block text-xs font-medium text-slate-600 dark:text-slate-300">
              Metadata
            </label>
            <button
              type="button"
              id="meta-add"
              class="inline-flex items-center rounded border border-slate-300 dark:border-slate-700 px-2 py-1 text-xs text-slate-700 dark:text-slate-200"
            >
              Add field
            </button>
          </div>
          <div
            id="meta-fields"
            class="mt-2 space-y-2"
          >
          </div>
        </div>
        <div class="flex justify-between items-center">
          <button
            type="submit"
            class="inline-flex items-center rounded bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900 px-3 py-1.5 text-sm"
          >
            Save
          </button>
          <button
            type="button"
            id="node-delete"
            class="inline-flex items-center rounded border border-red-300 text-red-700 dark:border-red-800 dark:text-red-300 px-3 py-1.5 text-sm"
          >
            Delete
          </button>
        </div>
      </form>
    </aside>
    """
  end

  @doc """
  Renders the map overlay hints and badges.
  """
  attr :class, :string, default: nil

  def map_overlay(assigns) do
    ~H"""
    <div class="pointer-events-none absolute left-[400px] top-0 right-[280px] p-3 flex justify-between items-start text-slate-500 text-xs">
      <div class="pointer-events-auto rounded bg-white/80 dark:bg-slate-900/60 backdrop-blur px-2 py-1 border border-slate-200 dark:border-slate-800 shadow-sm">
        Y: Visibility (top = more visible)
      </div>
      <div class="flex items-center gap-2">
        <div class="pointer-events-auto rounded bg-white/80 dark:bg-slate-900/60 backdrop-blur px-2 py-1 border border-slate-200 dark:border-slate-800 shadow-sm">
          X: Evolution (genesis → custom → product → commodity)
        </div>
        <button
          type="button"
          id="open-coach-btn"
          onclick="document.getElementById('coaching-modal').classList.remove('hidden')"
          class="pointer-events-auto flex items-center gap-1.5 rounded bg-gradient-to-r from-emerald-500 to-cyan-500 text-white px-3 py-1 border border-emerald-400 shadow-sm hover:from-emerald-600 hover:to-cyan-600 transition-colors"
        >
          <svg
            class="w-4 h-4"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"
            />
          </svg>
          Coach
        </button>
        <div
          id="line-mode-badge"
          class="hidden pointer-events-auto rounded bg-emerald-100 text-emerald-700 dark:bg-emerald-900/50 dark:text-emerald-300 px-2 py-1 border border-emerald-200 dark:border-emerald-800 shadow-sm"
        >
          Line mode
        </div>
      </div>
    </div>
    <div class="pointer-events-none absolute bottom-3 left-[400px] right-[280px] flex justify-center text-slate-400 text-xs select-none">
      Click to add node · Drag to reposition · Line mode: press L, click two nodes
    </div>
    <div
      id="undo-toast"
      class="hidden pointer-events-auto absolute bottom-3 right-[300px] text-xs"
    >
      <div class="inline-flex items-center gap-2 rounded border border-slate-300 dark:border-slate-700 bg-white/90 dark:bg-slate-900/70 backdrop-blur px-3 py-2 text-slate-700 dark:text-slate-200 shadow">
        <span id="undo-message">Node deleted.</span>
        <button
          id="undo-button"
          class="inline-flex items-center rounded bg-slate-900 text-white dark:bg-slate-100 dark:text-slate-900 px-2 py-1"
        >
          Undo
        </button>
      </div>
    </div>
    """
  end
end
