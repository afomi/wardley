defmodule Wardley.Maps.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nodes" do
    belongs_to :map, Wardley.Maps.Map
    field :x_pct, :float
    field :y_pct, :float
    field :text, :string
    field :metadata, :map, default: %{}
    timestamps(type: :utc_datetime)
  end

  def changeset(node, attrs) do
    node
    |> cast(attrs, [:map_id, :x_pct, :y_pct, :text, :metadata])
    |> validate_required([:map_id, :x_pct, :y_pct, :text])
    |> validate_number(:x_pct, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    |> validate_number(:y_pct, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
  end
end

