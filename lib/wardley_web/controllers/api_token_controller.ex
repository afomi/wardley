defmodule WardleyWeb.ApiTokenController do
  use WardleyWeb, :controller

  alias Wardley.Accounts

  def create(conn, params) do
    user = conn.assigns.current_scope.user
    label = token_label(params)

    case Accounts.create_api_token(user, label) do
      {:ok, encoded_token, api_token} ->
        json(conn, %{
          token: encoded_token,
          token_type: "Bearer",
          label: api_token.label,
          expires_at: DateTime.to_iso8601(api_token.expires_at)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  def show(%{assigns: %{api_token: api_token, current_scope: %{user: user}}} = conn, _params) do
    json(conn, %{
      user: %{id: user.id, email: user.email},
      token: %{
        id: api_token.id,
        label: api_token.label,
        expires_at: DateTime.to_iso8601(api_token.expires_at)
      }
    })
  end

  def show(conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "invalid_or_missing_token"})
  end

  defp token_label(%{"api_token" => %{"label" => label}}), do: clean_label(label)
  defp token_label(%{"label" => label}), do: clean_label(label)
  defp token_label(_params), do: "llm-session"

  defp clean_label(label) when is_binary(label) do
    case String.trim(label) do
      "" -> "llm-session"
      value -> value
    end
  end

  defp clean_label(_label), do: "llm-session"

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
