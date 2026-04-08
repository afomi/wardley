defmodule WardleyWeb.Features.FragmentTest do
  @moduledoc """
  Feature specs for map fragments — save and invoke partial maps.

  Exercises the full flow:
  1. Create nodes and edges on a map
  2. Select nodes and save as a named fragment
  3. List available fragments
  4. Invoke a fragment onto a map, creating real nodes and edges
  5. Delete fragments
  """
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Maps

  describe "as a mapper saving reusable patterns" do
    setup %{conn: conn} do
      # Build a map with a few nodes and edges
      n1 =
        json_response(
          post(conn, ~p"/api/nodes", %{
            "x_pct" => 20.0,
            "y_pct" => 80.0,
            "text" => "Customer"
          }),
          200
        )

      n2 =
        json_response(
          post(conn, ~p"/api/nodes", %{
            "x_pct" => 50.0,
            "y_pct" => 60.0,
            "text" => "Payment Gateway"
          }),
          200
        )

      n3 =
        json_response(
          post(conn, ~p"/api/nodes", %{
            "x_pct" => 80.0,
            "y_pct" => 30.0,
            "text" => "Bank API"
          }),
          200
        )

      e1 =
        json_response(
          post(conn, ~p"/api/edges", %{
            "source_id" => n1["id"],
            "target_id" => n2["id"]
          }),
          200
        )

      e2 =
        json_response(
          post(conn, ~p"/api/edges", %{
            "source_id" => n2["id"],
            "target_id" => n3["id"]
          }),
          200
        )

      %{n1: n1, n2: n2, n3: n3, e1: e1, e2: e2, map_id: n1["map_id"]}
    end

    test "save selected nodes as a fragment and list it", ctx do
      conn = build_conn()

      # Cmd/Ctrl+click selects n1 and n2, then save as fragment
      create_conn =
        post(conn, ~p"/api/fragments", %{
          "name" => "Payment Pattern",
          "node_ids" => [ctx.n1["id"], ctx.n2["id"]],
          "map_id" => ctx.map_id
        })

      fragment = json_response(create_conn, 201)
      assert fragment["name"] == "Payment Pattern"
      assert length(fragment["data"]["nodes"]) == 2
      assert length(fragment["data"]["edges"]) == 1

      # Fragment appears in the list
      list_conn = get(conn, ~p"/api/fragments")
      fragments = json_response(list_conn, 200)["fragments"]
      assert length(fragments) == 1
      assert hd(fragments)["name"] == "Payment Pattern"
    end

    test "fragment stores positions relative to bounding box origin", ctx do
      conn = build_conn()

      create_conn =
        post(conn, ~p"/api/fragments", %{
          "name" => "Relative Test",
          "node_ids" => [ctx.n1["id"], ctx.n2["id"]],
          "map_id" => ctx.map_id
        })

      fragment = json_response(create_conn, 201)
      nodes = fragment["data"]["nodes"]

      # Original positions: Customer(20,80), Payment Gateway(50,60)
      # Relative to min(20,60): Customer(0,20), Payment Gateway(30,0)
      customer = Enum.find(nodes, &(&1["text"] == "Customer"))
      gateway = Enum.find(nodes, &(&1["text"] == "Payment Gateway"))

      assert customer["x_pct"] == 0.0
      assert customer["y_pct"] == 20.0
      assert gateway["x_pct"] == 30.0
      assert gateway["y_pct"] == 0.0
    end

    test "save all three nodes preserves both edges", ctx do
      conn = build_conn()

      create_conn =
        post(conn, ~p"/api/fragments", %{
          "name" => "Full Chain",
          "node_ids" => [ctx.n1["id"], ctx.n2["id"], ctx.n3["id"]],
          "map_id" => ctx.map_id
        })

      fragment = json_response(create_conn, 201)
      assert length(fragment["data"]["edges"]) == 2
    end
  end

  describe "invoking a fragment onto a map" do
    setup do
      map = Maps.get_or_create_default_map()

      {:ok, fragment} =
        Maps.create_fragment(%{
          name: "Auth Pattern",
          data: %{
            "nodes" => [
              %{
                "temp_id" => "t0",
                "text" => "User",
                "x_pct" => 0.0,
                "y_pct" => 0.0,
                "metadata" => %{}
              },
              %{
                "temp_id" => "t1",
                "text" => "Identity Provider",
                "x_pct" => 30.0,
                "y_pct" => 20.0,
                "metadata" => %{"category" => "security"}
              }
            ],
            "edges" => [
              %{
                "source_temp_id" => "t0",
                "target_temp_id" => "t1",
                "metadata" => %{}
              }
            ]
          }
        })

      %{map: map, fragment: fragment}
    end

    test "invoke creates real nodes and edges on the target map", ctx do
      conn = build_conn()

      invoke_conn =
        post(conn, ~p"/api/fragments/#{ctx.fragment.id}/invoke", %{
          "map_id" => ctx.map.id,
          "x_pct" => 10.0,
          "y_pct" => 10.0
        })

      result = json_response(invoke_conn, 200)
      assert length(result["nodes"]) == 2
      assert length(result["edges"]) == 1

      # Verify positions are offset
      user = Enum.find(result["nodes"], &(&1["text"] == "User"))
      idp = Enum.find(result["nodes"], &(&1["text"] == "Identity Provider"))

      assert user["x_pct"] == 10.0
      assert user["y_pct"] == 10.0
      assert idp["x_pct"] == 40.0
      assert idp["y_pct"] == 30.0
    end

    test "invoked nodes appear in the map's node list", ctx do
      conn = build_conn()

      post(conn, ~p"/api/fragments/#{ctx.fragment.id}/invoke", %{
        "map_id" => ctx.map.id,
        "x_pct" => 10.0,
        "y_pct" => 10.0
      })

      # Fetch the map — should include the fragment's nodes
      map_conn = get(conn, ~p"/api/maps/#{ctx.map.id}")
      map_data = json_response(map_conn, 200)

      texts = Enum.map(map_data["nodes"], & &1["text"])
      assert "User" in texts
      assert "Identity Provider" in texts
    end

    test "fragment can be invoked multiple times at different positions", ctx do
      conn = build_conn()

      post(conn, ~p"/api/fragments/#{ctx.fragment.id}/invoke", %{
        "map_id" => ctx.map.id,
        "x_pct" => 10.0,
        "y_pct" => 10.0
      })

      post(conn, ~p"/api/fragments/#{ctx.fragment.id}/invoke", %{
        "map_id" => ctx.map.id,
        "x_pct" => 50.0,
        "y_pct" => 50.0
      })

      map_conn = get(conn, ~p"/api/maps/#{ctx.map.id}")
      map_data = json_response(map_conn, 200)

      # Should have 4 nodes (2 per invocation)
      assert length(map_data["nodes"]) == 4
      assert length(map_data["edges"]) == 2
    end

    test "invoked nodes are independent — editing one doesn't affect the fragment", ctx do
      conn = build_conn()

      invoke_conn =
        post(conn, ~p"/api/fragments/#{ctx.fragment.id}/invoke", %{
          "map_id" => ctx.map.id,
          "x_pct" => 10.0,
          "y_pct" => 10.0
        })

      result = json_response(invoke_conn, 200)
      user = Enum.find(result["nodes"], &(&1["text"] == "User"))

      # Rename the invoked node
      patch(conn, ~p"/api/nodes/#{user["id"]}", %{"text" => "End User"})

      # Fragment data should be unchanged
      fragment_conn = get(conn, ~p"/api/fragments/#{ctx.fragment.id}")
      fragment = json_response(fragment_conn, 200)
      fragment_texts = Enum.map(fragment["data"]["nodes"], & &1["text"])
      assert "User" in fragment_texts
      refute "End User" in fragment_texts
    end
  end

  describe "fragment lifecycle" do
    test "create with raw data, list, show, delete", %{conn: conn} do
      # Create directly with data (not from nodes)
      create_conn =
        post(conn, ~p"/api/fragments", %{
          "name" => "Simple Pattern",
          "description" => "A test pattern",
          "data" => %{
            "nodes" => [
              %{"temp_id" => "t0", "text" => "A", "x_pct" => 0.0, "y_pct" => 0.0}
            ],
            "edges" => []
          }
        })

      fragment = json_response(create_conn, 201)
      assert fragment["name"] == "Simple Pattern"
      assert fragment["description"] == "A test pattern"

      # Show
      show_conn = get(conn, ~p"/api/fragments/#{fragment["id"]}")
      assert json_response(show_conn, 200)["name"] == "Simple Pattern"

      # Delete
      delete_conn = delete(conn, ~p"/api/fragments/#{fragment["id"]}")
      assert response(delete_conn, 204)

      # Verify gone
      list_conn = get(conn, ~p"/api/fragments")
      assert json_response(list_conn, 200)["fragments"] == []
    end

    test "create with invalid data returns errors", %{conn: conn} do
      conn = post(conn, ~p"/api/fragments", %{"name" => "Bad", "data" => %{}})
      response = json_response(conn, 422)

      assert response["errors"]["data"]
    end

    test "create with no matching nodes returns error", %{conn: conn} do
      map = Maps.get_or_create_default_map()

      conn =
        post(conn, ~p"/api/fragments", %{
          "name" => "Empty",
          "node_ids" => [999_999],
          "map_id" => map.id
        })

      response = json_response(conn, 422)
      assert response["errors"]["nodes"]
    end
  end
end
