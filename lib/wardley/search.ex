defmodule Wardley.Search do
  @moduledoc """
  Unified search across nodes, maps, and personas.

  Provides a single entry point for searching all entity types,
  returning results grouped by type with relevance indicators.
  """
  import Ecto.Query
  alias Wardley.Repo
  alias Wardley.Maps.Map, as: WardleyMap
  alias Wardley.Maps.Node
  alias Wardley.Personas.Persona

  @doc """
  Search across all entity types.

  Returns a map with keys :nodes, :maps, :personas, each containing
  a list of matching results.

  ## Options
    * `:limit` - Maximum results per type (default: 10)
    * `:types` - List of types to search (default: [:nodes, :maps, :personas])

  ## Examples

      iex> Search.search("cloud")
      %{
        nodes: [%{id: 1, text: "Cloud Platform", ...}],
        maps: [],
        personas: []
      }
  """
  def search(query, opts \\ []) when is_binary(query) do
    limit = Keyword.get(opts, :limit, 10)
    types = Keyword.get(opts, :types, [:nodes, :maps, :personas])

    results = %{nodes: [], maps: [], personas: []}

    results =
      if :nodes in types do
        Map.put(results, :nodes, search_nodes(query, limit))
      else
        results
      end

    results =
      if :maps in types do
        Map.put(results, :maps, search_maps(query, limit))
      else
        results
      end

    results =
      if :personas in types do
        Map.put(results, :personas, search_personas(query, limit))
      else
        results
      end

    results
  end

  @doc """
  Search nodes by text, category, tags, or description in metadata.
  """
  def search_nodes(query, limit \\ 10) when is_binary(query) do
    search_term = "%#{query}%"

    Repo.all(
      from n in Node,
        join: m in WardleyMap,
        on: n.map_id == m.id,
        where:
          ilike(n.text, ^search_term) or
            fragment(
              "?->>'category' ILIKE ? OR ?->>'description' ILIKE ? OR ?::text ILIKE ?",
              n.metadata,
              ^search_term,
              n.metadata,
              ^search_term,
              n.metadata,
              ^search_term
            ),
        select: %{
          id: n.id,
          text: n.text,
          x_pct: n.x_pct,
          y_pct: n.y_pct,
          metadata: n.metadata,
          map_id: n.map_id,
          map_name: m.name
        },
        order_by: [asc: n.text],
        limit: ^limit
    )
  end

  @doc """
  Search maps by name.
  """
  def search_maps(query, limit \\ 10) when is_binary(query) do
    search_term = "%#{query}%"

    Repo.all(
      from m in WardleyMap,
        where: ilike(m.name, ^search_term),
        select: %{
          id: m.id,
          name: m.name,
          node_count:
            fragment(
              "(SELECT COUNT(*) FROM nodes WHERE map_id = ?)",
              m.id
            )
        },
        order_by: [asc: m.name],
        limit: ^limit
    )
  end

  @doc """
  Search personas by name or description.
  """
  def search_personas(query, limit \\ 10) when is_binary(query) do
    search_term = "%#{query}%"

    Repo.all(
      from p in Persona,
        where: ilike(p.name, ^search_term) or ilike(p.description, ^search_term),
        select: %{
          id: p.id,
          name: p.name,
          description: p.description,
          is_default: p.is_default,
          metadata: p.metadata
        },
        order_by: [desc: p.is_default, asc: p.name],
        limit: ^limit
    )
  end

  @doc """
  Get all unique categories from node metadata across all maps.
  Useful for building category filters.
  """
  def list_categories do
    Repo.all(
      from n in Node,
        where: not is_nil(fragment("?->>'category'", n.metadata)),
        select: fragment("DISTINCT ?->>'category'", n.metadata),
        order_by: [asc: fragment("?->>'category'", n.metadata)]
    )
  end

  @doc """
  Get all unique tags from node metadata across all maps.
  Tags are stored as arrays in metadata.tags.
  """
  def list_tags do
    # Get all nodes with tags, extract and flatten
    nodes_with_tags =
      Repo.all(
        from n in Node,
          where: not is_nil(fragment("?->'tags'", n.metadata)),
          select: n.metadata
      )

    nodes_with_tags
    |> Enum.flat_map(fn metadata ->
      case metadata["tags"] do
        tags when is_list(tags) -> tags
        _ -> []
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Search nodes by category (exact match on metadata.category).
  """
  def search_by_category(category, limit \\ 50) when is_binary(category) do
    Repo.all(
      from n in Node,
        join: m in WardleyMap,
        on: n.map_id == m.id,
        where: fragment("?->>'category' = ?", n.metadata, ^category),
        select: %{
          id: n.id,
          text: n.text,
          x_pct: n.x_pct,
          y_pct: n.y_pct,
          metadata: n.metadata,
          map_id: n.map_id,
          map_name: m.name
        },
        order_by: [asc: m.name, asc: n.text],
        limit: ^limit
    )
  end

  @doc """
  Search nodes by tag (checks if tag is in metadata.tags array).
  """
  def search_by_tag(tag, limit \\ 50) when is_binary(tag) do
    tag_json = Jason.encode!([tag])

    Repo.all(
      from n in Node,
        join: m in WardleyMap,
        on: n.map_id == m.id,
        where: fragment("(?->'tags')::jsonb @> ?::jsonb", n.metadata, ^tag_json),
        select: %{
          id: n.id,
          text: n.text,
          x_pct: n.x_pct,
          y_pct: n.y_pct,
          metadata: n.metadata,
          map_id: n.map_id,
          map_name: m.name
        },
        order_by: [asc: m.name, asc: n.text],
        limit: ^limit
    )
  end

  @doc """
  Get aggregated view of a component type across all maps.
  Returns positions from each map for comparison.

  This is the data structure needed for the aggregate comparison view.
  """
  def aggregate_by_category(category) when is_binary(category) do
    nodes = search_by_category(category, 100)

    %{
      category: category,
      count: length(nodes),
      nodes: nodes,
      positions:
        Enum.map(nodes, fn n ->
          %{
            x_pct: n.x_pct,
            y_pct: n.y_pct,
            map_id: n.map_id,
            map_name: n.map_name,
            text: n.text
          }
        end),
      evolution_stats: calculate_evolution_stats(nodes)
    }
  end

  defp calculate_evolution_stats(nodes) when nodes == [], do: nil

  defp calculate_evolution_stats(nodes) do
    x_values = Enum.map(nodes, & &1.x_pct)
    count = length(x_values)

    %{
      min: Enum.min(x_values),
      max: Enum.max(x_values),
      mean: Enum.sum(x_values) / count,
      spread: Enum.max(x_values) - Enum.min(x_values)
    }
  end
end
