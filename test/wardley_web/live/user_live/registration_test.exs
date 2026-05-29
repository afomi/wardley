defmodule WardleyWeb.UserLive.RegistrationTest do
  use WardleyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wardley.AccountsFixtures

  describe "registration page" do
    test "redirects anonymous users to /login", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/users/register")
      assert path == ~p"/login"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/users/settings")

      assert {:ok, _conn} = result
    end
  end
end
