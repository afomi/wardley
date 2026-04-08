defmodule Wardley.Maps.Fragment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fragments" do
    field :name, :string
    field :description, :string
    field :data, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(fragment, attrs) do
    fragment
    |> cast(attrs, [:name, :description, :data])
    |> validate_required([:name, :data])
    |> validate_length(:name, max: 200)
    |> validate_data()
  end

  defp validate_data(changeset) do
    case get_field(changeset, :data) do
      %{"nodes" => nodes} when is_list(nodes) ->
        changeset

      _ ->
        add_error(changeset, :data, "must contain a nodes list")
    end
  end
end
