defmodule WardleyWeb.ApiTokenControllerTest do
  use WardleyWeb.ConnCase, async: true

  import Wardley.AccountsFixtures

  alias Wardley.Accounts

  describe "POST /api/tokens" do
    test "requires a logged-in user", %{conn: conn} do
      conn = post(conn, ~p"/api/tokens", %{"label" => "codex"})

      assert redirected_to(conn) == ~p"/login"
    end

    test "creates a 30-day bearer token", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/api/tokens", %{"label" => "codex"})

      assert %{
               "token" => token,
               "token_type" => "Bearer",
               "label" => "codex",
               "expires_at" => expires_at
             } = json_response(conn, 200)

      assert Accounts.get_user_by_api_token(token).user.id == user.id
      assert {:ok, expires_at, _offset} = DateTime.from_iso8601(expires_at)
      assert DateTime.diff(expires_at, DateTime.utc_now(:second), :day) in 29..30
    end
  end

  describe "GET /api/me" do
    test "returns the token user when bearer auth is supplied", %{conn: conn} do
      user = user_fixture()
      {:ok, token, _api_token} = Accounts.create_api_token(user, "codex")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/me")

      assert %{
               "user" => %{"id" => user_id, "email" => email},
               "token" => %{"label" => "codex"}
             } = json_response(conn, 200)

      assert user_id == user.id
      assert email == user.email
    end

    test "rejects missing bearer auth", %{conn: conn} do
      conn = get(conn, ~p"/api/me")

      assert json_response(conn, 401) == %{"error" => "invalid_or_missing_token"}
    end
  end
end
