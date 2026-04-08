defmodule WardleyWeb.Features.TypeAheadTest do
  @moduledoc """
  Feature specs for component type-ahead with shared vocabulary.

  Exercises the full flow a user experiences:
  1. Create nodes on a map (clicking canvas → POST /api/nodes)
  2. Rename them (typing label → PATCH /api/nodes/:id)
  3. On a new node, type a partial name and get suggestions (GET /api/suggestions)
  4. Select a suggestion and save
  """
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Maps

  describe "as a mapper building a map, I get type-ahead suggestions from shared vocabulary" do
    test "creating nodes builds the vocabulary that powers suggestions", %{conn: conn} do
      # User clicks empty canvas three times, creating nodes
      conn1 = post(conn, ~p"/api/nodes", %{"x_pct" => 25.0, "y_pct" => 80.0, "text" => "Node"})
      node1 = json_response(conn1, 200)

      conn2 = post(conn, ~p"/api/nodes", %{"x_pct" => 50.0, "y_pct" => 60.0, "text" => "Node"})
      node2 = json_response(conn2, 200)

      conn3 = post(conn, ~p"/api/nodes", %{"x_pct" => 75.0, "y_pct" => 30.0, "text" => "Node"})
      node3 = json_response(conn3, 200)

      # User renames each node (inline label edit → PATCH)
      patch(conn, ~p"/api/nodes/#{node1["id"]}", %{"text" => "Customer"})
      patch(conn, ~p"/api/nodes/#{node2["id"]}", %{"text" => "CRM Platform"})
      patch(conn, ~p"/api/nodes/#{node3["id"]}", %{"text" => "Cloud Infrastructure"})

      # User creates a 4th node and starts typing "C" — suggestions appear
      suggestions_conn = get(conn, ~p"/api/suggestions?q=C")
      suggestions = json_response(suggestions_conn, 200)["suggestions"]

      # All three components starting with C should appear
      texts = Enum.map(suggestions, & &1["text"])
      assert "Customer" in texts
      assert "CRM Platform" in texts
      assert "Cloud Infrastructure" in texts
    end

    test "suggestions show usage count so user can see popular components", %{conn: conn} do
      map = Maps.get_or_create_default_map()
      {:ok, map2} = Wardley.Repo.insert(%Wardley.Maps.Map{name: "Team Map"})

      # "API Gateway" used in two maps
      Maps.create_node(%{map_id: map.id, text: "API Gateway", x_pct: 60.0, y_pct: 40.0})
      Maps.create_node(%{map_id: map2.id, text: "API Gateway", x_pct: 65.0, y_pct: 35.0})

      # "API Documentation" used in one map
      Maps.create_node(%{map_id: map.id, text: "API Documentation", x_pct: 50.0, y_pct: 50.0})

      conn = get(conn, ~p"/api/suggestions?q=API")
      suggestions = json_response(conn, 200)["suggestions"]

      gateway = Enum.find(suggestions, &(&1["text"] == "API Gateway"))
      docs = Enum.find(suggestions, &(&1["text"] == "API Documentation"))

      assert gateway["map_count"] == 2
      assert gateway["usage_count"] == 2
      assert docs["map_count"] == 1
      assert docs["usage_count"] == 1
    end

    test "selecting a suggestion renames the node via the same PATCH flow", %{conn: conn} do
      map = Maps.get_or_create_default_map()

      # Existing vocabulary from prior mapping
      Maps.create_node(%{map_id: map.id, text: "Payment Processing", x_pct: 70.0, y_pct: 50.0})

      # User creates a new node (click on canvas)
      new_conn = post(conn, ~p"/api/nodes", %{"x_pct" => 30.0, "y_pct" => 60.0, "text" => "Node"})
      new_node = json_response(new_conn, 200)
      assert new_node["text"] == "Node"

      # User types "Pay" and sees "Payment Processing" suggested
      suggest_conn = get(conn, ~p"/api/suggestions?q=Pay")
      suggestions = json_response(suggest_conn, 200)["suggestions"]
      assert hd(suggestions)["text"] == "Payment Processing"

      # User selects the suggestion (sets input value, then saves via PATCH)
      rename_conn =
        patch(conn, ~p"/api/nodes/#{new_node["id"]}", %{"text" => "Payment Processing"})

      renamed = json_response(rename_conn, 200)
      assert renamed["text"] == "Payment Processing"

      # Now the vocabulary reflects the increased usage
      suggest_conn2 = get(conn, ~p"/api/suggestions?q=Pay")
      suggestions2 = json_response(suggest_conn2, 200)["suggestions"]
      payment = Enum.find(suggestions2, &(&1["text"] == "Payment Processing"))
      assert payment["usage_count"] == 2
    end

    test "default 'Node' text is excluded from suggestions", %{conn: conn} do
      # Several unedited nodes sitting around with default text
      post(conn, ~p"/api/nodes", %{"x_pct" => 10.0, "y_pct" => 10.0, "text" => "Node"})
      post(conn, ~p"/api/nodes", %{"x_pct" => 20.0, "y_pct" => 20.0, "text" => "Node"})

      # Also a real component
      post(conn, ~p"/api/nodes", %{
        "x_pct" => 30.0,
        "y_pct" => 30.0,
        "text" => "Notification Service"
      })

      conn = get(conn, ~p"/api/suggestions?q=No")
      suggestions = json_response(conn, 200)["suggestions"]

      texts = Enum.map(suggestions, & &1["text"])
      assert "Notification Service" in texts
      refute "Node" in texts
    end

    test "suggestions are case-insensitive", %{conn: conn} do
      post(conn, ~p"/api/nodes", %{"x_pct" => 50.0, "y_pct" => 50.0, "text" => "Database"})

      conn = get(conn, ~p"/api/suggestions?q=data")
      suggestions = json_response(conn, 200)["suggestions"]

      assert length(suggestions) == 1
      assert hd(suggestions)["text"] == "Database"
    end

    test "prefix matches are prioritized over substring matches", %{conn: conn} do
      post(conn, ~p"/api/nodes", %{"x_pct" => 50.0, "y_pct" => 50.0, "text" => "Cloud Platform"})
      post(conn, ~p"/api/nodes", %{"x_pct" => 60.0, "y_pct" => 60.0, "text" => "Hybrid Cloud"})

      conn = get(conn, ~p"/api/suggestions?q=Cloud")
      suggestions = json_response(conn, 200)["suggestions"]

      assert length(suggestions) == 2
      # "Cloud Platform" starts with "Cloud" so should come first
      assert hd(suggestions)["text"] == "Cloud Platform"
    end
  end

  describe "cross-map vocabulary sharing" do
    test "components from one map appear as suggestions when building another", %{conn: conn} do
      map1 = Maps.get_or_create_default_map()
      {:ok, _map2} = Wardley.Repo.insert(%Wardley.Maps.Map{name: "New Strategy Map"})

      # Team A builds their map with specific components
      Maps.create_node(%{map_id: map1.id, text: "Identity Provider", x_pct: 80.0, y_pct: 20.0})
      Maps.create_node(%{map_id: map1.id, text: "User Database", x_pct: 70.0, y_pct: 15.0})
      Maps.create_node(%{map_id: map1.id, text: "Auth Middleware", x_pct: 60.0, y_pct: 40.0})

      # Team B starts a new map and types "Auth" — sees Team A's component
      conn = get(conn, ~p"/api/suggestions?q=Auth")
      suggestions = json_response(conn, 200)["suggestions"]

      texts = Enum.map(suggestions, & &1["text"])
      assert "Auth Middleware" in texts
    end

    test "vocabulary deduplicates across maps", %{conn: conn} do
      map1 = Maps.get_or_create_default_map()
      {:ok, map2} = Wardley.Repo.insert(%Wardley.Maps.Map{name: "Second Map"})
      {:ok, map3} = Wardley.Repo.insert(%Wardley.Maps.Map{name: "Third Map"})

      # Same component name used in three different maps
      Maps.create_node(%{map_id: map1.id, text: "Kubernetes", x_pct: 80.0, y_pct: 15.0})
      Maps.create_node(%{map_id: map2.id, text: "Kubernetes", x_pct: 75.0, y_pct: 18.0})
      Maps.create_node(%{map_id: map3.id, text: "Kubernetes", x_pct: 82.0, y_pct: 12.0})

      conn = get(conn, ~p"/api/suggestions?q=Kub")
      suggestions = json_response(conn, 200)["suggestions"]

      # Should be one suggestion, not three
      assert length(suggestions) == 1
      k8s = hd(suggestions)
      assert k8s["text"] == "Kubernetes"
      assert k8s["map_count"] == 3
      assert k8s["usage_count"] == 3
    end
  end

  describe "edge cases" do
    test "empty query returns no suggestions", %{conn: conn} do
      post(conn, ~p"/api/nodes", %{"x_pct" => 50.0, "y_pct" => 50.0, "text" => "Something"})

      conn = get(conn, ~p"/api/suggestions?q=")
      response = json_response(conn, 200)

      assert response["suggestions"] == []
    end

    test "query with no matches returns empty list", %{conn: conn} do
      post(conn, ~p"/api/nodes", %{"x_pct" => 50.0, "y_pct" => 50.0, "text" => "Database"})

      conn = get(conn, ~p"/api/suggestions?q=zzzzz")
      response = json_response(conn, 200)

      assert response["suggestions"] == []
    end

    test "limit parameter caps results", %{conn: conn} do
      # Create many components
      for i <- 1..5 do
        post(conn, ~p"/api/nodes", %{
          "x_pct" => i * 10.0,
          "y_pct" => 50.0,
          "text" => "Service #{i}"
        })
      end

      conn = get(conn, ~p"/api/suggestions?q=Service&limit=2")
      suggestions = json_response(conn, 200)["suggestions"]

      assert length(suggestions) == 2
    end

    test "special characters in query are handled safely", %{conn: conn} do
      post(conn, ~p"/api/nodes", %{"x_pct" => 50.0, "y_pct" => 50.0, "text" => "C++ Compiler"})

      conn = get(conn, ~p"/api/suggestions?q=C%2B%2B")
      suggestions = json_response(conn, 200)["suggestions"]

      assert length(suggestions) == 1
      assert hd(suggestions)["text"] == "C++ Compiler"
    end

    test "SQL injection in query is safely handled", %{conn: conn} do
      conn = get(conn, ~p"/api/suggestions?q=' OR 1=1--")
      response = json_response(conn, 200)

      assert response["suggestions"] == []
    end
  end
end
