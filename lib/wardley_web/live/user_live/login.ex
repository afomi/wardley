defmodule WardleyWeb.UserLive.Login do
  use WardleyWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto flex min-h-[70vh] max-w-md items-center px-6">
        <section class="w-full space-y-8 rounded-lg border border-slate-200 bg-white p-8 shadow-sm">
          <div class="space-y-3">
            <.header>Log in</.header>
          </div>

          <.link
            id="github-login-link"
            href={~p"/auth/github"}
            class="inline-flex w-full items-center justify-center gap-3 rounded-md bg-slate-950 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2"
          >
            <.icon name="hero-code-bracket-square" class="size-5" /> Continue with GitHub
          </.link>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
