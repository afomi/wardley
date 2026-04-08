defmodule Wardley.Maps do
  @moduledoc """
  Context for Wardley maps, nodes, and edges.
  """
  import Ecto.Query
  alias Wardley.Repo
  alias Wardley.Maps.{Map, Node, Edge, Fragment}

  # Maps
  def get_or_create_default_map() do
    Repo.transaction(fn ->
      case Repo.one(from m in Map, limit: 1) do
        nil ->
          %Map{} |> Map.changeset(%{name: "Default Map"}) |> Repo.insert!()

        map ->
          map
      end
    end)
    |> case do
      {:ok, map} -> map
      {:error, _} -> raise "could not create or fetch default map"
    end
  end

  def get_map!(id), do: Repo.get!(Map, id)

  def list_maps do
    Repo.all(from m in Map, order_by: [desc: m.updated_at])
  end

  def get_map_with_data(id) do
    map = Repo.get!(Map, id)
    nodes = list_nodes(id)
    edges = list_edges(id)
    %{map: map, nodes: nodes, edges: edges}
  end

  # Nodes
  def list_nodes(map_id) do
    Repo.all(from n in Node, where: n.map_id == ^map_id, order_by: n.inserted_at)
  end

  def create_node(attrs) do
    %Node{} |> Node.changeset(attrs) |> Repo.insert()
  end

  def update_node(%Node{} = node, attrs) do
    node |> Node.changeset(attrs) |> Repo.update()
  end

  def get_node!(id), do: Repo.get!(Node, id)

  def delete_node(%Node{} = node), do: Repo.delete(node)

  # Edges
  def list_edges(map_id) do
    Repo.all(from e in Edge, where: e.map_id == ^map_id, order_by: e.inserted_at)
  end

  def create_edge(attrs) do
    %Edge{} |> Edge.changeset(attrs) |> Repo.insert()
  end

  def get_edge!(id), do: Repo.get!(Edge, id)
  def update_edge(%Edge{} = edge, attrs), do: edge |> Edge.changeset(attrs) |> Repo.update()
  def delete_edge(%Edge{} = edge), do: Repo.delete(edge)

  # Fragments

  def list_fragments do
    Repo.all(from f in Fragment, order_by: [desc: f.updated_at])
  end

  def get_fragment!(id), do: Repo.get!(Fragment, id)

  def create_fragment(attrs) do
    %Fragment{} |> Fragment.changeset(attrs) |> Repo.insert()
  end

  def update_fragment(%Fragment{} = fragment, attrs) do
    fragment |> Fragment.changeset(attrs) |> Repo.update()
  end

  def delete_fragment(%Fragment{} = fragment), do: Repo.delete(fragment)

  @doc """
  Create a fragment from selected nodes and their connecting edges on a map.

  Stores node positions as offsets relative to the bounding box origin,
  so the fragment can be placed anywhere when invoked.
  """
  def create_fragment_from_nodes(name, node_ids, map_id, opts \\ []) do
    nodes = Repo.all(from n in Node, where: n.id in ^node_ids and n.map_id == ^map_id)

    if nodes == [] do
      {:error, :no_nodes}
    else
      edges =
        Repo.all(
          from e in Edge,
            where: e.map_id == ^map_id and e.source_id in ^node_ids and e.target_id in ^node_ids
        )

      min_x = nodes |> Enum.map(& &1.x_pct) |> Enum.min()
      min_y = nodes |> Enum.map(& &1.y_pct) |> Enum.min()

      # Use temp IDs so edges can reference nodes within the fragment
      id_map = nodes |> Enum.with_index() |> Enum.into(%{}, fn {n, i} -> {n.id, "t#{i}"} end)

      fragment_nodes =
        Enum.map(nodes, fn n ->
          %{
            "temp_id" => id_map[n.id],
            "text" => n.text,
            "x_pct" => n.x_pct - min_x,
            "y_pct" => n.y_pct - min_y,
            "metadata" => n.metadata || %{}
          }
        end)

      fragment_edges =
        Enum.map(edges, fn e ->
          %{
            "source_temp_id" => id_map[e.source_id],
            "target_temp_id" => id_map[e.target_id],
            "metadata" => e.metadata || %{}
          }
        end)

      create_fragment(%{
        name: name,
        description: opts[:description],
        data: %{"nodes" => fragment_nodes, "edges" => fragment_edges}
      })
    end
  end

  @doc """
  Invoke a fragment onto a map at a given position.

  Creates real nodes and edges. The fragment's relative positions are
  offset by (x_pct, y_pct), clamped to 0-100.
  """
  def invoke_fragment(fragment_id, map_id, x_pct, y_pct) do
    fragment = get_fragment!(fragment_id)
    nodes_data = fragment.data["nodes"] || []
    edges_data = fragment.data["edges"] || []

    Repo.transaction(fn ->
      # Create nodes, building a temp_id → real_id map
      temp_to_real =
        Enum.reduce(nodes_data, %{}, fn node_data, acc ->
          attrs = %{
            "map_id" => map_id,
            "text" => node_data["text"],
            "x_pct" => clamp(node_data["x_pct"] + x_pct, 0.0, 100.0),
            "y_pct" => clamp(node_data["y_pct"] + y_pct, 0.0, 100.0),
            "metadata" => node_data["metadata"] || %{}
          }

          case create_node(attrs) do
            {:ok, node} -> Elixir.Map.put(acc, node_data["temp_id"], node.id)
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)

      # Create edges using the temp_id mapping
      created_edges =
        Enum.map(edges_data, fn edge_data ->
          attrs = %{
            "map_id" => map_id,
            "source_id" => temp_to_real[edge_data["source_temp_id"]],
            "target_id" => temp_to_real[edge_data["target_temp_id"]],
            "metadata" => edge_data["metadata"] || %{}
          }

          case create_edge(attrs) do
            {:ok, edge} -> edge
            {:error, changeset} -> Repo.rollback(changeset)
          end
        end)

      real_node_ids = Elixir.Map.values(temp_to_real)
      created_nodes = Repo.all(from n in Node, where: n.id in ^real_node_ids)

      %{nodes: created_nodes, edges: created_edges}
    end)
  end

  defp clamp(val, min_val, max_val) do
    val |> max(min_val) |> min(max_val)
  end
end
