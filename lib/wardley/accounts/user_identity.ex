defmodule Wardley.Accounts.UserIdentity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Wardley.Accounts.User

  schema "user_identities" do
    belongs_to :user, User
    field :provider, :string
    field :uid, :string
    field :access_token, :string, redact: true
    field :refresh_token, :string, redact: true
    field :token_expires_at, :utc_datetime
    field :raw_info, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [
      :provider,
      :uid,
      :user_id,
      :access_token,
      :refresh_token,
      :token_expires_at,
      :raw_info
    ])
    |> validate_required([:provider, :uid, :user_id])
    |> unique_constraint([:provider, :uid])
  end
end
