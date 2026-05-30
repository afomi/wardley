defmodule Wardley.Repo.Migrations.AddMapOwnership do
  use Ecto.Migration

  def change do
    # System user for legacy/unowned maps
    execute(
      "INSERT INTO users (email, hashed_password, confirmed_at, inserted_at, updated_at) VALUES ('system@wardley.app', '', NOW(), NOW(), NOW())",
      "DELETE FROM users WHERE email = 'system@wardley.app'"
    )

    # Add owner to maps
    alter table(:maps) do
      add :user_id, references(:users, on_delete: :nilify_all)
    end

    create index(:maps, [:user_id])

    # Assign existing maps to system user
    execute(
      "UPDATE maps SET user_id = (SELECT id FROM users WHERE email = 'system@wardley.app')",
      "SELECT 1"
    )

    # Map memberships for collaboration
    create table(:map_memberships) do
      add :map_id, references(:maps, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, null: false, default: "editor"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:map_memberships, [:map_id, :user_id])
    create index(:map_memberships, [:user_id])
  end
end
