defmodule Wardley.Maps do
  @moduledoc """
  Context for Wardley maps, nodes, and edges.
  """
  import Ecto.Query
  alias Wardley.Repo
  alias Wardley.Maps.{Map, Node, Edge}

  # Maps
  def get_or_create_default_map() do
    Repo.transaction(fn ->
      case Repo.one(from m in Map, limit: 1) do
        nil ->
          %Map{} |> Map.changeset(%{name: "Default Map"}) |> Repo.insert!()
        map -> map
      end
    end)
    |> case do
      {:ok, map} -> map
      {:error, _} -> raise "could not create or fetch default map"
    end
  end

  def get_map!(id), do: Repo.get!(Map, id)

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
end
