defmodule WardleyWeb.MapAPIControllerTest do
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Maps

  setup do
    map = Maps.get_or_create_default_map()
    {:ok, map: map}
  end

  describe "GET /api/map" do
    test "returns map with nodes and edges", %{conn: conn, map: map} do
      {:ok, node1} = Maps.create_node(%{map_id: map.id, text: "Node 1", x_pct: 50.0, y_pct: 80.0})
      {:ok, node2} = Maps.create_node(%{map_id: map.id, text: "Node 2", x_pct: 70.0, y_pct: 40.0})
      {:ok, _edge} = Maps.create_edge(%{map_id: map.id, source_id: node1.id, target_id: node2.id})

      conn = get(conn, ~p"/api/map")
      response = json_response(conn, 200)

      assert response["map"]["id"] == map.id
      assert response["map"]["name"] == map.name
      assert length(response["nodes"]) == 2
      assert length(response["edges"]) == 1
    end

    test "returns empty nodes and edges for new map", %{conn: conn} do
      conn = get(conn, ~p"/api/map")
      response = json_response(conn, 200)

      assert response["nodes"] == []
      assert response["edges"] == []
    end
  end

  describe "POST /api/nodes" do
    test "creates a node with valid data", %{conn: conn} do
      params = %{
        "x_pct" => 45.0,
        "y_pct" => 75.0,
        "text" => "New Component",
        "metadata" => %{"type" => "service"}
      }

      conn = post(conn, ~p"/api/nodes", params)
      response = json_response(conn, 200)

      assert response["text"] == "New Component"
      assert response["x_pct"] == 45.0
      assert response["y_pct"] == 75.0
      assert response["metadata"] == %{"type" => "service"}
      assert response["id"] != nil
    end

    test "returns error for invalid x_pct", %{conn: conn} do
      params = %{"x_pct" => 150.0, "y_pct" => 50.0, "text" => "Bad Node"}

      conn = post(conn, ~p"/api/nodes", params)
      response = json_response(conn, 422)

      assert response["errors"]["x_pct"] != nil
    end

    test "uses default text when not provided", %{conn: conn} do
      params = %{"x_pct" => 50.0, "y_pct" => 50.0}

      conn = post(conn, ~p"/api/nodes", params)
      response = json_response(conn, 200)

      assert response["text"] == "Node"
    end
  end

  describe "PATCH /api/nodes/:id" do
    test "updates node position", %{conn: conn, map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Movable", x_pct: 20.0, y_pct: 80.0})

      conn = patch(conn, ~p"/api/nodes/#{node.id}", %{"x_pct" => 60.0, "y_pct" => 40.0})
      response = json_response(conn, 200)

      assert response["x_pct"] == 60.0
      assert response["y_pct"] == 40.0
      assert response["text"] == "Movable"
    end

    test "updates node text", %{conn: conn, map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Original", x_pct: 50.0, y_pct: 50.0})

      conn = patch(conn, ~p"/api/nodes/#{node.id}", %{"text" => "Renamed"})
      response = json_response(conn, 200)

      assert response["text"] == "Renamed"
    end

    test "updates node metadata", %{conn: conn, map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Tagged", x_pct: 50.0, y_pct: 50.0})

      conn = patch(conn, ~p"/api/nodes/#{node.id}", %{"metadata" => %{"category" => "Database"}})
      response = json_response(conn, 200)

      assert response["metadata"] == %{"category" => "Database"}
    end

    test "returns error for invalid update", %{conn: conn, map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Valid", x_pct: 50.0, y_pct: 50.0})

      conn = patch(conn, ~p"/api/nodes/#{node.id}", %{"x_pct" => -10.0})
      response = json_response(conn, 422)

      assert response["errors"]["x_pct"] != nil
    end
  end

  describe "DELETE /api/nodes/:id" do
    test "deletes the node", %{conn: conn, map: map} do
      {:ok, node} = Maps.create_node(%{map_id: map.id, text: "Deletable", x_pct: 50.0, y_pct: 50.0})

      conn = delete(conn, ~p"/api/nodes/#{node.id}")

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_node!(node.id) end
    end

    test "deletes associated edges when node is deleted", %{conn: conn, map: map} do
      {:ok, node1} = Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})
      {:ok, node2} = Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: node1.id, target_id: node2.id})

      conn = delete(conn, ~p"/api/nodes/#{node1.id}")

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_edge!(edge.id) end
    end
  end

  describe "POST /api/edges" do
    test "creates an edge between nodes", %{conn: conn, map: map} do
      {:ok, source} = Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})
      {:ok, target} = Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

      params = %{
        "source_id" => source.id,
        "target_id" => target.id,
        "metadata" => %{"relationship" => "requires"}
      }

      conn = post(conn, ~p"/api/edges", params)
      response = json_response(conn, 200)

      assert response["source_id"] == source.id
      assert response["target_id"] == target.id
      assert response["metadata"] == %{"relationship" => "requires"}
    end

    test "returns error without source_id", %{conn: conn, map: map} do
      {:ok, target} = Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

      params = %{"target_id" => target.id}

      conn = post(conn, ~p"/api/edges", params)
      response = json_response(conn, 422)

      assert response["errors"]["source_id"] != nil
    end
  end

  describe "PATCH /api/edges/:id" do
    test "updates edge metadata", %{conn: conn, map: map} do
      {:ok, source} = Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})
      {:ok, target} = Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      conn = patch(conn, ~p"/api/edges/#{edge.id}", %{"metadata" => %{"relationship" => "uses"}})
      response = json_response(conn, 200)

      assert response["metadata"] == %{"relationship" => "uses"}
    end
  end

  describe "DELETE /api/edges/:id" do
    test "deletes the edge", %{conn: conn, map: map} do
      {:ok, source} = Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})
      {:ok, target} = Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})
      {:ok, edge} = Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      conn = delete(conn, ~p"/api/edges/#{edge.id}")

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_edge!(edge.id) end
    end
  end
end
