defmodule WardleyWeb.OAuthControllerTest do
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Accounts
  alias Wardley.Accounts.UserIdentity
  alias WardleyWeb.OAuthController

  describe "callback/2" do
    test "logs a GitHub user in", %{conn: conn} do
      conn =
        conn
        |> oauth_conn()
        |> fetch_flash()
        |> assign(:ueberauth_auth, github_auth())
        |> OAuthController.callback(%{})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Signed in with GitHub."
      assert user = Accounts.get_user_by_email("octo@example.com")

      identity = Wardley.Repo.get_by!(UserIdentity, user_id: user.id)
      assert identity.raw_info["user"]["login"] == "octo"
      refute Map.has_key?(identity.raw_info, "token")
    end

    test "redirects when GitHub does not return an email", %{conn: conn} do
      conn =
        conn
        |> oauth_conn()
        |> fetch_flash()
        |> assign(:ueberauth_auth, github_auth(email: nil, emails: []))
        |> OAuthController.callback(%{})

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "did not return a verified email"
    end

    test "uses a verified email from the GitHub raw user payload", %{conn: conn} do
      emails = [%{"email" => "primary@example.com", "primary" => true, "verified" => true}]

      conn =
        conn
        |> oauth_conn()
        |> fetch_flash()
        |> assign(:ueberauth_auth, github_auth(email: nil, emails: emails))
        |> OAuthController.callback(%{})

      assert get_session(conn, :user_token)
      assert Accounts.get_user_by_email("primary@example.com")
    end

    test "redirects failures to /login", %{conn: conn} do
      conn =
        conn
        |> oauth_conn()
        |> fetch_flash()
        |> assign(:ueberauth_failure, :cancelled)
        |> OAuthController.callback(%{})

      assert redirected_to(conn) == ~p"/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "cancelled or failed"
    end
  end

  defp oauth_conn(conn) do
    conn
    |> Map.put(:secret_key_base, WardleyWeb.Endpoint.config(:secret_key_base))
    |> init_test_session(%{})
  end

  defp github_auth(attrs \\ []) do
    attrs = Enum.into(attrs, %{email: "octo@example.com", emails: []})

    raw_info = %{
      token: %OAuth2.AccessToken{access_token: "raw-token"},
      emails: attrs.emails,
      user: %{"login" => "octo", "emails" => attrs.emails}
    }

    %Ueberauth.Auth{
      provider: :github,
      uid: "12345",
      info: %Ueberauth.Auth.Info{email: attrs.email},
      credentials: %Ueberauth.Auth.Credentials{token: "github-token"},
      extra: %Ueberauth.Auth.Extra{raw_info: raw_info}
    }
  end
end
