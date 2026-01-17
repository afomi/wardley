defmodule Wardley.Repo.Migrations.CreatePersonas do
  use Ecto.Migration

  def change do
    create table(:personas) do
      add :name, :string, null: false
      add :description, :text
      add :is_default, :boolean, default: false, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:personas, [:name])
    create index(:personas, [:is_default])
  end
end
