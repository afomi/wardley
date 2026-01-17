defmodule WardleyWeb.PersonasControllerTest do
  use WardleyWeb.ConnCase, async: true

  alias Wardley.Personas

  describe "GET /api/personas" do
    test "returns list of personas with default first", %{conn: conn} do
      _default = Personas.get_or_create_default_persona()
      {:ok, _} = Personas.create_persona(%{name: "Analyst"})

      conn = get(conn, ~p"/api/personas")
      response = json_response(conn, 200)

      assert length(response["personas"]) == 2
      assert hd(response["personas"])["is_default"] == true
    end
  end

  describe "GET /api/personas/:id" do
    test "returns a specific persona", %{conn: conn} do
      {:ok, persona} = Personas.create_persona(%{name: "Test Persona", description: "For testing"})

      conn = get(conn, ~p"/api/personas/#{persona.id}")
      response = json_response(conn, 200)

      assert response["id"] == persona.id
      assert response["name"] == "Test Persona"
      assert response["description"] == "For testing"
    end
  end

  describe "POST /api/personas" do
    test "creates a persona with valid data", %{conn: conn} do
      params = %{
        "name" => "New Persona",
        "description" => "A new persona",
        "metadata" => %{"category" => "external"}
      }

      conn = post(conn, ~p"/api/personas", params)
      response = json_response(conn, 201)

      assert response["name"] == "New Persona"
      assert response["description"] == "A new persona"
      assert response["metadata"] == %{"category" => "external"}
    end

    test "returns error for invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/personas", %{})
      response = json_response(conn, 422)

      assert response["errors"]["name"] != nil
    end

    test "returns error for duplicate name", %{conn: conn} do
      {:ok, _} = Personas.create_persona(%{name: "Duplicate"})

      conn = post(conn, ~p"/api/personas", %{"name" => "Duplicate"})
      response = json_response(conn, 422)

      assert response["errors"]["name"] != nil
    end
  end

  describe "PATCH /api/personas/:id" do
    test "updates a persona", %{conn: conn} do
      {:ok, persona} = Personas.create_persona(%{name: "Original"})

      conn = patch(conn, ~p"/api/personas/#{persona.id}", %{"name" => "Updated"})
      response = json_response(conn, 200)

      assert response["name"] == "Updated"
    end
  end

  describe "DELETE /api/personas/:id" do
    test "deletes a non-default persona", %{conn: conn} do
      {:ok, persona} = Personas.create_persona(%{name: "Deletable"})

      conn = delete(conn, ~p"/api/personas/#{persona.id}")

      assert response(conn, 204)
    end

    test "prevents deleting default persona", %{conn: conn} do
      default = Personas.get_or_create_default_persona()

      conn = delete(conn, ~p"/api/personas/#{default.id}")
      response = json_response(conn, 403)

      assert response["error"] == "Cannot delete the default persona"
    end
  end
end
