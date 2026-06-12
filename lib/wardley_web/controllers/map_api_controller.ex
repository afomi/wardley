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
    maps = Maps.list_maps(current_user_id_or_nil(conn))

    json(conn, %{
      maps:
        Enum.map(maps, fn m ->
          %{id: m.id, name: m.name, updated_at: m.updated_at}
        end)
    })
  end

  def create_map(conn, params) do
    user_id =
      case conn.assigns do
        %{current_scope: %{user: %{id: id}}} -> id
        _ -> nil
      end

    attrs =
      %{"name" => params["name"], "user_id" => user_id}
      |> maybe_put_visibility(params, user_id)

    case Maps.create_map(attrs) do
      {:ok, map} ->
        conn |> put_status(:created) |> json(map_json(map))

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
    end
  end

  def update_map(conn, %{"id" => id} = params) do
    with {:ok, user_id} <- current_user_id(conn),
         true <- Maps.can_access_map?(id, user_id) do
      map = Maps.get_map!(id)

      attrs =
        params
        |> Map.take(["name"])
        |> maybe_put_owner_visibility(params, id, user_id)

      case Maps.update_map(map, attrs) do
        {:ok, map} ->
          json(conn, map_json(map))

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
      end
    else
      _ -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end

  def delete_map(conn, %{"id" => id}) do
    with {:ok, user_id} <- current_user_id(conn),
         true <- Maps.owns_map?(id, user_id) do
      map = Maps.get_map!(id)
      {:ok, _} = Maps.delete_map(map)
      send_resp(conn, :no_content, "")
    else
      _ -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end

  @doc """
  Get a specific map with all its data (for loading as a layer).
  """
  def show_map(conn, %{"id" => id}) do
    if Maps.can_view_map?(id, current_user_id_or_nil(conn)) do
      %{map: map, nodes: nodes, edges: edges} = Maps.get_map_with_data(id)

      json(conn, %{
        map: %{id: map.id, name: map.name},
        nodes: Enum.map(nodes, &node_json/1),
        edges: Enum.map(edges, &edge_json/1)
      })
    else
      conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  end

  def map_svg(conn, %{"id" => id}) do
    %{map: map, nodes: nodes, edges: edges} = Maps.get_map_with_data(id)
    svg = Wardley.Maps.Svg.render(map, nodes, edges)

    conn
    |> put_resp_content_type("image/svg+xml")
    |> send_resp(200, svg)
  end

  def map_dsl(conn, %{"id" => id}) do
    %{map: map, nodes: nodes, edges: edges} = Maps.get_map_with_data(id)
    dsl = Wardley.Maps.Dsl.render(map, nodes, edges)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, dsl)
  end

  def create_node(conn, params) do
    map_id = params["map_id"] || Maps.get_or_create_default_map().id

    if can_write_map?(conn, map_id) do
      attrs = %{
        "map_id" => map_id,
        "x_pct" => params["x_pct"],
        "y_pct" => params["y_pct"],
        "text" => params["text"] || "Node",
        "metadata" => params["metadata"] || %{}
      }

      case Maps.create_node(attrs) do
        {:ok, node} ->
          json(conn, node_json(node))

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
    end
  end

  def show_node(conn, %{"id" => id}) do
    node = Maps.get_node!(id)

    if can_read_map?(conn, node.map_id) do
      json(conn, node_json(node))
    else
      forbid(conn)
    end
  end

  def update_node(conn, %{"id" => id} = params) do
    node = Maps.get_node!(id)

    if can_write_map?(conn, node.map_id) do
      attrs = Map.take(params, ["x_pct", "y_pct", "text"])

      # Merge metadata rather than replace — only keys present in the request are updated
      attrs = case params do
        %{"metadata" => incoming} when is_map(incoming) ->
          Map.put(attrs, "metadata", Map.merge(node.metadata || %{}, incoming))
        _ ->
          attrs
      end

      case Maps.update_node(node, attrs) do
        {:ok, node} ->
          json(conn, node_json(node))

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
    end
  end

  def put_node_metadata_key(conn, %{"id" => id, "key" => key} = params) do
    node = Maps.get_node!(id)

    if can_write_map?(conn, node.map_id) do
      value = params["value"]
      metadata = Map.put(node.metadata || %{}, key, value)

      case Maps.update_node(node, %{"metadata" => metadata}) do
        {:ok, node} -> json(conn, node_json(node))
        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
    end
  end

  def delete_node_metadata_key(conn, %{"id" => id, "key" => key}) do
    node = Maps.get_node!(id)

    if can_write_map?(conn, node.map_id) do
      metadata = Map.delete(node.metadata || %{}, key)

      case Maps.update_node(node, %{"metadata" => metadata}) do
        {:ok, node} -> json(conn, node_json(node))
        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
    end
  end

  def delete_node(conn, %{"id" => id}) do
    node = Maps.get_node!(id)

    if can_write_map?(conn, node.map_id) do
      {:ok, _} = Maps.delete_node(node)
      send_resp(conn, :no_content, "")
    else
      forbid(conn)
    end
  end

  def create_edge(conn, params) do
    map_id = params["map_id"] || edge_map_id(params)

    if can_write_map?(conn, map_id) do
      attrs = %{
        "map_id" => map_id,
        "source_id" => params["source_id"],
        "target_id" => params["target_id"],
        "metadata" => params["metadata"] || %{}
      }

      case Maps.create_edge(attrs) do
        {:ok, edge} ->
          json(conn, edge_json(edge))

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
    end
  end

  def delete_edge(conn, %{"id" => id}) do
    edge = Maps.get_edge!(id)

    if can_write_map?(conn, edge.map_id) do
      {:ok, _} = Maps.delete_edge(edge)
      send_resp(conn, :no_content, "")
    else
      forbid(conn)
    end
  end

  def show_edge(conn, %{"id" => id}) do
    edge = Maps.get_edge!(id)

    if can_read_map?(conn, edge.map_id) do
      json(conn, edge_json(edge))
    else
      forbid(conn)
    end
  end

  def update_edge(conn, %{"id" => id} = params) do
    edge = Maps.get_edge!(id)

    if can_write_map?(conn, edge.map_id) do
      attrs = case params do
        %{"metadata" => incoming} when is_map(incoming) ->
          %{"metadata" => Map.merge(edge.metadata || %{}, incoming)}
        _ ->
          %{}
      end

      case Maps.update_edge(edge, attrs) do
        {:ok, edge} ->
          json(conn, edge_json(edge))

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
    end
  end

  def put_edge_metadata_key(conn, %{"id" => id, "key" => key} = params) do
    edge = Maps.get_edge!(id)

    if can_write_map?(conn, edge.map_id) do
      value = params["value"]
      metadata = Map.put(edge.metadata || %{}, key, value)

      case Maps.update_edge(edge, %{"metadata" => metadata}) do
        {:ok, edge} -> json(conn, edge_json(edge))
        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
    end
  end

  def delete_edge_metadata_key(conn, %{"id" => id, "key" => key}) do
    edge = Maps.get_edge!(id)

    if can_write_map?(conn, edge.map_id) do
      metadata = Map.delete(edge.metadata || %{}, key)

      case Maps.update_edge(edge, %{"metadata" => metadata}) do
        {:ok, edge} -> json(conn, edge_json(edge))
        {:error, changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{errors: translate_errors(changeset)})
      end
    else
      forbid(conn)
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

  defp map_json(%Maps.Map{} = m) do
    %{
      id: m.id,
      name: m.name,
      visibility: m.visibility,
      inserted_at: m.inserted_at,
      updated_at: m.updated_at
    }
  end

  # On create, honor a requested visibility only when the map has an owner —
  # a private map with no owner would be invisible to everyone.
  defp maybe_put_visibility(attrs, params, user_id) do
    case {user_id, params["visibility"]} do
      {nil, _} -> attrs
      {_id, vis} when is_binary(vis) -> Map.put(attrs, "visibility", vis)
      _ -> attrs
    end
  end

  # On update, only the owner may change visibility.
  defp maybe_put_owner_visibility(attrs, params, map_id, user_id) do
    case params["visibility"] do
      vis when is_binary(vis) ->
        if Maps.owns_map?(map_id, user_id),
          do: Map.put(attrs, "visibility", vis),
          else: attrs

      _ ->
        attrs
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

  defp edge_map_id(%{"source_id" => source_id}) when not is_nil(source_id) do
    Maps.get_node!(source_id).map_id
  end

  defp edge_map_id(_params), do: Maps.get_or_create_default_map().id

  defp current_user_id(conn) do
    case conn.assigns do
      %{current_scope: %{user: %{id: id}}} -> {:ok, id}
      _ -> :error
    end
  end

  defp current_user_id_or_nil(conn) do
    case current_user_id(conn) do
      {:ok, id} -> id
      :error -> nil
    end
  end

  # May the caller modify the contents (nodes/edges) of this map?
  #
  # Open maps (e.g. the default sandbox) are writable by anyone, which keeps the
  # in-app editor working for anonymous sessions. Any other map requires the
  # caller to be its owner or a member.
  defp can_read_map?(conn, map_id) do
    Maps.can_read_map?(map_id, current_user_id_or_nil(conn))
  end

  defp can_write_map?(conn, map_id) do
    Maps.can_write_map?(map_id, current_user_id_or_nil(conn))
  end

  defp forbid(conn) do
    conn |> put_status(:not_found) |> json(%{error: "not_found"})
  end
end
