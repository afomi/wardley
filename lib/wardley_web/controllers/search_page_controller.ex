defmodule WardleyWeb.SearchPageController do
  use WardleyWeb, :controller

  alias Wardley.Search

  def index(conn, params) do
    query = params["q"] || ""

    results =
      if String.length(query) >= 1 do
        Search.search(query, limit: 50)
      else
        %{nodes: [], maps: [], personas: []}
      end

    categories = Search.list_categories()

    page_title = if(query != "", do: "Search: #{query}", else: "Search")

    conn
    |> assign(:page_title, page_title)
    |> assign(:page_description, "Search across all Wardley Map components, maps, and personas. Find nodes by category, tags, or text.")
    |> render(:index,
      query: query,
      results: results,
      categories: categories
    )
  end
end
