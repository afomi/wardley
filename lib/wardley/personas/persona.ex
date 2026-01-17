defmodule Wardley.Personas.Persona do
  use Ecto.Schema
  import Ecto.Changeset

  schema "personas" do
    field :name, :string
    field :description, :string
    field :is_default, :boolean, default: false
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(persona, attrs) do
    persona
    |> cast(attrs, [:name, :description, :is_default, :metadata])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
