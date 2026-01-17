defmodule WardleyWeb.PersonasController do
  use WardleyWeb, :controller
  alias Wardley.Personas
  alias Wardley.Personas.Persona

  @doc """
  List all personas.
  GET /api/personas
  """
  def index(conn, _params) do
    personas = Personas.list_personas()
    json(conn, %{personas: Enum.map(personas, &persona_json/1)})
  end

  @doc """
  Get a single persona.
  GET /api/personas/:id
  """
  def show(conn, %{"id" => id}) do
    persona = Personas.get_persona!(id)
    json(conn, persona_json(persona))
  end

  @doc """
  Create a persona.
  POST /api/personas
  """
  def create(conn, params) do
    attrs = %{
      "name" => params["name"],
      "description" => params["description"],
      "metadata" => params["metadata"] || %{}
    }

    case Personas.create_persona(attrs) do
      {:ok, persona} ->
        conn
        |> put_status(:created)
        |> json(persona_json(persona))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  Update a persona.
  PATCH /api/personas/:id
  """
  def update(conn, %{"id" => id} = params) do
    persona = Personas.get_persona!(id)
    attrs = Map.take(params, ["name", "description", "metadata"])

    case Personas.update_persona(persona, attrs) do
      {:ok, persona} ->
        json(conn, persona_json(persona))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  Delete a persona.
  DELETE /api/personas/:id
  """
  def delete(conn, %{"id" => id}) do
    persona = Personas.get_persona!(id)

    case Personas.delete_persona(persona) do
      {:ok, _} ->
        send_resp(conn, :no_content, "")

      {:error, :cannot_delete_default} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Cannot delete the default persona"})
    end
  end

  defp persona_json(%Persona{} = p) do
    %{
      id: p.id,
      name: p.name,
      description: p.description,
      is_default: p.is_default,
      metadata: p.metadata || %{}
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
