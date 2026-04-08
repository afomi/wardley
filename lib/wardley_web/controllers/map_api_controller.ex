defmodule WardleyWeb.MapAPIController do
  use WardleyWeb, :controller
  alias Wardley.Maps
  alias Wardley.Maps.{Node, Edge}

  def map(conn, _params) do
    map = Maps.get_or_create_default_map()
    nodes = Maps.list_nodes(map.id)
    edges = Maps.list_edges(map.id)

    json(conn, %{
      map: %{id: map.id, name: map.name},
      nodes: Enum.map(nodes, &node_json/1),
      edges: Enum.map(edges, &edge_json/1)
    })
  end

  @doc """
  List all maps for layer selection.
  """
  def list_maps(conn, _params) do
    maps = Maps.list_maps()

    json(conn, %{
      maps:
        Enum.map(maps, fn m ->
          %{id: m.id, name: m.name, updated_at: m.updated_at}
        end)
    })
  end

  @doc """
  Get a specific map with all its data (for loading as a layer).
  """
  def show_map(conn, %{"id" => id}) do
    %{map: map, nodes: nodes, edges: edges} = Maps.get_map_with_data(id)

    json(conn, %{
      map: %{id: map.id, name: map.name},
      nodes: Enum.map(nodes, &node_json/1),
      edges: Enum.map(edges, &edge_json/1)
    })
  end

  def map_svg(conn, %{"id" => id}) do
    %{map: map, nodes: nodes, edges: edges} = Maps.get_map_with_data(id)
    svg = Wardley.Maps.Svg.render(map, nodes, edges)

    conn
    |> put_resp_content_type("image/svg+xml")
    |> send_resp(200, svg)
  end

  def create_node(conn, params) do
    map = Maps.get_or_create_default_map()

    attrs = %{
      "map_id" => map.id,
      "x_pct" => params["x_pct"],
      "y_pct" => params["y_pct"],
      "text" => params["text"] || "Node",
      "metadata" => params["metadata"] || %{}
    }

    case Maps.create_node(attrs) do
      {:ok, node} ->
        json(conn, node_json(node))

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
    end
  end

  def update_node(conn, %{"id" => id} = params) do
    node = Maps.get_node!(id)
    attrs = Map.take(params, ["x_pct", "y_pct", "text", "metadata"])

    case Maps.update_node(node, attrs) do
      {:ok, node} ->
        json(conn, node_json(node))

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
    end
  end

  def delete_node(conn, %{"id" => id}) do
    node = Maps.get_node!(id)
    {:ok, _} = Maps.delete_node(node)
    send_resp(conn, :no_content, "")
  end

  def create_edge(conn, params) do
    map = Maps.get_or_create_default_map()

    attrs = %{
      "map_id" => map.id,
      "source_id" => params["source_id"],
      "target_id" => params["target_id"],
      "metadata" => params["metadata"] || %{}
    }

    case Maps.create_edge(attrs) do
      {:ok, edge} ->
        json(conn, edge_json(edge))

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
    end
  end

  def delete_edge(conn, %{"id" => id}) do
    edge = Maps.get_edge!(id)
    {:ok, _} = Maps.delete_edge(edge)
    send_resp(conn, :no_content, "")
  end

  def update_edge(conn, %{"id" => id} = params) do
    edge = Maps.get_edge!(id)
    attrs = Map.take(params, ["metadata"]) |> Enum.into(%{})

    case Maps.update_edge(edge, attrs) do
      {:ok, edge} ->
        json(conn, edge_json(edge))

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
    end
  end

  # Fragments

  def list_fragments(conn, _params) do
    fragments = Maps.list_fragments()

    json(conn, %{
      fragments:
        Enum.map(fragments, fn f ->
          fragment_json(f)
        end)
    })
  end

  def create_fragment(conn, params) do
    case params do
      %{"node_ids" => node_ids, "map_id" => map_id, "name" => name} ->
        case Maps.create_fragment_from_nodes(name, node_ids, map_id,
               description: params["description"]
             ) do
          {:ok, fragment} ->
            conn |> put_status(:created) |> json(fragment_json(fragment))

          {:error, :no_nodes} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: %{nodes: ["no matching nodes found"]}})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: translate_errors(changeset)})
        end

      %{"name" => _name, "data" => _data} ->
        case Maps.create_fragment(params) do
          {:ok, fragment} ->
            conn |> put_status(:created) |> json(fragment_json(fragment))

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: translate_errors(changeset)})
        end

      _ ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: %{params: ["must include name and either node_ids+map_id or data"]}})
    end
  end

  def show_fragment(conn, %{"id" => id}) do
    fragment = Maps.get_fragment!(id)
    json(conn, fragment_json(fragment))
  end

  def delete_fragment(conn, %{"id" => id}) do
    fragment = Maps.get_fragment!(id)
    {:ok, _} = Maps.delete_fragment(fragment)
    send_resp(conn, :no_content, "")
  end

  def invoke_fragment(conn, %{"id" => id} = params) do
    map = Maps.get_or_create_default_map()
    map_id = params["map_id"] || map.id
    x_pct = params["x_pct"] || 10.0
    y_pct = params["y_pct"] || 10.0

    case Maps.invoke_fragment(id, map_id, x_pct, y_pct) do
      {:ok, %{nodes: nodes, edges: edges}} ->
        json(conn, %{
          nodes: Enum.map(nodes, &node_json/1),
          edges: Enum.map(edges, &edge_json/1)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  defp fragment_json(f) do
    %{
      id: f.id,
      name: f.name,
      description: f.description,
      data: f.data,
      inserted_at: f.inserted_at,
      updated_at: f.updated_at
    }
  end

  defp node_json(%Node{} = n) do
    %{
      id: n.id,
      map_id: n.map_id,
      x_pct: n.x_pct,
      y_pct: n.y_pct,
      text: n.text,
      metadata: n.metadata || %{}
    }
  end

  defp edge_json(%Edge{} = e) do
    %{
      id: e.id,
      map_id: e.map_id,
      source_id: e.source_id,
      target_id: e.target_id,
      metadata: e.metadata || %{}
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
