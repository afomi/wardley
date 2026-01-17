defmodule WardleyWeb.SearchController do
  use WardleyWeb, :controller
  alias Wardley.Search

  @doc """
  Unified search endpoint.
  GET /api/search?q=query&limit=10&types=nodes,maps,personas
  """
  def search(conn, params) do
    query = params["q"] || ""
    limit = parse_int(params["limit"], 10)

    types =
      case params["types"] do
        nil -> [:nodes, :maps, :personas]
        types_str -> parse_types(types_str)
      end

    if String.length(query) < 1 do
      json(conn, %{nodes: [], maps: [], personas: [], error: "Query too short"})
    else
      results = Search.search(query, limit: limit, types: types)
      json(conn, results)
    end
  end

  @doc """
  List all categories.
  GET /api/categories
  """
  def categories(conn, _params) do
    categories = Search.list_categories()
    json(conn, %{categories: categories})
  end

  @doc """
  List all tags.
  GET /api/tags
  """
  def tags(conn, _params) do
    tags = Search.list_tags()
    json(conn, %{tags: tags})
  end

  @doc """
  Search by category with aggregation data.
  GET /api/categories/:category
  """
  def by_category(conn, %{"category" => category}) do
    result = Search.aggregate_by_category(category)
    json(conn, result)
  end

  @doc """
  Search by tag.
  GET /api/tags/:tag
  """
  def by_tag(conn, %{"tag" => tag}) do
    nodes = Search.search_by_tag(tag)
    json(conn, %{tag: tag, count: length(nodes), nodes: nodes})
  end

  defp parse_int(nil, default), do: default
  defp parse_int(str, default) do
    case Integer.parse(str) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_types(types_str) when is_binary(types_str) do
    types_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.filter(&(&1 in [:nodes, :maps, :personas]))
  rescue
    ArgumentError -> [:nodes, :maps, :personas]
  end
end
