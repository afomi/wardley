defmodule WardleyWeb.DevelopersController do
  use WardleyWeb, :controller

  @route_docs %{
    {"GET", "/api/me"} =>
      {"Token identity", "Validates a bearer token and returns user/token metadata."},
    {"GET", "/api/map"} =>
      {"Active map", "Returns the active/default map loaded by the browser editor."},
    {"GET", "/api/maps"} => {"List maps", "Returns available maps."},
    {"POST", "/api/maps"} => {"Create map", "Creates a new map."},
    {"GET", "/api/maps/:id"} => {"Show map", "Returns one map with nodes and edges."},
    {"PATCH", "/api/maps/:id"} => {"Update map", "Renames a map."},
    {"DELETE", "/api/maps/:id"} => {"Delete map", "Deletes a map and its nodes and edges."},
    {"GET", "/api/maps/:id/dsl"} => {"Map DSL", "Returns compact OWM-style DSL for reasoning."},
    {"GET", "/api/maps/:id/svg"} => {"Map SVG", "Returns a rendered SVG of the map."},
    {"POST", "/api/nodes"} =>
      {"Create node", "Creates a component on the active or specified map."},
    {"PATCH", "/api/nodes/:id"} =>
      {"Update node", "Updates node text, position, metadata, or related fields."},
    {"DELETE", "/api/nodes/:id"} => {"Delete node", "Deletes a node and its dependent edges."},
    {"POST", "/api/edges"} => {"Create edge", "Creates a dependency edge between two nodes."},
    {"PATCH", "/api/edges/:id"} => {"Update edge", "Updates edge metadata."},
    {"DELETE", "/api/edges/:id"} => {"Delete edge", "Deletes an edge."},
    {"GET", "/api/fragments"} => {"List fragments", "Lists reusable map fragments."},
    {"GET", "/api/fragments/:id"} => {"Show fragment", "Returns one reusable fragment."},
    {"POST", "/api/fragments"} => {"Create fragment", "Creates a reusable fragment."},
    {"DELETE", "/api/fragments/:id"} => {"Delete fragment", "Deletes a reusable fragment."},
    {"POST", "/api/fragments/:id/invoke"} =>
      {"Invoke fragment", "Applies a reusable fragment to a map."},
    {"GET", "/api/suggestions"} => {"Suggestions", "Returns component-name suggestions."},
    {"GET", "/api/search"} => {"Search", "Searches maps, nodes, and personas."},
    {"GET", "/api/categories"} => {"Categories", "Lists known node categories."},
    {"GET", "/api/categories/:category"} =>
      {"Category nodes", "Returns aggregate data for one category."},
    {"GET", "/api/tags"} => {"Tags", "Lists known tags."},
    {"GET", "/api/tags/:tag"} => {"Tag nodes", "Returns nodes for one tag."},
    {"GET", "/api/personas"} => {"List personas", "Returns personas, with default first."},
    {"GET", "/api/personas/:id"} => {"Show persona", "Returns one persona."},
    {"POST", "/api/personas"} => {"Create persona", "Creates a persona."},
    {"PATCH", "/api/personas/:id"} => {"Update persona", "Updates a persona."},
    {"DELETE", "/api/personas/:id"} => {"Delete persona", "Deletes a non-default persona."},
    {"POST", "/api/tokens"} =>
      {"Create token", "Creates a 30-day API token for a signed-in user."}
  }

  def index(conn, _params) do
    api_routes =
      WardleyWeb.Router.__routes__()
      |> Enum.filter(&String.starts_with?(&1.path, "/api"))
      |> Enum.reject(&route_hidden?/1)
      |> Enum.map(&document_route/1)
      |> Enum.sort_by(&{&1.path, verb_order(&1.verb)})

    conn
    |> assign(:page_title, "Developers")
    |> assign(
      :page_description,
      "Developer API reference for Wardley.app, generated from Phoenix routes."
    )
    |> assign(:api_routes, api_routes)
    |> render(:index)
  end

  defp document_route(route) do
    verb = route.verb |> to_string() |> String.upcase()
    path = route.path
    {name, description} = Map.get(@route_docs, {verb, path}, fallback_doc(route))

    %{
      verb: verb,
      path: path,
      name: name,
      description: description,
      controller: route.plug |> inspect() |> String.replace_prefix("WardleyWeb.", ""),
      action: to_string(route.plug_opts),
      auth: auth_for(verb, path)
    }
  end

  defp route_hidden?(route) do
    route.path == "/api" || is_nil(route.verb)
  end

  defp fallback_doc(route) do
    action =
      route.plug_opts
      |> to_string()
      |> String.replace("_", " ")

    {"Route #{route.path}", "Handled by #{inspect(route.plug)}.#{action}."}
  end

  defp auth_for(_verb, "/api/tokens"), do: "Signed-in session + CSRF"
  defp auth_for("GET", "/api/me"), do: "Bearer token required"
  defp auth_for(_verb, _path), do: "Bearer token supported"

  defp verb_order("GET"), do: 0
  defp verb_order("POST"), do: 1
  defp verb_order("PATCH"), do: 2
  defp verb_order("DELETE"), do: 3
  defp verb_order(_verb), do: 9
end
