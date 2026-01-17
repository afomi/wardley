defmodule WardleyWeb.SearchControllerTest do
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Maps
  alias Wardley.Personas

  setup do
    map = Maps.get_or_create_default_map()

    {:ok, _node} =
      Maps.create_node(%{
        map_id: map.id,
        text: "Cloud Platform",
        x_pct: 85.0,
        y_pct: 12.0,
        metadata: %{"category" => "Infrastructure"}
      })

    {:ok, _persona} =
      Personas.create_persona(%{
        name: "IT Administrator",
        description: "Manages cloud infrastructure"
      })

    {:ok, map: map}
  end

  describe "GET /api/search" do
    test "returns results grouped by type", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=cloud")
      response = json_response(conn, 200)

      assert Map.has_key?(response, "nodes")
      assert Map.has_key?(response, "maps")
      assert Map.has_key?(response, "personas")
    end

    test "finds nodes by text", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=platform")
      response = json_response(conn, 200)

      assert length(response["nodes"]) == 1
      assert hd(response["nodes"])["text"] == "Cloud Platform"
    end

    test "finds personas by name", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=administrator")
      response = json_response(conn, 200)

      assert length(response["personas"]) == 1
      assert hd(response["personas"])["name"] == "IT Administrator"
    end

    test "returns error for empty query", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=")
      response = json_response(conn, 200)

      assert response["error"] == "Query too short"
    end

    test "respects limit parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=a&limit=1")
      response = json_response(conn, 200)

      assert length(response["nodes"]) <= 1
    end

    test "filters by types parameter", %{conn: conn} do
      conn = get(conn, ~p"/api/search?q=cloud&types=nodes")
      response = json_response(conn, 200)

      assert length(response["nodes"]) >= 1
      assert response["maps"] == []
      assert response["personas"] == []
    end
  end

  describe "GET /api/categories" do
    test "returns list of categories", %{conn: conn} do
      conn = get(conn, ~p"/api/categories")
      response = json_response(conn, 200)

      assert "Infrastructure" in response["categories"]
    end
  end

  describe "GET /api/categories/:category" do
    test "returns aggregated data for category", %{conn: conn} do
      conn = get(conn, ~p"/api/categories/Infrastructure")
      response = json_response(conn, 200)

      assert response["category"] == "Infrastructure"
      assert response["count"] >= 1
      assert is_list(response["nodes"])
      assert is_list(response["positions"])
    end

    test "includes evolution stats", %{conn: conn} do
      conn = get(conn, ~p"/api/categories/Infrastructure")
      response = json_response(conn, 200)

      assert is_map(response["evolution_stats"])
      assert Map.has_key?(response["evolution_stats"], "min")
      assert Map.has_key?(response["evolution_stats"], "max")
      assert Map.has_key?(response["evolution_stats"], "mean")
    end
  end
end
