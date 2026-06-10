defmodule Mix.Tasks.Wardley.StackMap do
  use Mix.Task

  @shortdoc "Parse a project's mix.exs and print (or seed) a Wardley stack map"

  @moduledoc """
  Parse a project directory's mix.exs + mix.lock and output the resulting
  Wardley map nodes and edges.

  ## Usage

      mix wardley.stack_map [PATH] [--seed MAP_ID]

  PATH defaults to the current directory.

  With --seed MAP_ID, nodes and edges are inserted into the given map.
  Without --seed, the parsed graph is printed to stdout.

  ## Examples

      mix wardley.stack_map
      mix wardley.stack_map /path/to/other/project
      mix wardley.stack_map --seed 1
  """

  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, strict: [seed: :integer])
    path = List.first(positional) || "."

    result = Wardley.StackMap.parse(path)

    case Keyword.get(opts, :seed) do
      nil ->
        print_result(result)

      map_id ->
        Mix.Task.run("app.start")
        seed_result(result, map_id)
    end
  end

  defp print_result(%{nodes: nodes, edges: edges}) do
    IO.puts("Nodes (#{length(nodes)}) — sorted by visibility:")

    nodes
    |> Enum.sort_by(& &1.y_pct, :desc)
    |> Enum.each(fn n ->
      layer = n.metadata[:layer] || n.metadata["layer"] || "?"
      version = n.metadata[:version] || n.metadata["version"] || ""
      direct = if n.metadata[:direct] || n.metadata["direct"], do: " *", else: ""

      IO.puts(
        "  [y=#{round(n.y_pct)} x=#{round(n.x_pct)}] #{n.text} #{version} (#{layer})#{direct}"
      )
    end)

    IO.puts("\nEdges (#{length(edges)}):")

    edges
    |> Enum.take(20)
    |> Enum.each(fn e ->
      IO.puts("  #{e.source_label} → #{e.target_label}")
    end)

    if length(edges) > 20 do
      IO.puts("  ... and #{length(edges) - 20} more")
    end
  end

  defp seed_result(%{nodes: nodes, edges: edges}, map_id) do
    alias Wardley.Maps

    IO.puts("Seeding into map #{map_id}...")

    # Create nodes, track text → id mapping
    label_to_id =
      Enum.reduce(nodes, %{}, fn node_attrs, acc ->
        attrs = Map.put(node_attrs, :map_id, map_id)

        case Maps.create_node(attrs) do
          {:ok, node} ->
            IO.puts("  + node: #{node.text}")
            Map.put(acc, node.text, node.id)

          {:error, changeset} ->
            IO.puts("  ! failed node #{node_attrs.text}: #{inspect(changeset.errors)}")
            acc
        end
      end)

    # Create edges using resolved IDs
    Enum.each(edges, fn %{source_label: src, target_label: tgt} ->
      with source_id when not is_nil(source_id) <- Map.get(label_to_id, src),
           target_id when not is_nil(target_id) <- Map.get(label_to_id, tgt) do
        Maps.create_edge(%{map_id: map_id, source_id: source_id, target_id: target_id})
      end
    end)

    IO.puts("Done. #{map_count(label_to_id)} nodes, #{length(edges)} edges attempted.")
  end

  defp map_count(m), do: map_size(m)
end
