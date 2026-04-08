defmodule Wardley.MCP.ToolsTest do
  use Wardley.DataCase, async: true

  alias Wardley.Maps
  alias Wardley.MCP.Tools

  setup do
    map = Maps.get_or_create_default_map()
    {:ok, map: map}
  end

  describe "definitions/0" do
    test "returns a list of tool definitions" do
      defs = Tools.definitions()
      names = Enum.map(defs, & &1.name)

      assert "get_map" in names
      assert "create_node" in names
      assert "move_node" in names
      assert "connect_nodes" in names
      assert "delete_node" in names
      assert "delete_edge" in names

      for def <- defs do
        assert is_binary(def.description)
        assert is_map(def.inputSchema)
      end
    end
  end

  describe "get_map" do
    test "returns default map with nodes and edges", %{map: map} do
      {:ok, n1} = Maps.create_node(%{map_id: map.id, text: "A", x_pct: 10.0, y_pct: 20.0})
      {:ok, n2} = Maps.create_node(%{map_id: map.id, text: "B", x_pct: 30.0, y_pct: 40.0})
      {:ok, _e} = Maps.create_edge(%{map_id: map.id, source_id: n1.id, target_id: n2.id})

      {:ok, json} = Tools.handle("get_map", %{})
      result = Jason.decode!(json)

      assert result["map"]["id"] == map.id
      assert length(result["nodes"]) == 2
      assert length(result["edges"]) == 1
    end
  end

  describe "create_node" do
    test "creates a node on the default map" do
      {:ok, json} =
        Tools.handle("create_node", %{"text" => "Platform", "x_pct" => 65.0, "y_pct" => 70.0})

      result = Jason.decode!(json)
      assert result["text"] == "Platform"
      assert result["x_pct"] == 65.0
      assert result["y_pct"] == 70.0
      assert result["id"] != nil
    end

    test "returns error for invalid position" do
      {:error, msg} =
        Tools.handle("create_node", %{"text" => "Bad", "x_pct" => 150.0, "y_pct" => 50.0})

      assert msg =~ "Validation failed"
    end
  end

  describe "move_node" do
    test "repositions a node", %{map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Movable", x_pct: 20.0, y_pct: 80.0})

      {:ok, json} =
        Tools.handle("move_node", %{"node_id" => node.id, "x_pct" => 60.0, "y_pct" => 40.0})

      result = Jason.decode!(json)
      assert result["x_pct"] == 60.0
      assert result["y_pct"] == 40.0
      assert result["text"] == "Movable"
    end
  end

  describe "update_node" do
    test "renames a node", %{map: map} do
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Original", x_pct: 50.0, y_pct: 50.0})

      {:ok, json} =
        Tools.handle("update_node", %{"node_id" => node.id, "text" => "Renamed"})

      result = Jason.decode!(json)
      assert result["text"] == "Renamed"
    end
  end

  describe "connect_nodes" do
    test "creates an edge between two nodes", %{map: map} do
      {:ok, n1} = Maps.create_node(%{map_id: map.id, text: "User", x_pct: 50.0, y_pct: 10.0})
      {:ok, n2} = Maps.create_node(%{map_id: map.id, text: "API", x_pct: 50.0, y_pct: 40.0})

      {:ok, json} =
        Tools.handle("connect_nodes", %{"source_id" => n1.id, "target_id" => n2.id})

      result = Jason.decode!(json)
      assert result["source_id"] == n1.id
      assert result["target_id"] == n2.id
    end
  end

  describe "delete_node" do
    test "removes a node", %{map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Doomed", x_pct: 50.0, y_pct: 50.0})

      {:ok, json} = Tools.handle("delete_node", %{"node_id" => node.id})
      result = Jason.decode!(json)
      assert result["deleted"] == true

      assert_raise Ecto.NoResultsError, fn -> Maps.get_node!(node.id) end
    end
  end

  describe "delete_edge" do
    test "removes an edge", %{map: map} do
      {:ok, n1} = Maps.create_node(%{map_id: map.id, text: "A", x_pct: 10.0, y_pct: 20.0})
      {:ok, n2} = Maps.create_node(%{map_id: map.id, text: "B", x_pct: 30.0, y_pct: 40.0})
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: n1.id, target_id: n2.id})

      {:ok, json} = Tools.handle("delete_edge", %{"edge_id" => edge.id})
      result = Jason.decode!(json)
      assert result["deleted"] == true

      assert_raise Ecto.NoResultsError, fn -> Maps.get_edge!(edge.id) end
    end
  end

  describe "list_maps" do
    test "returns all maps" do
      {:ok, json} = Tools.handle("list_maps", %{})
      result = Jason.decode!(json)

      assert is_list(result["maps"])
      assert length(result["maps"]) >= 1

      map_entry = hd(result["maps"])
      assert map_entry["id"]
      assert map_entry["name"]
    end
  end

  describe "get_map_svg" do
    test "returns SVG markup for default map", %{map: map} do
      {:ok, n1} = Maps.create_node(%{map_id: map.id, text: "User", x_pct: 50.0, y_pct: 10.0})
      {:ok, n2} = Maps.create_node(%{map_id: map.id, text: "API", x_pct: 50.0, y_pct: 40.0})
      {:ok, _e} = Maps.create_edge(%{map_id: map.id, source_id: n1.id, target_id: n2.id})

      {:ok, svg} = Tools.handle("get_map_svg", %{})

      assert svg =~ "<svg"
      assert svg =~ "User"
      assert svg =~ "API"
      assert svg =~ "<line"
    end
  end

  describe "unknown tool" do
    test "returns error for unknown tool name" do
      {:error, msg} = Tools.handle("nonexistent", %{})
      assert msg =~ "Unknown tool"
    end
  end
end
