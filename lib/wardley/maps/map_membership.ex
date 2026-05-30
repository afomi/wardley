defmodule Wardley.Maps.MapMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "map_memberships" do
    belongs_to :map, Wardley.Maps.Map
    belongs_to :user, Wardley.Accounts.User
    field :role, :string, default: "editor"

    timestamps(type: :utc_datetime)
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:map_id, :user_id, :role])
    |> validate_required([:map_id, :user_id, :role])
    |> validate_inclusion(:role, ["editor", "viewer"])
    |> unique_constraint([:map_id, :user_id])
  end
end
