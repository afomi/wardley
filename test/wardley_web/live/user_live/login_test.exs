defmodule WardleyWeb.UserLive.LoginTest do
  use WardleyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Wardley.AccountsFixtures

  describe "login page" do
    test "renders GitHub-only login page at /login", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Log in"
      assert html =~ "Continue with GitHub"
      assert html =~ ~p"/auth/github"
      refute html =~ "Use GitHub to access your Wardley maps"
      refute html =~ "Email sign-in is currently disabled."
      refute html =~ "uppercase tracking-wide text-slate-500"
      refute html =~ "Register"
      refute html =~ "Log in with email"
      refute html =~ "Password"
    end

    test "redirects legacy login path to /login", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")

      assert redirected_to(conn) == ~p"/login"
    end
  end

  describe "re-authentication" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "renders the GitHub login page for an already logged-in user", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Log in"
      assert html =~ "Continue with GitHub"
      assert html =~ ~p"/auth/github"
    end
  end
end
