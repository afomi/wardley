defmodule Wardley.Maps.Map do
  use Ecto.Schema
  import Ecto.Changeset

  schema "maps" do
    field :name, :string
    has_many :nodes, Wardley.Maps.Node
    has_many :edges, Wardley.Maps.Edge
    timestamps(type: :utc_datetime)
  end

  def changeset(map, attrs) do
    map
    |> cast(attrs, [:name])
    |> validate_length(:name, max: 200)
  end
end

