defmodule Wardley.Repo.Migrations.CreateFragments do
  use Ecto.Migration

  def change do
    create table(:fragments) do
      add :name, :string, null: false
      add :description, :text
      add :data, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:fragments, [:name])
  end
end
