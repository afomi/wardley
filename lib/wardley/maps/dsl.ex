defmodule Wardley.Maps.Dsl do
  @moduledoc """
  Renders a Wardley map in the OWM (Online Wardley Maps) DSL format.

  Produces a compact, human-readable text representation that is also
  compatible with onlinewardleymaps.com.
  """

  def render(map, nodes, edges) do
    node_index = Map.new(nodes, fn n -> {n.id, n} end)

    [
      "title #{map.name}",
      "",
      render_nodes(nodes),
      "",
      render_edges(edges, node_index)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp render_nodes(nodes) do
    Enum.map(nodes, fn n ->
      vis = Float.round((100 - n.y_pct) / 100, 2)
      evo = Float.round(n.x_pct / 100, 2)
      keyword = if anchor?(n), do: "anchor", else: "component"
      "#{keyword} #{n.text} [#{format_coord(vis)}, #{format_coord(evo)}]"
    end)
  end

  defp render_edges(edges, node_index) do
    Enum.flat_map(edges, fn e ->
      with %{} = source <- node_index[e.source_id],
           %{} = target <- node_index[e.target_id] do
        ["#{source.text}->#{target.text}"]
      else
        _ -> []
      end
    end)
  end

  defp anchor?(node) do
    case node.metadata do
      %{"type" => "anchor"} -> true
      %{"type" => "user"} -> true
      _ -> false
    end
  end

  defp format_coord(val) do
    :erlang.float_to_binary(val * 1.0, decimals: 2)
  end
end
