defmodule WardleyWeb.MapController do
  use WardleyWeb, :controller
  alias Wardley.Maps

  def show(conn, _params) do
    map = Maps.get_or_create_default_map()
    render(conn, :map, map: map)
  end
end

