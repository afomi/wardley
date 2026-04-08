defmodule WardleyWeb.MapChannel do
  use Phoenix.Channel

  alias Wardley.Maps

  @impl true
  def join("map:" <> map_id, _params, socket) do
    map_id = String.to_integer(map_id)
    Maps.subscribe(map_id)
    {:ok, assign(socket, :map_id, map_id)}
  end

  @impl true
  def handle_info({:map_updated, map_id}, socket) do
    nodes = Maps.list_nodes(map_id)
    edges = Maps.list_edges(map_id)

    push(socket, "map_updated", %{
      nodes: Enum.map(nodes, &node_json/1),
      edges: Enum.map(edges, &edge_json/1)
    })

    {:noreply, socket}
  end

  defp node_json(n) do
    %{
      id: n.id,
      map_id: n.map_id,
      x_pct: n.x_pct,
      y_pct: n.y_pct,
      text: n.text,
      metadata: n.metadata || %{}
    }
  end

  defp edge_json(e) do
    %{
      id: e.id,
      map_id: e.map_id,
      source_id: e.source_id,
      target_id: e.target_id,
      metadata: e.metadata || %{}
    }
  end
end
