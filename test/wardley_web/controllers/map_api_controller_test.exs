defmodule WardleyWeb.MapAPIControllerTest do
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Maps
  alias Wardley.Accounts.Scope

  import Wardley.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    map = Maps.get_or_create_default_map()
    Maps.update_map(map, %{user_id: user.id})
    map = Maps.get_map!(map.id)

    conn =
      conn
      |> Plug.Conn.assign(:current_scope, Scope.for_user(user))

    {:ok, conn: conn, map: map, user: user}
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

  describe "POST /api/maps" do
    test "creates a map with a name", %{conn: conn} do
      conn = post(conn, ~p"/api/maps", %{"name" => "EHR Map"})
      response = json_response(conn, 201)

      assert response["name"] == "EHR Map"
      assert response["id"] != nil
      assert response["inserted_at"] != nil
    end

    test "returns error without a name", %{conn: conn} do
      conn = post(conn, ~p"/api/maps", %{})
      response = json_response(conn, 422)

      assert response["errors"]["name"] != nil
    end
  end

  describe "PATCH /api/maps/:id" do
    test "renames a map", %{conn: conn, map: map} do
      conn = patch(conn, ~p"/api/maps/#{map.id}", %{"name" => "Renamed Map"})
      response = json_response(conn, 200)

      assert response["name"] == "Renamed Map"
      assert response["id"] == map.id
    end

    test "returns error for blank name", %{conn: conn, map: map} do
      conn = patch(conn, ~p"/api/maps/#{map.id}", %{"name" => ""})
      response = json_response(conn, 422)

      assert response["errors"]["name"] != nil
    end
  end

  describe "map ownership" do
    test "PATCH returns 404 for a map the user does not own", %{conn: conn} do
      other_user = user_fixture(%{email: "other@example.com"})
      {:ok, other_map} = Maps.create_map(%{name: "Other Map", user_id: other_user.id})

      conn = patch(conn, ~p"/api/maps/#{other_map.id}", %{"name" => "Hijacked"})

      assert json_response(conn, 404)["error"] == "not_found"
    end

    test "DELETE returns 404 for a map the user does not own", %{conn: conn} do
      other_user = user_fixture(%{email: "other2@example.com"})
      {:ok, other_map} = Maps.create_map(%{name: "Other Map", user_id: other_user.id})

      conn = delete(conn, ~p"/api/maps/#{other_map.id}")

      assert json_response(conn, 404)["error"] == "not_found"
    end

    test "PATCH allowed for a member", %{conn: conn} do
      other_user = user_fixture(%{email: "owner3@example.com"})
      {:ok, shared_map} = Maps.create_map(%{name: "Shared Map", user_id: other_user.id})
      user = conn.assigns.current_scope.user
      Maps.add_member(shared_map.id, user.id)

      conn = patch(conn, ~p"/api/maps/#{shared_map.id}", %{"name" => "Updated by member"})
      response = json_response(conn, 200)

      assert response["name"] == "Updated by member"
    end
  end

  describe "map visibility" do
    test "GET /api/maps omits another user's private map", %{conn: conn} do
      other = user_fixture(%{email: "vis-api-1@example.com"})

      {:ok, private} =
        Maps.create_map(%{name: "Hidden", user_id: other.id, visibility: "private"})

      {:ok, public} = Maps.create_map(%{name: "Shown", user_id: other.id})

      ids =
        get(conn, ~p"/api/maps")
        |> json_response(200)
        |> Map.fetch!("maps")
        |> Enum.map(& &1["id"])

      refute private.id in ids
      assert public.id in ids
    end

    test "GET /api/maps/:id returns 404 for another user's private map", %{conn: conn} do
      other = user_fixture(%{email: "vis-api-2@example.com"})

      {:ok, private} =
        Maps.create_map(%{name: "Hidden", user_id: other.id, visibility: "private"})

      conn = get(conn, ~p"/api/maps/#{private.id}")

      assert json_response(conn, 404)["error"] == "not_found"
    end

    test "GET /api/maps/:id returns a private map to its owner", %{conn: conn, user: user} do
      {:ok, private} = Maps.create_map(%{name: "Mine", user_id: user.id, visibility: "private"})

      conn = get(conn, ~p"/api/maps/#{private.id}")
      response = json_response(conn, 200)

      assert response["map"]["id"] == private.id
    end

    test "owner can set a map private via PATCH", %{conn: conn, map: map} do
      conn = patch(conn, ~p"/api/maps/#{map.id}", %{"visibility" => "private"})
      response = json_response(conn, 200)

      assert response["visibility"] == "private"
    end

    test "a member cannot change visibility via PATCH", %{conn: conn} do
      other = user_fixture(%{email: "vis-api-3@example.com"})
      {:ok, shared} = Maps.create_map(%{name: "Shared", user_id: other.id})
      user = conn.assigns.current_scope.user
      Maps.add_member(shared.id, user.id)

      conn = patch(conn, ~p"/api/maps/#{shared.id}", %{"visibility" => "private"})
      json_response(conn, 200)

      assert Maps.get_map!(shared.id).visibility == "public"
    end
  end

  describe "DELETE /api/maps/:id" do
    test "deletes the map", %{conn: conn, user: user} do
      {:ok, map} = Maps.create_map(%{name: "Temporary Map", user_id: user.id})

      conn = delete(conn, ~p"/api/maps/#{map.id}")

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_map!(map.id) end
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

    test "creates a node on the requested map", %{conn: conn} do
      {:ok, map} = Wardley.Repo.insert(%Wardley.Maps.Map{name: "Selected Map"})

      conn =
        post(conn, ~p"/api/nodes", %{
          "map_id" => map.id,
          "x_pct" => 45.0,
          "y_pct" => 75.0,
          "text" => "Selected Component"
        })

      response = json_response(conn, 200)

      assert response["map_id"] == map.id
      assert response["text"] == "Selected Component"
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
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Original", x_pct: 50.0, y_pct: 50.0})

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
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Deletable", x_pct: 50.0, y_pct: 50.0})

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
      {:ok, source} =
        Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})

      {:ok, target} =
        Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

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
      {:ok, target} =
        Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

      params = %{"target_id" => target.id}

      conn = post(conn, ~p"/api/edges", params)
      response = json_response(conn, 422)

      assert response["errors"]["source_id"] != nil
    end

    test "infers the edge map from the source node", %{conn: conn} do
      {:ok, map} = Wardley.Repo.insert(%Wardley.Maps.Map{name: "Dependency Map"})

      {:ok, source} =
        Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})

      {:ok, target} =
        Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

      conn = post(conn, ~p"/api/edges", %{"source_id" => source.id, "target_id" => target.id})
      response = json_response(conn, 200)

      assert response["map_id"] == map.id
    end
  end

  describe "PATCH /api/edges/:id" do
    test "updates edge metadata", %{conn: conn, map: map} do
      {:ok, source} =
        Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})

      {:ok, target} =
        Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

      {:ok, edge} =
        Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      conn = patch(conn, ~p"/api/edges/#{edge.id}", %{"metadata" => %{"relationship" => "uses"}})
      response = json_response(conn, 200)

      assert response["metadata"] == %{"relationship" => "uses"}
    end
  end

  describe "DELETE /api/edges/:id" do
    test "deletes the edge", %{conn: conn, map: map} do
      {:ok, source} =
        Maps.create_node(%{map_id: map.id, text: "Source", x_pct: 20.0, y_pct: 80.0})

      {:ok, target} =
        Maps.create_node(%{map_id: map.id, text: "Target", x_pct: 60.0, y_pct: 40.0})

      {:ok, edge} =
        Maps.create_edge(%{map_id: map.id, source_id: source.id, target_id: target.id})

      conn = delete(conn, ~p"/api/edges/#{edge.id}")

      assert response(conn, 204)
      assert_raise Ecto.NoResultsError, fn -> Maps.get_edge!(edge.id) end
    end
  end

  describe "GET /api/maps/:id/dsl" do
    test "returns a map as OWM DSL text", %{conn: conn, map: map} do
      {:ok, node} =
        Maps.create_node(%{map_id: map.id, text: "Customer", x_pct: 50.0, y_pct: 10.0})

      {:ok, target} = Maps.create_node(%{map_id: map.id, text: "API", x_pct: 60.0, y_pct: 40.0})
      {:ok, _edge} = Maps.create_edge(%{map_id: map.id, source_id: node.id, target_id: target.id})

      conn = get(conn, ~p"/api/maps/#{map.id}/dsl")
      response = response(conn, 200)

      assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
      assert response =~ "title #{map.name}"
      assert response =~ "component Customer"
      assert response =~ "Customer->API"
    end
  end
end
