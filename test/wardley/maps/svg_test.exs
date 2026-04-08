defmodule Wardley.Maps.SvgTest do
  use Wardley.DataCase, async: true

  alias Wardley.Maps
  alias Wardley.Maps.Svg

  setup do
    map = Maps.get_or_create_default_map()
    {:ok, map: map}
  end

  test "renders empty map as valid SVG", %{map: map} do
    svg = Svg.render(map, [], [])

    assert svg =~ "<svg"
    assert svg =~ "</svg>"
    assert svg =~ "Evolution"
    assert svg =~ "Visible"
    assert svg =~ "Genesis"
    assert svg =~ "Commodity"
  end

  test "renders nodes as circles with labels", %{map: map} do
    {:ok, _n} = Maps.create_node(%{map_id: map.id, text: "Platform", x_pct: 60.0, y_pct: 50.0})
    nodes = Maps.list_nodes(map.id)

    svg = Svg.render(map, nodes, [])

    assert svg =~ "Platform"
    assert svg =~ "<circle"
    assert svg =~ ~s(r="6")
  end

  test "renders edges as lines", %{map: map} do
    {:ok, n1} = Maps.create_node(%{map_id: map.id, text: "User", x_pct: 50.0, y_pct: 10.0})
    {:ok, n2} = Maps.create_node(%{map_id: map.id, text: "API", x_pct: 50.0, y_pct: 40.0})
    {:ok, _e} = Maps.create_edge(%{map_id: map.id, source_id: n1.id, target_id: n2.id})

    nodes = Maps.list_nodes(map.id)
    edges = Maps.list_edges(map.id)

    svg = Svg.render(map, nodes, edges)

    assert svg =~ "<line"
    assert svg =~ "edge-line"
  end

  test "escapes special characters in node text", %{map: map} do
    {:ok, _n} =
      Maps.create_node(%{map_id: map.id, text: "A <b>&</b> B", x_pct: 50.0, y_pct: 50.0})

    nodes = Maps.list_nodes(map.id)
    svg = Svg.render(map, nodes, [])

    assert svg =~ "A &lt;b&gt;&amp;&lt;/b&gt; B"
    refute svg =~ "A <b>"
  end

  test "includes map title", %{map: map} do
    svg = Svg.render(map, [], [])

    assert svg =~ "<title>#{map.name}</title>"
  end
end
