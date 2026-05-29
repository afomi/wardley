defmodule WardleyWeb.PageControllerTest do
  use WardleyWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ "Wardley Mapping"
    assert html =~ "1. Value Stream Connections"
    assert html =~ "2. Evolution"
    assert html =~ "3. Gameplay"
    assert html =~ "LLM image prompt: Create a clean product-style illustration"
    assert html =~ "LLM image prompt: Create a clean instructional illustration"
    assert html =~ "LLM image prompt: Create a clean strategic gameplay illustration"
    assert html =~ ~s(href="/login")
  end
end
