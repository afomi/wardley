defmodule Wardley.StackMap.Fingerprint do
  @moduledoc """
  Computes a structural fingerprint from a parsed StackMap result.

  A fingerprint is a stable, comparable vector that describes the shape
  of a dependency graph — layer distribution, depth, breadth, connectivity,
  and keystone packages. Two codebases with the same architectural shape
  will have similar fingerprints regardless of exact package versions.

  ## Usage

      parsed = StackMap.parse("/path/to/project")
      fp = Fingerprint.compute(parsed)

      fp2 = StackMap.parse("/path/to/other") |> Fingerprint.compute()
      score = Fingerprint.similarity(fp, fp2)   # 0.0–1.0

  ## Fingerprint fields

    - `:ecosystem`       — "elixir" | "npm" | "ruby" | "unknown"
    - `:breadth`         — total node count (incl. root)
    - `:depth`           — number of distinct y-bands occupied
    - `:layers`          — map of layer → fraction of total nodes (0.0–1.0)
    - `:edge_count`      — total edge count
    - `:fan_out`         — mean direct-dep count per node (avg out-degree)
    - `:layer_crossing`  — fraction of edges that cross y-bands (vs same-layer)
    - `:keystones`       — sorted list of direct-dep package names
    - `:layer_vector`    — ordered float list for cosine similarity
  """

  alias Wardley.StackMap.LayerSchema

  @doc """
  Compute a fingerprint map from a `%{nodes: [...], edges: [...]}` result.
  """
  def compute(%{nodes: nodes, edges: edges}) do
    total = length(nodes)
    ecosystem = detect_ecosystem(nodes)

    layer_counts =
      Enum.reduce(nodes, %{}, fn node, acc ->
        layer = node.metadata[:layer] || node.metadata["layer"] || "unknown"
        Map.update(acc, layer, 1, &(&1 + 1))
      end)

    layer_fractions =
      Map.new(layer_counts, fn {layer, count} ->
        {layer, Float.round(count / max(total, 1), 4)}
      end)

    # Depth: number of distinct non-unknown layers occupied
    depth =
      layer_counts
      |> Map.keys()
      |> Enum.reject(&(&1 == "unknown"))
      |> length()

    keystones =
      nodes
      |> Enum.filter(fn n -> n.metadata[:direct] || n.metadata["direct"] end)
      |> Enum.reject(fn n -> n.metadata[:root] || n.metadata["root"] end)
      |> Enum.map(& &1.text)
      |> Enum.sort()

    fan_out = compute_fan_out(nodes, edges)
    layer_crossing = compute_layer_crossing(nodes, edges)

    # Vector uses canonical schema order — consistent across all ecosystems
    layer_vector =
      Enum.map(LayerSchema.vector_layers(), fn layer ->
        Map.get(layer_fractions, layer, 0.0)
      end)

    %{
      schema_version: LayerSchema.version(),
      ecosystem: ecosystem,
      breadth: total,
      depth: depth,
      layers: layer_fractions,
      edge_count: length(edges),
      fan_out: fan_out,
      layer_crossing: layer_crossing,
      keystones: keystones,
      layer_vector: layer_vector
    }
  end

  @doc """
  Cosine similarity between two fingerprints. Returns 0.0–1.0.

  Uses the layer_vector (layer histogram) as the primary signal.
  Penalizes ecosystem mismatch slightly.
  Raises if schema versions differ — recompute stale fingerprints first.
  """
  def similarity(fp_a, fp_b) do
    if Map.get(fp_a, :schema_version) != Map.get(fp_b, :schema_version) and
         Map.has_key?(fp_a, :schema_version) and Map.has_key?(fp_b, :schema_version) do
      raise "Schema version mismatch: #{fp_a.schema_version} vs #{fp_b.schema_version}. Recompute fingerprints."
    end

    cosine = cosine_similarity(fp_a.layer_vector, fp_b.layer_vector)
    ecosystem_factor = if fp_a.ecosystem == fp_b.ecosystem, do: 1.0, else: 0.7
    Float.round(cosine * ecosystem_factor, 4)
  end

  @doc """
  Compare a fingerprint against a list of named fingerprints.
  Returns list of {name, score} sorted descending.
  """
  def rank(fingerprint, named_fingerprints) do
    named_fingerprints
    |> Enum.map(fn {name, fp} -> {name, similarity(fingerprint, fp)} end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
  end

  @doc """
  Summarise the difference between two fingerprints.
  Returns a map of layer → delta (positive = more in b, negative = more in a).
  """
  def diff(%{layers: la}, %{layers: lb}) do
    all_layers = (Map.keys(la) ++ Map.keys(lb)) |> Enum.uniq()

    Map.new(all_layers, fn layer ->
      a = Map.get(la, layer, 0.0)
      b = Map.get(lb, layer, 0.0)
      {layer, Float.round(b - a, 4)}
    end)
    |> Enum.reject(fn {_, delta} -> delta == 0.0 end)
    |> Enum.sort_by(fn {_, delta} -> abs(delta) end, :desc)
    |> Map.new()
  end

  # ── Private ────────────────────────────────────────────────────────────────

  defp detect_ecosystem(nodes) do
    nodes
    |> Enum.map(fn n -> n.metadata[:ecosystem] || n.metadata["ecosystem"] end)
    |> Enum.reject(&is_nil/1)
    |> List.first() || "unknown"
  end

  # Average out-degree: edges leaving each non-root node
  defp compute_fan_out(nodes, edges) do
    non_root = nodes |> Enum.reject(fn n -> n.metadata[:root] || n.metadata["root"] end)

    if non_root == [],
      do: 0.0,
      else: Float.round(length(edges) / length(non_root), 2)
  end

  # Fraction of edges where source and target are in different layers
  defp compute_layer_crossing(nodes, edges) do
    node_layer =
      Map.new(nodes, fn n ->
        {n.text, n.metadata[:layer] || n.metadata["layer"] || "unknown"}
      end)

    crossing =
      Enum.count(edges, fn e ->
        Map.get(node_layer, e.source_label) != Map.get(node_layer, e.target_label)
      end)

    if edges == [], do: 0.0, else: Float.round(crossing / length(edges), 4)
  end

  defp cosine_similarity(va, vb) do
    dot = Enum.zip(va, vb) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
    mag_a = va |> Enum.reduce(0.0, fn x, acc -> acc + x * x end) |> :math.sqrt()
    mag_b = vb |> Enum.reduce(0.0, fn x, acc -> acc + x * x end) |> :math.sqrt()

    if mag_a == 0.0 or mag_b == 0.0 do
      0.0
    else
      Float.round(dot / (mag_a * mag_b), 6)
    end
  end
end
