defmodule Wardley.Maps.DslTest do
  use Wardley.DataCase, async: true

  alias Wardley.Maps
  alias Wardley.Maps.Dsl

  setup do
    map = Maps.get_or_create_default_map()
    {:ok, map: map}
  end

  test "renders empty map with title", %{map: map} do
    dsl = Dsl.render(map, [], [])

    assert dsl =~ "title #{map.name}"
  end

  test "renders anchor nodes with anchor keyword", %{map: map} do
    {:ok, _n} =
      Maps.create_node(%{
        map_id: map.id,
        text: "Customer",
        x_pct: 65.0,
        y_pct: 5.0,
        metadata: %{"type" => "anchor"}
      })

    nodes = Maps.list_nodes(map.id)
    dsl = Dsl.render(map, nodes, [])

    assert dsl =~ "anchor Customer [0.95, 0.65]"
  end

  test "renders regular nodes with component keyword", %{map: map} do
    {:ok, _n} =
      Maps.create_node(%{
        map_id: map.id,
        text: "Platform",
        x_pct: 60.0,
        y_pct: 50.0
      })

    nodes = Maps.list_nodes(map.id)
    dsl = Dsl.render(map, nodes, [])

    assert dsl =~ "component Platform [0.50, 0.60]"
  end

  test "renders edges as arrows", %{map: map} do
    {:ok, n1} =
      Maps.create_node(%{map_id: map.id, text: "User", x_pct: 50.0, y_pct: 10.0})

    {:ok, n2} =
      Maps.create_node(%{map_id: map.id, text: "API", x_pct: 50.0, y_pct: 40.0})

    {:ok, _e} =
      Maps.create_edge(%{map_id: map.id, source_id: n1.id, target_id: n2.id})

    nodes = Maps.list_nodes(map.id)
    edges = Maps.list_edges(map.id)
    dsl = Dsl.render(map, nodes, edges)

    assert dsl =~ "User->API"
  end

  test "treats user type as anchor", %{map: map} do
    {:ok, _n} =
      Maps.create_node(%{
        map_id: map.id,
        text: "Resident",
        x_pct: 90.0,
        y_pct: 2.0,
        metadata: %{"type" => "user"}
      })

    nodes = Maps.list_nodes(map.id)
    dsl = Dsl.render(map, nodes, [])

    assert dsl =~ "anchor Resident"
  end
end
