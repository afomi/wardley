defmodule WardleyWeb.OAuthController do
  use WardleyWeb, :controller

  plug Ueberauth

  alias Wardley.Accounts
  alias WardleyWeb.UserAuth

  def request(conn, _params) do
    redirect(conn, to: ~p"/login")
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "GitHub sign-in was cancelled or failed.")
    |> redirect(to: ~p"/login")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    provider = auth.provider |> to_string()

    case Accounts.find_or_create_from_oauth(provider, oauth_info(auth)) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Signed in with GitHub.")
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      {:error, :email_required} ->
        conn
        |> put_flash(:error, "GitHub did not return a verified email address.")
        |> redirect(to: ~p"/login")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "GitHub sign-in could not be completed.")
        |> redirect(to: ~p"/login")
    end
  end

  def callback(conn, _params) do
    conn
    |> put_flash(:error, "GitHub sign-in could not be completed.")
    |> redirect(to: ~p"/login")
  end

  defp oauth_info(auth) do
    credentials = field(auth, :credentials) || %{}
    raw_info = field(field(auth, :extra), :raw_info) || %{}

    %{
      uid: field(auth, :uid),
      email: email_from_auth(auth, raw_info),
      access_token: field(credentials, :token),
      refresh_token: field(credentials, :refresh_token),
      token_expires_at: token_expires_at(credentials),
      raw_info: raw_info_for_storage(raw_info)
    }
  end

  defp email_from_auth(auth, raw_info) do
    info_email =
      auth
      |> field(:info)
      |> field(:email)

    info_email || verified_github_email(raw_info)
  end

  defp verified_github_email(raw_info) do
    user = field(raw_info, :user)
    emails = field(raw_info, :emails) || field(user, :emails) || []
    primary_verified = Enum.find(emails, &primary_verified_email?/1)
    verified = primary_verified || Enum.find(emails, &truthy?(field(&1, :verified)))

    field(verified, :email)
  end

  defp primary_verified_email?(email) do
    truthy?(field(email, :primary)) && truthy?(field(email, :verified))
  end

  defp token_expires_at(%{expires: true, expires_at: expires_at}) when is_integer(expires_at) do
    DateTime.from_unix!(expires_at)
  end

  defp token_expires_at(_credentials), do: nil

  defp raw_info_for_storage(raw_info) do
    %{
      "user" => field(raw_info, :user) || %{}
    }
  end

  defp field(nil, _key), do: nil
  defp field(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))

  defp truthy?(value), do: value in [true, "true", 1, "1"]
end
