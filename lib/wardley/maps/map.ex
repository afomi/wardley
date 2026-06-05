defmodule Wardley.Maps.Map do
  use Ecto.Schema
  import Ecto.Changeset

  # public  — anyone may read; owner/members may write
  # private — only owner/members may read or write
  # open    — anyone may read AND write (a shared sandbox; e.g. the default map)
  @visibilities ~w(public private open)

  @doc "Visibility values that allow anyone to read the map."
  def readable_by_all, do: ~w(public open)

  @doc "Visibility values that allow anyone to write to the map."
  def writable_by_all, do: ~w(open)

  schema "maps" do
    field :name, :string
    field :visibility, :string, default: "public"
    belongs_to :user, Wardley.Accounts.User
    has_many :nodes, Wardley.Maps.Node
    has_many :edges, Wardley.Maps.Edge
    has_many :memberships, Wardley.Maps.MapMembership

    timestamps(type: :utc_datetime)
  end

  def changeset(map, attrs) do
    map
    |> cast(attrs, [:name, :user_id, :visibility])
    |> validate_required([:name])
    |> validate_length(:name, max: 200)
    |> validate_inclusion(:visibility, @visibilities)
  end
end
