defmodule WardleyWeb.UserLive.Settings do
  use WardleyWeb, :live_view

  on_mount {WardleyWeb.UserAuth, :require_sudo_mode}

  alias Wardley.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl space-y-8">
        <header class="space-y-2">
          <p class="text-sm font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400">
            Account
          </p>
          <h1 class="text-3xl font-bold text-slate-950 dark:text-slate-100">
            Settings
          </h1>
          <p class="leading-7 text-slate-600 dark:text-slate-300">
            Manage your sign-in details and generate API tokens for LLM or automation workflows.
          </p>
        </header>

        <section
          id="api-token-panel"
          class="rounded-lg border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900"
        >
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <h2 class="text-xl font-semibold text-slate-950 dark:text-slate-100">
                API token
              </h2>
              <p class="mt-2 leading-7 text-slate-600 dark:text-slate-300">
                Generate a 30-day bearer token for the Wardley API.
              </p>
            </div>
          </div>

          <.form
            for={@api_token_form}
            id="api-token-form"
            phx-submit="create_api_token"
            class="mt-6 grid gap-4 sm:grid-cols-[1fr_auto] sm:items-end"
          >
            <.input
              field={@api_token_form[:label]}
              type="text"
              label="Token label"
              maxlength="120"
              class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition placeholder:text-slate-400 focus:border-slate-500 focus:ring-2 focus:ring-slate-200 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:focus:border-slate-500 dark:focus:ring-slate-800"
            />
            <button
              type="submit"
              id="generate-api-token"
              phx-disable-with="Generating..."
              class="inline-flex h-10 items-center justify-center rounded-md bg-slate-950 px-4 text-sm font-semibold text-white transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 dark:bg-slate-100 dark:text-slate-950 dark:hover:bg-white"
            >
              Generate token
            </button>
          </.form>

          <div
            :if={@api_token_result}
            id="api-token-result"
            class="mt-6 rounded-md border border-emerald-200 bg-emerald-50 p-4 dark:border-emerald-900/70 dark:bg-emerald-950/30"
          >
            <div class="flex items-start gap-3">
              <.icon
                name="hero-check-circle"
                class="mt-0.5 size-5 shrink-0 text-emerald-700 dark:text-emerald-300"
              />
              <div class="min-w-0 flex-1">
                <p class="text-sm font-semibold text-emerald-950 dark:text-emerald-100">
                  Token generated. Copy it now; it will not be shown again.
                </p>
                <div class="mt-3 flex flex-col gap-2 sm:flex-row">
                  <input
                    id="api-token-value"
                    type="text"
                    readonly
                    value={@api_token_result.token}
                    class="min-w-0 flex-1 rounded-md border border-emerald-300 bg-white px-3 py-2 font-mono text-xs text-slate-950 shadow-sm dark:border-emerald-800 dark:bg-slate-950 dark:text-slate-100"
                  />
                  <button
                    type="button"
                    id="copy-api-token"
                    phx-click={JS.dispatch("wardley:copy-token", to: "#api-token-value")}
                    class="inline-flex h-9 items-center justify-center rounded-md border border-emerald-300 px-3 text-sm font-semibold text-emerald-950 transition hover:bg-emerald-100 dark:border-emerald-800 dark:text-emerald-100 dark:hover:bg-emerald-950"
                  >
                    Copy
                  </button>
                </div>
                <p class="mt-2 text-sm text-emerald-900 dark:text-emerald-200">
                  Expires {@api_token_result.expires_at}.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section class="rounded-lg border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900">
          <h2 class="text-xl font-semibold text-slate-950 dark:text-slate-100">
            Email
          </h2>
          <p class="mt-2 leading-7 text-slate-600 dark:text-slate-300">
            Current email:
            <span class="font-medium text-slate-900 dark:text-slate-100">{@current_email}</span>
          </p>

          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
            class="mt-6 space-y-4"
          >
            <.input
              field={@email_form[:email]}
              type="email"
              label="New email"
              autocomplete="username"
              spellcheck="false"
              required
              class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition placeholder:text-slate-400 focus:border-slate-500 focus:ring-2 focus:ring-slate-200 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:focus:border-slate-500 dark:focus:ring-slate-800"
            />
            <button
              type="submit"
              id="change-email"
              phx-disable-with="Changing..."
              class="inline-flex h-10 items-center justify-center rounded-md bg-slate-950 px-4 text-sm font-semibold text-white transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 dark:bg-slate-100 dark:text-slate-950 dark:hover:bg-white"
            >
              Change Email
            </button>
          </.form>
        </section>

        <section class="rounded-lg border border-slate-200 bg-white p-6 shadow-sm dark:border-slate-800 dark:bg-slate-900">
          <h2 class="text-xl font-semibold text-slate-950 dark:text-slate-100">
            Password
          </h2>
          <p class="mt-2 leading-7 text-slate-600 dark:text-slate-300">
            Set or update a password for this account.
          </p>

          <.form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
            class="mt-6 space-y-4"
          >
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              spellcheck="false"
              value={@current_email}
            />
            <.input
              field={@password_form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              spellcheck="false"
              required
              class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition placeholder:text-slate-400 focus:border-slate-500 focus:ring-2 focus:ring-slate-200 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:focus:border-slate-500 dark:focus:ring-slate-800"
            />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              spellcheck="false"
              class="w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-none transition placeholder:text-slate-400 focus:border-slate-500 focus:ring-2 focus:ring-slate-200 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 dark:focus:border-slate-500 dark:focus:ring-slate-800"
            />
            <button
              type="submit"
              id="save-password"
              phx-disable-with="Saving..."
              class="inline-flex h-10 items-center justify-center rounded-md bg-slate-950 px-4 text-sm font-semibold text-white transition hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 dark:bg-slate-100 dark:text-slate-950 dark:hover:bg-white"
            >
              Save Password
            </button>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:api_token_form, api_token_form())
      |> assign(:api_token_result, nil)
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("create_api_token", %{"api_token" => api_token_params}, socket) do
    user = socket.assigns.current_scope.user
    label = api_token_params |> Map.get("label", "llm-session") |> clean_token_label()

    case Accounts.create_api_token(user, label) do
      {:ok, encoded_token, api_token} ->
        result = %{
          token: encoded_token,
          label: api_token.label,
          expires_at: DateTime.to_iso8601(api_token.expires_at)
        }

        {:noreply,
         socket
         |> assign(:api_token_form, api_token_form(api_token.label))
         |> assign(:api_token_result, result)
         |> put_flash(:info, "API token generated. Copy it now.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "API token could not be generated.")}
    end
  end

  def handle_event("create_api_token", _params, socket) do
    handle_event("create_api_token", %{"api_token" => %{}}, socket)
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  defp api_token_form(label \\ "llm-session") do
    to_form(%{"label" => label}, as: :api_token)
  end

  defp clean_token_label(label) when is_binary(label) do
    case String.trim(label) do
      "" -> "llm-session"
      value -> value
    end
  end

  defp clean_token_label(_label), do: "llm-session"
end
