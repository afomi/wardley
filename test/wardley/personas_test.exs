defmodule Wardley.PersonasTest do
  use Wardley.DataCase, async: true

  alias Wardley.Personas
  alias Wardley.Personas.Persona

  describe "personas" do
    test "list_personas/0 returns default persona first, then alphabetically" do
      # Create default first
      _default = Personas.get_or_create_default_persona()

      {:ok, _citizen} = Personas.create_persona(%{name: "Citizen"})
      {:ok, _analyst} = Personas.create_persona(%{name: "Analyst"})

      personas = Personas.list_personas()

      assert length(personas) == 3
      assert hd(personas).is_default == true
      assert hd(personas).name == "User"
      assert Enum.at(personas, 1).name == "Analyst"
      assert Enum.at(personas, 2).name == "Citizen"
    end

    test "get_persona!/1 returns the persona with given id" do
      {:ok, persona} = Personas.create_persona(%{name: "Test Persona"})

      fetched = Personas.get_persona!(persona.id)

      assert fetched.id == persona.id
      assert fetched.name == "Test Persona"
    end

    test "get_persona_by_name/1 returns persona by name" do
      {:ok, _persona} = Personas.create_persona(%{name: "Manager"})

      result = Personas.get_persona_by_name("Manager")

      assert result.name == "Manager"
    end

    test "get_persona_by_name/1 returns nil for non-existent name" do
      assert Personas.get_persona_by_name("NonExistent") == nil
    end

    test "get_or_create_default_persona/0 creates default if none exists" do
      default = Personas.get_or_create_default_persona()

      assert default.name == "User"
      assert default.is_default == true
    end

    test "get_or_create_default_persona/0 returns existing default" do
      first = Personas.get_or_create_default_persona()
      second = Personas.get_or_create_default_persona()

      assert first.id == second.id
    end

    test "create_persona/1 with valid data creates a persona" do
      attrs = %{
        name: "Frontline Staff",
        description: "Employees who interact directly with citizens",
        metadata: %{"department" => "Customer Service"}
      }

      assert {:ok, %Persona{} = persona} = Personas.create_persona(attrs)
      assert persona.name == "Frontline Staff"
      assert persona.description == "Employees who interact directly with citizens"
      assert persona.metadata == %{"department" => "Customer Service"}
      assert persona.is_default == false
    end

    test "create_persona/1 without name fails" do
      assert {:error, changeset} = Personas.create_persona(%{description: "No name"})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "create_persona/1 with duplicate name fails" do
      {:ok, _} = Personas.create_persona(%{name: "Duplicate"})

      assert {:error, changeset} = Personas.create_persona(%{name: "Duplicate"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "update_persona/2 with valid data updates the persona" do
      {:ok, persona} = Personas.create_persona(%{name: "Original"})

      assert {:ok, updated} = Personas.update_persona(persona, %{name: "Updated", description: "New desc"})
      assert updated.name == "Updated"
      assert updated.description == "New desc"
    end

    test "delete_persona/1 deletes the persona" do
      {:ok, persona} = Personas.create_persona(%{name: "Deletable"})

      assert {:ok, %Persona{}} = Personas.delete_persona(persona)
      assert_raise Ecto.NoResultsError, fn -> Personas.get_persona!(persona.id) end
    end

    test "delete_persona/1 prevents deleting default persona" do
      default = Personas.get_or_create_default_persona()

      assert {:error, :cannot_delete_default} = Personas.delete_persona(default)
      assert Personas.get_persona!(default.id) != nil
    end

    test "search_personas/1 finds personas by name" do
      Personas.get_or_create_default_persona()
      {:ok, _} = Personas.create_persona(%{name: "City Manager"})
      {:ok, _} = Personas.create_persona(%{name: "Department Head"})

      results = Personas.search_personas("manager")

      assert length(results) == 1
      assert hd(results).name == "City Manager"
    end

    test "search_personas/1 finds personas by description" do
      {:ok, _} = Personas.create_persona(%{name: "Analyst", description: "Works on data analysis"})
      {:ok, _} = Personas.create_persona(%{name: "Manager", description: "Oversees operations"})

      results = Personas.search_personas("data")

      assert length(results) == 1
      assert hd(results).name == "Analyst"
    end

    test "search_personas/1 is case-insensitive" do
      {:ok, _} = Personas.create_persona(%{name: "UPPERCASE"})

      results = Personas.search_personas("uppercase")

      assert length(results) == 1
    end

    test "change_persona/1 returns a changeset" do
      {:ok, persona} = Personas.create_persona(%{name: "Changeable"})

      changeset = Personas.change_persona(persona)

      assert %Ecto.Changeset{} = changeset
    end
  end
end
