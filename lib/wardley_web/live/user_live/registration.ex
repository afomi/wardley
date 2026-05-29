defmodule WardleyWeb.UserLive.Registration do
  use WardleyWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="registration-redirect" class="mx-auto max-w-sm px-6 py-12">
        <.header>
          GitHub sign-in only
          <:subtitle>
            Email registration is currently disabled.
          </:subtitle>
        </.header>

        <.link
          id="registration-login-link"
          navigate={~p"/login"}
          class="mt-6 inline-flex w-full items-center justify-center rounded-md bg-slate-950 px-4 py-3 text-sm font-semibold text-white transition hover:bg-slate-800"
        >
          Continue with GitHub
        </.link>
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
    {:ok, redirect(socket, to: ~p"/login")}
  end
end
