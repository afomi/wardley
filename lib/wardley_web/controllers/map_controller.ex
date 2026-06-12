defmodule WardleyWeb.MapController do
  use WardleyWeb, :controller
  alias Wardley.Maps
  alias Wardley.Accounts

  def index(conn, _params) do
    user = conn.assigns.current_scope.user
    maps = Maps.list_maps_for_user(user.id)

    conn
    |> assign(:page_title, "Maps")
    |> assign(:page_description, "Browse and manage your Wardley Maps.")
    |> render(:index, maps: maps)
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_scope.user

    if Maps.can_view_map?(id, user.id) do
      map = Maps.get_map!(id)
      memberships = Maps.list_memberships(map.id)
      is_owner = map.user_id == user.id
      # Viewing a public map does not grant edit rights — those stay owner/member-only.
      can_edit = Maps.can_access_map?(id, user.id)

      conn
      |> assign(:page_title, map.name)
      |> assign(:page_description, "Wardley Map: #{map.name}")
      |> assign(:og_type, "article")
      |> render(:map,
        map: map,
        memberships: memberships,
        is_owner: is_owner,
        can_edit: can_edit
      )
    else
      conn
      |> put_status(:not_found)
      |> put_view(WardleyWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
    end
  end

  def add_member(conn, %{"id" => map_id, "email" => email}) do
    user = conn.assigns.current_scope.user

    if Maps.owns_map?(map_id, user.id) do
      case Accounts.get_user_by_email(email) do
        nil ->
          conn
          |> put_flash(:error, "No user found with that email.")
          |> redirect(to: ~p"/maps/#{map_id}")

        invitee ->
          case Maps.add_member(map_id, invitee.id) do
            {:ok, _membership} ->
              conn
              |> put_flash(:info, "#{email} added as editor.")
              |> redirect(to: ~p"/maps/#{map_id}")

            {:error, _changeset} ->
              conn
              |> put_flash(:error, "Could not add member. They may already have access.")
              |> redirect(to: ~p"/maps/#{map_id}")
          end
      end
    else
      conn
      |> put_status(:not_found)
      |> put_view(WardleyWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
    end
  end

  def remove_member(conn, %{"id" => map_id, "user_id" => member_user_id}) do
    user = conn.assigns.current_scope.user

    if Maps.owns_map?(map_id, user.id) do
      case Maps.remove_member(map_id, member_user_id) do
        {:ok, _} ->
          conn
          |> put_flash(:info, "Member removed.")
          |> redirect(to: ~p"/maps/#{map_id}")

        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Member not found.")
          |> redirect(to: ~p"/maps/#{map_id}")
      end
    else
      conn
      |> put_status(:not_found)
      |> put_view(WardleyWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
    end
  end

  def new(conn, _params) do
    conn
    |> assign(:page_title, "New Map")
    |> render(:new)
  end

  def create(conn, %{"map" => map_params}) do
    user = conn.assigns.current_scope.user
    attrs = Map.merge(map_params, %{"user_id" => user.id})

    case Maps.create_map(attrs) do
      {:ok, map} ->
        conn
        |> put_flash(:info, "Map created.")
        |> redirect(to: ~p"/maps/#{map.id}")

      {:error, changeset} ->
        conn
        |> assign(:page_title, "New Map")
        |> assign(:changeset, changeset)
        |> render(:new)
    end
  end

  def example(conn, _params) do
    map = Maps.get_or_create_default_map()
    user_id = conn.assigns[:current_scope] && conn.assigns.current_scope.user.id
    can_edit = Maps.can_write_map?(map.id, user_id)

    conn
    |> assign(:page_title, "Example Map")
    |> assign(
      :page_description,
      "Interactive Wardley Map editor. Add components, define dependencies, and visualize your value chain evolution from genesis to commodity."
    )
    |> assign(:og_type, "article")
    |> render(:map, map: map, can_edit: can_edit)
  end
end
