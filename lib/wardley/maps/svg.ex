defmodule Wardley.Maps.Svg do
  @moduledoc """
  Renders a Wardley map as SVG.

  Produces a self-contained SVG with the evolution axis (Genesis → Commodity),
  value chain axis (Visible → Invisible), nodes as labeled circles,
  and edges as lines between them.
  """

  @width 800
  @height 600
  @padding_top 40
  @padding_bottom 50
  @padding_left 80
  @padding_right 20
  @node_radius 6

  @evolution_labels [
    {0, "Genesis"},
    {25, "Custom"},
    {50, "Product"},
    {75, "Commodity"}
  ]

  def render(map, nodes, edges) do
    node_index = Map.new(nodes, fn n -> {n.id, n} end)

    [
      svg_open(map.name),
      render_axes(),
      render_edges(edges, node_index),
      render_nodes(nodes),
      svg_close()
    ]
    |> IO.iodata_to_binary()
  end

  defp svg_open(title) do
    """
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 #{@width} #{@height}"
      width="#{@width}"
      height="#{@height}"
      font-family="system-ui, sans-serif"
      font-size="12">
      <title>#{escape(title)}</title>
      <style>
        .axis-line { stroke: #ccc; stroke-width: 1; }
        .axis-label { fill: #999; font-size: 11px; }
        .axis-title { fill: #666; font-size: 13px; font-weight: 600; }
        .evolution-zone { fill: #f8f8f8; }
        .evolution-zone:nth-child(even) { fill: #f0f0f0; }
        .node-circle { fill: #1a1a2e; stroke: #fff; stroke-width: 1.5; }
        .node-label { fill: #1a1a2e; font-size: 11px; }
        .edge-line { stroke: #999; stroke-width: 1; }
      </style>
    """
  end

  defp svg_close, do: "</svg>"

  defp render_axes do
    plot_w = @width - @padding_left - @padding_right
    zone_w = plot_w / 4

    zones =
      Enum.map(0..3, fn i ->
        x = @padding_left + i * zone_w

        """
        <rect
          class="evolution-zone"
          x="#{x}"
          y="#{@padding_top}"
          width="#{zone_w}"
          height="#{@height - @padding_top - @padding_bottom}"
          opacity="0.5" />
        """
      end)

    evolution_labels =
      Enum.map(@evolution_labels, fn {pct, label} ->
        x = pct_to_x(pct)

        """
        <text
          class="axis-label"
          x="#{x}"
          y="#{@height - 15}"
          text-anchor="middle">#{label}</text>
        """
      end)

    value_chain_labels =
      [
        """
        <text
          class="axis-title"
          x="15"
          y="#{@padding_top + 20}"
          text-anchor="start"
          transform="rotate(-90, 15, #{@padding_top + 20})">Visible</text>
        """,
        """
        <text
          class="axis-title"
          x="15"
          y="#{@height - @padding_bottom - 10}"
          text-anchor="end"
          transform="rotate(-90, 15, #{@height - @padding_bottom - 10})">Invisible</text>
        """
      ]

    evolution_title =
      """
      <text
        class="axis-title"
        x="#{@padding_left + plot_w / 2}"
        y="#{@height - 2}"
        text-anchor="middle">Evolution</text>
      """

    border =
      """
      <rect
        x="#{@padding_left}"
        y="#{@padding_top}"
        width="#{plot_w}"
        height="#{@height - @padding_top - @padding_bottom}"
        fill="none"
        stroke="#ccc"
        stroke-width="1" />
      """

    [zones, evolution_labels, value_chain_labels, evolution_title, border]
  end

  defp render_nodes(nodes) do
    Enum.map(nodes, fn n ->
      x = pct_to_x(n.x_pct)
      y = pct_to_y(n.y_pct)

      """
      <circle
        class="node-circle"
        cx="#{x}"
        cy="#{y}"
        r="#{@node_radius}" />
      <text
        class="node-label"
        x="#{x + @node_radius + 4}"
        y="#{y + 4}">#{escape(n.text)}</text>
      """
    end)
  end

  defp render_edges(edges, node_index) do
    Enum.map(edges, fn e ->
      with %{} = source <- node_index[e.source_id],
           %{} = target <- node_index[e.target_id] do
        x1 = pct_to_x(source.x_pct)
        y1 = pct_to_y(source.y_pct)
        x2 = pct_to_x(target.x_pct)
        y2 = pct_to_y(target.y_pct)

        """
        <line
          class="edge-line"
          x1="#{x1}"
          y1="#{y1}"
          x2="#{x2}"
          y2="#{y2}" />
        """
      else
        _ -> ""
      end
    end)
  end

  defp pct_to_x(pct) do
    plot_w = @width - @padding_left - @padding_right
    @padding_left + pct / 100.0 * plot_w
  end

  defp pct_to_y(pct) do
    plot_h = @height - @padding_top - @padding_bottom
    @padding_top + pct / 100.0 * plot_h
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
