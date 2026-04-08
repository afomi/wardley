defmodule Wardley.FragmentTest do
  use Wardley.DataCase, async: true

  alias Wardley.Maps

  describe "fragment CRUD" do
    test "create_fragment with valid data" do
      {:ok, fragment} =
        Maps.create_fragment(%{
          name: "Auth Pattern",
          description: "Common authentication flow",
          data: %{
            "nodes" => [
              %{"temp_id" => "t0", "text" => "User", "x_pct" => 0.0, "y_pct" => 0.0},
              %{"temp_id" => "t1", "text" => "Auth", "x_pct" => 10.0, "y_pct" => 20.0}
            ],
            "edges" => [
              %{"source_temp_id" => "t0", "target_temp_id" => "t1"}
            ]
          }
        })

      assert fragment.name == "Auth Pattern"
      assert fragment.description == "Common authentication flow"
      assert length(fragment.data["nodes"]) == 2
    end

    test "create_fragment requires name" do
      {:error, changeset} = Maps.create_fragment(%{data: %{"nodes" => []}})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_fragment requires nodes list in data" do
      {:error, changeset} = Maps.create_fragment(%{name: "Bad", data: %{}})

      assert %{data: ["must contain a nodes list"]} = errors_on(changeset)
    end

    test "list_fragments returns all fragments" do
      Maps.create_fragment(%{name: "A", data: %{"nodes" => []}})
      Maps.create_fragment(%{name: "B", data: %{"nodes" => []}})

      assert length(Maps.list_fragments()) == 2
    end

    test "delete_fragment removes it" do
      {:ok, fragment} = Maps.create_fragment(%{name: "Temp", data: %{"nodes" => []}})

      {:ok, _} = Maps.delete_fragment(fragment)

      assert Maps.list_fragments() == []
    end
  end

  describe "create_fragment_from_nodes/4" do
    setup do
      map = Maps.get_or_create_default_map()

      {:ok, n1} =
        Maps.create_node(%{map_id: map.id, text: "Customer", x_pct: 20.0, y_pct: 80.0})

      {:ok, n2} =
        Maps.create_node(%{map_id: map.id, text: "CRM", x_pct: 50.0, y_pct: 60.0})

      {:ok, n3} =
        Maps.create_node(%{map_id: map.id, text: "Database", x_pct: 70.0, y_pct: 30.0})

      {:ok, e1} =
        Maps.create_edge(%{map_id: map.id, source_id: n1.id, target_id: n2.id})

      {:ok, e2} =
        Maps.create_edge(%{map_id: map.id, source_id: n2.id, target_id: n3.id})

      %{map: map, n1: n1, n2: n2, n3: n3, e1: e1, e2: e2}
    end

    test "creates fragment from selected nodes with relative positions", ctx do
      {:ok, fragment} =
        Maps.create_fragment_from_nodes("CRM Pattern", [ctx.n1.id, ctx.n2.id], ctx.map.id)

      nodes = fragment.data["nodes"]
      assert length(nodes) == 2

      # Positions should be relative to the bounding box origin (min_x=20, min_y=60)
      customer = Enum.find(nodes, &(&1["text"] == "Customer"))
      crm = Enum.find(nodes, &(&1["text"] == "CRM"))

      assert customer["x_pct"] == 0.0
      assert customer["y_pct"] == 20.0
      assert crm["x_pct"] == 30.0
      assert crm["y_pct"] == 0.0
    end

    test "includes edges connecting selected nodes", ctx do
      {:ok, fragment} =
        Maps.create_fragment_from_nodes(
          "Full Chain",
          [ctx.n1.id, ctx.n2.id, ctx.n3.id],
          ctx.map.id
        )

      edges = fragment.data["edges"]
      assert length(edges) == 2
    end

    test "excludes edges where one endpoint is not selected", ctx do
      {:ok, fragment} =
        Maps.create_fragment_from_nodes("Partial", [ctx.n1.id, ctx.n2.id], ctx.map.id)

      # Only the n1->n2 edge should be included, not n2->n3
      edges = fragment.data["edges"]
      assert length(edges) == 1
    end

    test "returns error when no nodes match", ctx do
      assert {:error, :no_nodes} =
               Maps.create_fragment_from_nodes("Empty", [999_999], ctx.map.id)
    end
  end

  describe "invoke_fragment/4" do
    setup do
      map = Maps.get_or_create_default_map()

      {:ok, fragment} =
        Maps.create_fragment(%{
          name: "Auth Fragment",
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
                "text" => "Auth Service",
                "x_pct" => 20.0,
                "y_pct" => 30.0,
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

    test "creates real nodes and edges at the target position", ctx do
      {:ok, result} = Maps.invoke_fragment(ctx.fragment.id, ctx.map.id, 10.0, 10.0)

      assert length(result.nodes) == 2
      assert length(result.edges) == 1

      user = Enum.find(result.nodes, &(&1.text == "User"))
      auth = Enum.find(result.nodes, &(&1.text == "Auth Service"))

      # Positions should be offset from (10, 10)
      assert user.x_pct == 10.0
      assert user.y_pct == 10.0
      assert auth.x_pct == 30.0
      assert auth.y_pct == 40.0
    end

    test "preserves metadata from fragment", ctx do
      {:ok, result} = Maps.invoke_fragment(ctx.fragment.id, ctx.map.id, 0.0, 0.0)

      auth = Enum.find(result.nodes, &(&1.text == "Auth Service"))
      assert auth.metadata["category"] == "security"
    end

    test "edges reference the newly created nodes", ctx do
      {:ok, result} = Maps.invoke_fragment(ctx.fragment.id, ctx.map.id, 0.0, 0.0)

      edge = hd(result.edges)
      node_ids = Enum.map(result.nodes, & &1.id)

      assert edge.source_id in node_ids
      assert edge.target_id in node_ids
    end

    test "clamps positions to 0-100 range", ctx do
      {:ok, result} = Maps.invoke_fragment(ctx.fragment.id, ctx.map.id, 90.0, 85.0)

      auth = Enum.find(result.nodes, &(&1.text == "Auth Service"))
      # 90 + 20 = 110, clamped to 100
      assert auth.x_pct == 100.0
      # 85 + 30 = 115, clamped to 100
      assert auth.y_pct == 100.0
    end
  end
end
