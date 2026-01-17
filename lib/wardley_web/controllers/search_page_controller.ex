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

    render(conn, :index,
      query: query,
      results: results,
      categories: categories,
      page_title: if(query != "", do: "Search: #{query}", else: "Search")
    )
  end
end
