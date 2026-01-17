defmodule Wardley.Personas do
  @moduledoc """
  Context for Personas - the "who" dimension of Wardley Maps.

  Personas represent different stakeholder types who interact with or
  are affected by components in a value stream. The default "User" persona
  is always present and represents the generic end-user.
  """
  import Ecto.Query
  alias Wardley.Repo
  alias Wardley.Personas.Persona

  @doc """
  Returns the list of all personas, with the default persona first,
  then remaining personas in alphabetical order.
  """
  def list_personas do
    Repo.all(
      from p in Persona,
        order_by: [desc: p.is_default, asc: p.name]
    )
  end

  @doc """
  Gets a single persona by ID.
  Returns nil if not found.
  """
  def get_persona(id), do: Repo.get(Persona, id)

  @doc """
  Gets a single persona by ID.
  Raises `Ecto.NoResultsError` if not found.
  """
  def get_persona!(id), do: Repo.get!(Persona, id)

  @doc """
  Gets a persona by name.
  Returns nil if not found.
  """
  def get_persona_by_name(name) do
    Repo.get_by(Persona, name: name)
  end

  @doc """
  Gets the default persona, creating it if it doesn't exist.
  """
  def get_or_create_default_persona do
    case Repo.one(from p in Persona, where: p.is_default == true, limit: 1) do
      nil ->
        {:ok, persona} =
          create_persona(%{
            name: "User",
            description: "Generic end-user of the system",
            is_default: true
          })

        persona

      persona ->
        persona
    end
  end

  @doc """
  Creates a persona.
  """
  def create_persona(attrs) do
    %Persona{}
    |> Persona.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a persona.
  """
  def update_persona(%Persona{} = persona, attrs) do
    persona
    |> Persona.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a persona.
  Returns error if attempting to delete the default persona.
  """
  def delete_persona(%Persona{is_default: true}), do: {:error, :cannot_delete_default}

  def delete_persona(%Persona{} = persona) do
    Repo.delete(persona)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking persona changes.
  """
  def change_persona(%Persona{} = persona, attrs \\ %{}) do
    Persona.changeset(persona, attrs)
  end

  @doc """
  Searches personas by name (case-insensitive partial match).
  """
  def search_personas(query) when is_binary(query) do
    search_term = "%#{query}%"

    Repo.all(
      from p in Persona,
        where: ilike(p.name, ^search_term) or ilike(p.description, ^search_term),
        order_by: [desc: p.is_default, asc: p.name]
    )
  end
end
