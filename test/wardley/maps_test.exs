defmodule Wardley.MapsTest do
  use Wardley.DataCase, async: true

  alias Wardley.Maps
  alias Wardley.Maps.{Map, Node, Edge}

  describe "maps" do
    test "get_or_create_default_map/0 creates a map if none exists" do
      map = Maps.get_or_create_default_map()

      assert %Map{} = map
      assert map.name == "Default Map"
      assert map.id != nil
    end

    test "get_or_create_default_map/0 returns existing map on subsequent calls" do
      map1 = Maps.get_or_create_default_map()
      map2 = Maps.get_or_create_default_map()

      assert map1.id == map2.id
    end

    test "get_map!/1 returns the map with given id" do
      map = Maps.get_or_create_default_map()
      fetched = Maps.get_map!(map.id)

      assert fetched.id == map.id
      assert fetched.name == map.name
    end
  end

  describe "nodes" do
    setup do
      map = Maps.get_or_create_default_map()
      {:ok, map: map}
    end

    test "create_node/1 with valid data creates a node", %{map: map} do
      attrs = %{
        map_id: map.id,
        text: "Test Component",
        x_pct: 50.0,
        y_pct: 75.0,
        metadata: %{"type" => "service"}
      }

      assert {:ok, %Node{} = node} = Maps.create_node(attrs)
      assert node.text == "Test Component"
      assert node.x_pct == 50.0
      assert node.y_pct == 75.0
      assert node.metadata == %{"type" => "service"}
    end

    test "create_node/1 with invalid x_pct fails", %{map: map} do
      attrs = %{map_id: map.id, text: "Bad Node", x_pct: 150.0, y_pct: 50.0}

      assert {:error, changeset} = Maps.create_node(attrs)
      assert "must be less than or equal to 100.0" in errors_on(changeset).x_pct
    end

    test "create_node/1 with negative y_pct fails", %{map: map} do
      attrs = %{map_id: map.id, text: "Bad Node", x_pct: 50.0, y_pct: -10.0}

      assert {:error, changeset} = Maps.create_node(attrs)
      assert "must be greater than or equal to 0.0" in errors_on(changeset).y_pct
    end

    test "create_node/1 without text fails", %{map: map} do
      attrs = %{map_id: map.id, x_pct: 50.0, y_pct: 50.0}

      assert {:error, changeset} = Maps.create_node(attrs)
      assert "can't be blank" in errors_on(changeset).text
    end

    test "list_nodes/1 returns all nodes for a map", %{map: map} do
      {:ok, node1} = Maps.create_node(%{map_id: map.id, text: "Node 1", x_pct: 10.0, y_pct: 90.0})
      {:ok, node2} = Maps.create_node(%{map_id: map.id, text: "Node 2", x_pct: 80.0, y_pct: 20.0})

      nodes = Maps.list_nodes(map.id)

      assert length(nodes) == 2
      assert Enum.any?(nodes, &(&1.id == node1.id))
      assert Enum.any?(nodes, &(&1.id == node2.id))
    end

    test "get_node!/1 returns the node with given id", %{map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Findable", x_pct: 50.0, y_pct: 50.0})

      fetched = Maps.get_node!(node.id)

      assert fetched.id == node.id
      assert fetched.text == "Findable"
    end

    test "update_node/2 with valid data updates the node", %{map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Original", x_pct: 50.0, y_pct: 50.0})

      assert {:ok, updated} = Maps.update_node(node, %{text: "Updated", x_pct: 75.0})
      assert updated.text == "Updated"
      assert updated.x_pct == 75.0
      assert updated.y_pct == 50.0
    end

    test "update_node/2 with invalid data returns error changeset", %{map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Original", x_pct: 50.0, y_pct: 50.0})

      assert {:error, changeset} = Maps.update_node(node, %{x_pct: 200.0})
      assert "must be less than or equal to 100.0" in errors_on(changeset).x_pct
    end

    test "delete_node/1 deletes the node", %{map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Deletable", x_pct: 50.0, y_pct: 50.0})

      assert {:ok, %Node{}} = Maps.delete_node(node)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_node!(node.id) end
    end

    test "node metadata defaults to empty map", %{map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "No Metadata", x_pct: 50.0, y_pct: 50.0})

      assert node.metadata == %{}
    end
  end

  describe "edges" do
    setup do
      map = Maps.get_or_create_default_map()
      {:ok, source} = Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})
      {:ok, target} = Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})
      {:ok, map: map, source: source, target: target}
    end

    test "create_edge/1 with valid data creates an edge", %{map: map, source: source, target: target} do
      attrs = %{
        map_id: map.id,
        source_id: source.id,
        target_id: target.id,
        metadata: %{"relationship" => "requires"}
      }

      assert {:ok, %Edge{} = edge} = Maps.create_edge(attrs)
      assert edge.source_id == source.id
      assert edge.target_id == target.id
      assert edge.metadata == %{"relationship" => "requires"}
    end

    test "create_edge/1 without source_id fails", %{map: map, target: target} do
      attrs = %{map_id: map.id, target_id: target.id}

      assert {:error, changeset} = Maps.create_edge(attrs)
      assert "can't be blank" in errors_on(changeset).source_id
    end

    test "list_edges/1 returns all edges for a map", %{map: map, source: source, target: target} do
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      edges = Maps.list_edges(map.id)

      assert length(edges) == 1
      assert hd(edges).id == edge.id
    end

    test "get_edge!/1 returns the edge with given id", %{map: map, source: source, target: target} do
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      fetched = Maps.get_edge!(edge.id)

      assert fetched.id == edge.id
    end

    test "update_edge/2 updates edge metadata", %{map: map, source: source, target: target} do
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      assert {:ok, updated} = Maps.update_edge(edge, %{metadata: %{"relationship" => "uses"}})
      assert updated.metadata == %{"relationship" => "uses"}
    end

    test "delete_edge/1 deletes the edge", %{map: map, source: source, target: target} do
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      assert {:ok, %Edge{}} = Maps.delete_edge(edge)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_edge!(edge.id) end
    end

    test "edge metadata defaults to empty map", %{map: map, source: source, target: target} do
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      assert edge.metadata == %{}
    end
  end
end
