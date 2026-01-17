defmodule WardleyWeb.PersonasPageController do
  use WardleyWeb, :controller

  alias Wardley.Personas

  def index(conn, _params) do
    personas = Personas.list_personas()

    render(conn, :index,
      personas: personas,
      page_title: "Personas"
    )
  end

  def show(conn, %{"id" => id}) do
    case Personas.get_persona(id) do
      nil ->
        conn
        |> put_flash(:error, "Persona not found")
        |> redirect(to: ~p"/personas")

      persona ->
        render(conn, :show,
          persona: persona,
          page_title: persona.name
        )
    end
  end
end
