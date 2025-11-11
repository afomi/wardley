defmodule Wardley.Repo.Migrations.CreateMapsNodesEdges do
  use Ecto.Migration

  def change do
    create table(:maps) do
      add :name, :string
      timestamps(type: :utc_datetime)
    end

    create table(:nodes) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :x_pct, :float, null: false
      add :y_pct, :float, null: false
      add :text, :string, null: false
      add :metadata, :map, default: %{}, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:nodes, [:map_id])

    create table(:edges) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :source_id, references(:nodes, on_delete: :delete_all), null: false
      add :target_id, references(:nodes, on_delete: :delete_all), null: false
      add :metadata, :map, default: %{}, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:edges, [:map_id])
    create index(:edges, [:source_id])
    create index(:edges, [:target_id])
  end
end

