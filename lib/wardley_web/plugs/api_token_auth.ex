defmodule WardleyWeb.Plugs.ApiTokenAuth do
  @moduledoc """
  Authenticates API requests with a Wardley bearer token when one is supplied.
  """

  import Plug.Conn

  alias Wardley.Accounts
  alias Wardley.Accounts.Scope

  def init(opts), do: opts

  def call(conn, opts) do
    optional? = Keyword.get(opts, :optional, false)

    case bearer_token(conn) do
      {:ok, token} ->
        authenticate(conn, token)

      :missing when optional? ->
        conn

      :missing ->
        unauthorized(conn)
    end
  end

  defp authenticate(conn, encoded_token) do
    case Accounts.get_user_by_api_token(encoded_token) do
      %{user: user} = api_token when not is_nil(user) ->
        Accounts.touch_api_token(api_token)

        conn
        |> assign(:api_token, api_token)
        |> assign(:current_scope, Scope.for_user(user))

      _ ->
        unauthorized(conn)
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, String.trim(token)}
      ["bearer " <> token] -> {:ok, String.trim(token)}
      _ -> :missing
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:unauthorized, Jason.encode!(%{error: "invalid_or_missing_token"}))
    |> halt()
  end
end
