defmodule WardleyWeb.MapController do
  use WardleyWeb, :controller
  alias Wardley.Maps

  def index(conn, _params) do
    maps = Maps.list_maps()

    conn
    |> assign(:page_title, "Maps")
    |> assign(:page_description, "Browse and manage your Wardley Maps.")
    |> render(:index, maps: maps)
  end

  def show(conn, %{"id" => id}) do
    map = Maps.get_map!(id)

    conn
    |> assign(:page_title, map.name)
    |> assign(:page_description, "Wardley Map: #{map.name}")
    |> assign(:og_type, "article")
    |> render(:map, map: map)
  end

  def example(conn, _params) do
    map = Maps.get_or_create_default_map()

    conn
    |> assign(:page_title, "Example Map")
    |> assign(
      :page_description,
      "Interactive Wardley Map editor. Add components, define dependencies, and visualize your value chain evolution from genesis to commodity."
    )
    |> assign(:og_type, "article")
    |> render(:map, map: map)
  end
end
