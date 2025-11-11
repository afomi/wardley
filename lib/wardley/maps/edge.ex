defmodule Wardley.Maps.Edge do
  use Ecto.Schema
  import Ecto.Changeset

  schema "edges" do
    belongs_to :map, Wardley.Maps.Map
    belongs_to :source, Wardley.Maps.Node
    belongs_to :target, Wardley.Maps.Node
    field :metadata, :map, default: %{}
    timestamps(type: :utc_datetime)
  end

  def changeset(edge, attrs) do
    edge
    |> cast(attrs, [:map_id, :source_id, :target_id, :metadata])
    |> validate_required([:map_id, :source_id, :target_id])
  end
end
