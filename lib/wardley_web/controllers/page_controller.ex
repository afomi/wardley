defmodule WardleyWeb.PageController do
  use WardleyWeb, :controller

  def home(conn, _params) do
    conn
    |> assign(:page_description, "Wardley Mapping is a strategy tool for visualizing value chains and understanding how components evolve over time. Create maps, explore strategy, and make better decisions.")
    |> render(:home)
  end
end
