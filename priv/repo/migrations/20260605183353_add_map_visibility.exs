defmodule Wardley.Repo.Migrations.AddMapVisibility do
  use Ecto.Migration

  def change do
    alter table(:maps) do
      add :visibility, :string, null: false, default: "public"
    end

    create index(:maps, [:visibility])
  end
end
