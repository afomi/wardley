defmodule WardleyWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WardleyWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="px-4 sm:px-6 lg:px-8 border-b border-slate-200 dark:border-slate-800 bg-white/80 dark:bg-slate-900/60 backdrop-blur supports-[backdrop-filter]:bg-white/60">
      <div class="mx-auto max-w-6xl h-14 flex items-center justify-between">
        <a
          href="/"
          class="text-lg font-semibold text-slate-900 dark:text-slate-100 hover:text-slate-700 dark:hover:text-slate-300 transition"
        >
          Wardley.app
        </a>
        <nav class="flex items-center gap-1">
          <button
            type="button"
            onclick="window.openSearchModal()"
            class="p-2 rounded-md text-slate-500 hover:text-slate-700 hover:bg-slate-100 dark:text-slate-400 dark:hover:text-white dark:hover:bg-slate-800 transition"
            title="Search (Ctrl+K)"
          >
            <.icon
              name="hero-magnifying-glass"
              class="size-5"
            />
          </button>
          <a
            href={~p"/map"}
            class="px-3 py-1.5 text-sm rounded-md text-slate-700 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-300 dark:hover:text-white dark:hover:bg-slate-800 transition"
          >
            Map
          </a>
          <a
            href={~p"/gameplay"}
            class="px-3 py-1.5 text-sm rounded-md text-slate-700 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-300 dark:hover:text-white dark:hover:bg-slate-800 transition"
          >
            Gameplay
          </a>
          <a
            href={~p"/personas"}
            class="px-3 py-1.5 text-sm rounded-md text-slate-700 hover:text-slate-900 hover:bg-slate-100 dark:text-slate-300 dark:hover:text-white dark:hover:bg-slate-800 transition"
          >
            Personas
          </a>
        </nav>
      </div>
    </header>

    <.search_modal />

    <main class="px-4 py-12 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders the search modal overlay.

  Opens via JavaScript (window.openSearchModal) and closes on Escape or backdrop click.
  Provides quick search with results that link to the full search page.
  """
  def search_modal(assigns) do
    ~H"""
    <div
      id="search-modal"
      class="hidden fixed inset-0 z-50"
      role="dialog"
      aria-modal="true"
      aria-labelledby="search-modal-title"
    >
      <!-- Backdrop -->
      <div
        class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm"
        onclick="window.closeSearchModal()"
      >
      </div>

      <!-- Modal -->
      <div class="fixed inset-x-4 top-8 sm:inset-x-auto sm:left-1/2 sm:-translate-x-1/2 sm:w-full sm:max-w-xl">
        <div class="rounded-xl bg-white dark:bg-slate-800 shadow-2xl ring-1 ring-slate-900/10 dark:ring-slate-700">
          <!-- Search input -->
          <div class="flex items-center gap-3 px-4 py-3 border-b border-slate-200 dark:border-slate-700">
            <.icon
              name="hero-magnifying-glass"
              class="size-5 text-slate-400"
            />
            <input
              id="search-input"
              type="text"
              placeholder="Search nodes, maps, personas..."
              class="flex-1 bg-transparent border-none outline-none text-slate-900 dark:text-white placeholder-slate-400 text-sm"
              autocomplete="off"
              oninput="window.handleSearchInput(this.value)"
            />
            <kbd class="hidden sm:inline-flex items-center gap-1 px-2 py-0.5 text-xs text-slate-400 bg-slate-100 dark:bg-slate-700 rounded">
              ESC
            </kbd>
          </div>

          <!-- Results -->
          <div
            id="search-results"
            class="max-h-80 overflow-y-auto p-2"
          >
            <p class="px-3 py-8 text-center text-sm text-slate-500">
              Type to search...
            </p>
          </div>

          <!-- Footer -->
          <div class="flex items-center justify-between px-4 py-2 border-t border-slate-200 dark:border-slate-700 text-xs text-slate-500">
            <span>
              <kbd class="px-1.5 py-0.5 bg-slate-100 dark:bg-slate-700 rounded">↵</kbd>
              to select
            </span>
            <a
              id="search-view-all"
              href="/search"
              class="text-blue-600 dark:text-blue-400 hover:underline hidden"
            >
              View all results →
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center rounded-full border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900">
      <div class="absolute w-1/3 h-full rounded-full border border-slate-200 dark:border-slate-800 bg-slate-100 dark:bg-slate-800 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
