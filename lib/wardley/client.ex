defmodule Wardley.Client do
  @moduledoc """
  HTTP client for the wardley.app REST API.

  Wraps the JSON API with bearer token auth from WARDLEY_API_TOKEN.
  Designed for use from scripts, Mix tasks, and other Elixir projects.

  ## Usage

      # List maps
      Wardley.Client.list_maps()

      # Get a map with nodes and edges
      Wardley.Client.get_map(7)

      # Get compact DSL
      Wardley.Client.get_dsl(7)

      # Create a node
      Wardley.Client.create_node(7, "Customer", x_pct: 75, y_pct: 5)

      # Connect two nodes (source depends on target)
      Wardley.Client.connect(source_id, target_id)

      # Move a node
      Wardley.Client.move_node(node_id, x_pct: 60, y_pct: 20)

      # Delete a node
      Wardley.Client.delete_node(node_id)

  ## Configuration

  Set `WARDLEY_API_TOKEN` for authenticated access.
  Set `WARDLEY_API_URL` to override the default `http://localhost:4000`.
  """

  @default_url "https://wardley.app"

  # --- Maps ---

  def list_maps do
    get("/api/maps")
  end

  def get_map(map_id) do
    get("/api/maps/#{map_id}")
  end

  def get_active_map do
    get("/api/map")
  end

  def get_dsl(map_id) do
    get_text("/api/maps/#{map_id}/dsl")
  end

  def get_svg(map_id) do
    get_text("/api/maps/#{map_id}/svg")
  end

  def create_map(name) do
    post("/api/maps", %{name: name})
  end

  def update_map(map_id, attrs) do
    patch("/api/maps/#{map_id}", Map.new(attrs))
  end

  def delete_map(map_id) do
    delete("/api/maps/#{map_id}")
  end

  # --- Nodes ---

  def create_node(map_id, text, opts \\ []) do
    body = %{
      map_id: map_id,
      text: text,
      x_pct: Keyword.get(opts, :x_pct, 50),
      y_pct: Keyword.get(opts, :y_pct, 50)
    }

    body =
      case Keyword.get(opts, :metadata) do
        nil -> body
        meta -> Map.put(body, :metadata, meta)
      end

    post("/api/nodes", body)
  end

  def update_node(node_id, attrs) do
    patch("/api/nodes/#{node_id}", Map.new(attrs))
  end

  def move_node(node_id, opts) do
    attrs =
      opts
      |> Keyword.take([:x_pct, :y_pct])
      |> Map.new()

    patch("/api/nodes/#{node_id}", attrs)
  end

  def delete_node(node_id) do
    delete("/api/nodes/#{node_id}")
  end

  # --- Edges ---

  def connect(source_id, target_id, opts \\ []) do
    body = %{source_id: source_id, target_id: target_id}

    body =
      case Keyword.get(opts, :metadata) do
        nil -> body
        meta -> Map.put(body, :metadata, meta)
      end

    post("/api/edges", body)
  end

  def update_edge(edge_id, attrs) do
    patch("/api/edges/#{edge_id}", Map.new(attrs))
  end

  def delete_edge(edge_id) do
    delete("/api/edges/#{edge_id}")
  end

  # --- Search ---

  def search(query) do
    get("/api/search?q=#{URI.encode_www_form(query)}")
  end

  # --- HTTP helpers ---

  defp get(path) do
    url = base_url() <> path

    Req.get!(url, headers: auth_headers()).body
  end

  defp get_text(path) do
    url = base_url() <> path

    Req.get!(url, headers: auth_headers()).body
  end

  defp post(path, body) do
    url = base_url() <> path

    Req.post!(url, json: body, headers: auth_headers()).body
  end

  defp patch(path, body) do
    url = base_url() <> path

    Req.patch!(url, json: body, headers: auth_headers()).body
  end

  defp delete(path) do
    url = base_url() <> path

    Req.delete!(url, headers: auth_headers()).body
  end

  defp base_url do
    System.get_env("WARDLEY_API_URL") || @default_url
  end

  defp auth_headers do
    case System.get_env("WARDLEY_API_TOKEN") do
      nil -> []
      token -> [{"authorization", "Bearer #{token}"}]
    end
  end
end
