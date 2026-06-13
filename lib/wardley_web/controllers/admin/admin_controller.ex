defmodule WardleyWeb.Admin.AdminController do
  use WardleyWeb, :controller

  alias Wardley.Accounts
  alias Wardley.Maps

  def index(conn, _params) do
    redirect(conn, to: ~p"/admin/users")
  end

  def users(conn, _params) do
    users = Accounts.list_users()
    render(conn, :users, users: users)
  end

  def show_user(conn, %{"id" => id}) do
    user = Accounts.get_user!(id)
    maps = Maps.list_maps_for_user(user.id)
    render(conn, :show_user, user: user, maps: maps)
  end
end
