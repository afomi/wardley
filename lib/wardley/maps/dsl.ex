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
      render_edges(edges, node_index),
      render_evolutions(nodes)
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 == :skip))
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

  defp render_evolutions(nodes) do
    lines =
      Enum.flat_map(nodes, fn n ->
        case evolve_x(n) do
          nil -> []
          evo -> ["evolve #{n.text} #{format_coord(Float.round(evo / 100, 2))}"]
        end
      end)

    case lines do
      [] -> :skip
      lines -> ["" | lines]
    end
  end

  # Target evolution as a percentage (0–100), or nil if the node isn't evolving.
  defp evolve_x(node) do
    case node.metadata do
      %{"evolve_x" => v} when is_number(v) -> v
      %{"evolve_x" => v} when is_binary(v) -> parse_number(v)
      _ -> nil
    end
  end

  defp parse_number(str) do
    case Float.parse(str) do
      {f, _} -> f
      :error -> nil
    end
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
