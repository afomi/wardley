defmodule WardleyWeb.DevelopersControllerTest do
  use WardleyWeb.ConnCase, async: true

  test "GET /developers documents API routes from the router", %{conn: conn} do
    conn = get(conn, ~p"/developers")
    html = html_response(conn, 200)

    assert html =~ "Wardley.app API"
    assert html =~ "WardleyWeb.Router.__routes__/0"
    assert html =~ "Authorization: Bearer $WARDLEY_API_TOKEN"
    assert html =~ ~s(href="/llms.txt")

    api_routes =
      WardleyWeb.Router.__routes__()
      |> Enum.filter(&String.starts_with?(&1.path, "/api"))

    for route <- api_routes do
      assert html =~ route.path
      assert html =~ route.verb |> to_string() |> String.upcase()
    end
  end
end
