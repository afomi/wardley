defmodule WardleyWeb.MapController do
  use WardleyWeb, :controller
  alias Wardley.Maps

  def show(conn, _params) do
    map = Maps.get_or_create_default_map()

    conn
    |> assign(:page_title, "Map Editor")
    |> assign(:page_description, "Interactive Wardley Map editor. Add components, define dependencies, and visualize your value chain evolution from genesis to commodity.")
    |> assign(:og_type, "article")
    |> render(:map, map: map)
  end
end

