defmodule WardleyWeb.MapControllerTest do
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Maps

  import Wardley.AccountsFixtures

  setup :register_and_log_in_user

  describe "GET /maps/:id visibility" do
    test "owner can view their own private map", %{conn: conn, user: user} do
      {:ok, map} = Maps.create_map(%{name: "Mine", user_id: user.id, visibility: "private"})

      conn = get(conn, ~p"/maps/#{map.id}")

      assert html_response(conn, 200) =~ ~s(data-map-id="#{map.id}")
    end

    test "a non-owner can view someone else's public map (read-only)", %{conn: conn} do
      other = user_fixture(%{email: "pub-owner@example.com"})
      {:ok, map} = Maps.create_map(%{name: "Public", user_id: other.id})

      conn = get(conn, ~p"/maps/#{map.id}")
      body = html_response(conn, 200)

      assert body =~ ~s(data-map-id="#{map.id}")
      assert body =~ ~s(data-can-edit="false")
    end

    test "a non-member gets 404 for someone else's private map", %{conn: conn} do
      other = user_fixture(%{email: "priv-owner@example.com"})
      {:ok, map} = Maps.create_map(%{name: "Private", user_id: other.id, visibility: "private"})

      conn = get(conn, ~p"/maps/#{map.id}")

      assert html_response(conn, 404)
    end

    test "a member can view and edit a private map", %{conn: conn, user: user} do
      other = user_fixture(%{email: "share-owner@example.com"})
      {:ok, map} = Maps.create_map(%{name: "Shared", user_id: other.id, visibility: "private"})
      {:ok, _} = Maps.add_member(map.id, user.id)

      conn = get(conn, ~p"/maps/#{map.id}")
      body = html_response(conn, 200)

      assert body =~ ~s(data-can-edit="true")
    end
  end

  describe "GET /maps/:id layout" do
    test "the add-layer modal renders exactly once", %{conn: conn, user: user} do
      {:ok, map} = Maps.create_map(%{name: "Layout", user_id: user.id})

      body = conn |> get(~p"/maps/#{map.id}") |> html_response(200)

      # Present, and not duplicated (it used to live inside the panel; moving it
      # to the top level must not leave a second copy behind).
      assert length(String.split(body, ~s(id="map-selector-modal"))) == 2
    end
  end
end
