defmodule WardleyWeb.PersonasPageController do
  use WardleyWeb, :controller

  alias Wardley.Personas

  def index(conn, _params) do
    personas = Personas.list_personas()

    conn
    |> assign(:page_title, "Personas")
    |> assign(:page_description, "Manage stakeholder personas for your Wardley Maps. Define user types, their needs, and how they interact with your value chain components.")
    |> render(:index, personas: personas)
  end

  def show(conn, %{"id" => id}) do
    case Personas.get_persona(id) do
      nil ->
        conn
        |> put_flash(:error, "Persona not found")
        |> redirect(to: ~p"/personas")

      persona ->
        conn
        |> assign(:page_title, persona.name)
        |> assign(:page_description, "#{persona.name} persona - #{persona.description || "Stakeholder type for Wardley Mapping"}")
        |> render(:show, persona: persona)
    end
  end
end
