defmodule Wardley.MCP.Tools do
  @moduledoc """
  MCP tool definitions and handlers for Wardley map operations.

  Each tool calls `Wardley.Maps` directly — the same domain layer
  the HTTP API uses.
  """
  alias Wardley.Maps

  @evolution_desc """
  x_pct: Evolution axis (0-100). \
  0 = Genesis (novel, uncertain), \
  25 = Custom-Built, \
  50 = Product/Rental, \
  75 = Commodity/Utility. \
  Components naturally evolve left-to-right over time.\
  """

  @visibility_desc """
  y_pct: Value chain visibility (0-100). \
  0 = most visible (closest to user need), \
  100 = least visible (deep infrastructure). \
  Components higher in the chain depend on those below.\
  """

  def definitions do
    [
      %{
        name: "get_map",
        description:
          "Get the current Wardley map with all its nodes (components) and edges (dependencies). " <>
            "Returns the map state so you can see what exists before making changes.",
        inputSchema: %{
          type: "object",
          properties: %{
            map_id: %{
              type: "integer",
              description: "Optional map ID. Omit to use the default map."
            }
          }
        }
      },
      %{
        name: "create_node",
        description:
          "Add a component (node) to the Wardley map. " <>
            @evolution_desc <> " " <> @visibility_desc,
        inputSchema: %{
          type: "object",
          properties: %{
            text: %{type: "string", description: "Component name"},
            x_pct: %{
              type: "number",
              description: "Evolution position (0=Genesis, 100=Commodity)"
            },
            y_pct: %{
              type: "number",
              description: "Value chain position (0=visible/user-facing, 100=invisible/infrastructure)"
            }
          },
          required: ["text", "x_pct", "y_pct"]
        }
      },
      %{
        name: "move_node",
        description:
          "Reposition a component on the map. " <>
            @evolution_desc <> " " <> @visibility_desc,
        inputSchema: %{
          type: "object",
          properties: %{
            node_id: %{type: "integer", description: "ID of the node to move"},
            x_pct: %{
              type: "number",
              description: "New evolution position (0=Genesis, 100=Commodity)"
            },
            y_pct: %{
              type: "number",
              description: "New value chain position (0=visible, 100=invisible)"
            }
          },
          required: ["node_id", "x_pct", "y_pct"]
        }
      },
      %{
        name: "update_node",
        description: "Update a component's name or metadata.",
        inputSchema: %{
          type: "object",
          properties: %{
            node_id: %{type: "integer", description: "ID of the node to update"},
            text: %{type: "string", description: "New component name"},
            metadata: %{type: "object", description: "Arbitrary metadata to store on the node"}
          },
          required: ["node_id"]
        }
      },
      %{
        name: "connect_nodes",
        description:
          "Create a dependency edge between two components. " <>
            "The source depends on the target (source is higher in the value chain).",
        inputSchema: %{
          type: "object",
          properties: %{
            source_id: %{type: "integer", description: "ID of the dependent component"},
            target_id: %{type: "integer", description: "ID of the component being depended on"}
          },
          required: ["source_id", "target_id"]
        }
      },
      %{
        name: "delete_node",
        description: "Remove a component from the map. Also removes any edges connected to it.",
        inputSchema: %{
          type: "object",
          properties: %{
            node_id: %{type: "integer", description: "ID of the node to delete"}
          },
          required: ["node_id"]
        }
      },
      %{
        name: "delete_edge",
        description: "Remove a dependency between two components.",
        inputSchema: %{
          type: "object",
          properties: %{
            edge_id: %{type: "integer", description: "ID of the edge to delete"}
          },
          required: ["edge_id"]
        }
      }
    ]
  end

  def handle("get_map", args) do
    map =
      case args do
        %{"map_id" => id} when not is_nil(id) -> Maps.get_map!(id)
        _ -> Maps.get_or_create_default_map()
      end

    nodes = Maps.list_nodes(map.id)
    edges = Maps.list_edges(map.id)

    {:ok,
     Jason.encode!(%{
       map: %{id: map.id, name: map.name},
       nodes: Enum.map(nodes, &format_node/1),
       edges: Enum.map(edges, &format_edge/1)
     })}
  end

  def handle("create_node", %{"text" => text, "x_pct" => x, "y_pct" => y} = args) do
    map = Maps.get_or_create_default_map()

    attrs = %{
      "map_id" => map.id,
      "text" => text,
      "x_pct" => x,
      "y_pct" => y,
      "metadata" => args["metadata"] || %{}
    }

    case Maps.create_node(attrs) do
      {:ok, node} -> {:ok, Jason.encode!(format_node(node))}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def handle("move_node", %{"node_id" => id, "x_pct" => x, "y_pct" => y}) do
    node = Maps.get_node!(id)

    case Maps.update_node(node, %{"x_pct" => x, "y_pct" => y}) do
      {:ok, node} -> {:ok, Jason.encode!(format_node(node))}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def handle("update_node", %{"node_id" => id} = args) do
    node = Maps.get_node!(id)
    attrs = Map.take(args, ["text", "metadata"])

    case Maps.update_node(node, attrs) do
      {:ok, node} -> {:ok, Jason.encode!(format_node(node))}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def handle("connect_nodes", %{"source_id" => source, "target_id" => target}) do
    map = Maps.get_or_create_default_map()

    attrs = %{
      "map_id" => map.id,
      "source_id" => source,
      "target_id" => target,
      "metadata" => %{}
    }

    case Maps.create_edge(attrs) do
      {:ok, edge} -> {:ok, Jason.encode!(format_edge(edge))}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def handle("delete_node", %{"node_id" => id}) do
    node = Maps.get_node!(id)

    case Maps.delete_node(node) do
      {:ok, _} -> {:ok, Jason.encode!(%{deleted: true, node_id: id})}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def handle("delete_edge", %{"edge_id" => id}) do
    edge = Maps.get_edge!(id)

    case Maps.delete_edge(edge) do
      {:ok, _} -> {:ok, Jason.encode!(%{deleted: true, edge_id: id})}
      {:error, changeset} -> {:error, format_errors(changeset)}
    end
  end

  def handle(name, _args) do
    {:error, "Unknown tool: #{name}"}
  end

  defp format_node(n) do
    %{
      id: n.id,
      map_id: n.map_id,
      x_pct: n.x_pct,
      y_pct: n.y_pct,
      text: n.text,
      metadata: n.metadata || %{}
    }
  end

  defp format_edge(e) do
    %{
      id: e.id,
      map_id: e.map_id,
      source_id: e.source_id,
      target_id: e.target_id,
      metadata: e.metadata || %{}
    }
  end

  defp format_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    "Validation failed: #{inspect(errors)}"
  end
end
