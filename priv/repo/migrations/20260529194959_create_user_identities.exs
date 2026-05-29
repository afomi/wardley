defmodule Wardley.Repo.Migrations.CreateUserIdentities do
  use Ecto.Migration

  def change do
    create table(:user_identities) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :uid, :string, null: false
      add :access_token, :string
      add :refresh_token, :string
      add :token_expires_at, :utc_datetime
      add :raw_info, :map, default: %{}, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_identities, [:provider, :uid])
    create index(:user_identities, [:user_id])
  end
end
