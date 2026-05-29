defmodule Wardley.Repo.Migrations.CreateApiTokens do
  use Ecto.Migration

  def change do
    create table(:api_tokens) do
      add :token, :binary, null: false
      add :label, :string, default: "llm-session", null: false
      add :last_used_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:api_tokens, [:token])
    create index(:api_tokens, [:user_id])
  end
end
