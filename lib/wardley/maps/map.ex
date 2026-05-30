defmodule Wardley.Maps.Map do
  use Ecto.Schema
  import Ecto.Changeset

  schema "maps" do
    field :name, :string
    belongs_to :user, Wardley.Accounts.User
    has_many :nodes, Wardley.Maps.Node
    has_many :edges, Wardley.Maps.Edge
    has_many :memberships, Wardley.Maps.MapMembership

    timestamps(type: :utc_datetime)
  end

  def changeset(map, attrs) do
    map
    |> cast(attrs, [:name, :user_id])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
  end
end
