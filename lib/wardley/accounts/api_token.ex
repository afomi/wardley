defmodule Wardley.Accounts.ApiToken do
  use Ecto.Schema
  import Ecto.Changeset

  @default_ttl_days 30
  @token_bytes 32

  schema "api_tokens" do
    field :token, :binary, redact: true
    field :label, :string, default: "llm-session"
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, Wardley.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def build_for_user(user, label \\ "llm-session") do
    raw_token = :crypto.strong_rand_bytes(@token_bytes)
    hashed_token = :crypto.hash(:sha256, raw_token)
    encoded_token = Base.url_encode64(raw_token, padding: false)

    api_token = %__MODULE__{
      token: hashed_token,
      label: label,
      user_id: user.id,
      expires_at: expires_at()
    }

    {encoded_token, api_token}
  end

  def hash_token(encoded_token) when is_binary(encoded_token) do
    with {:ok, raw_token} <- Base.url_decode64(encoded_token, padding: false) do
      {:ok, :crypto.hash(:sha256, raw_token)}
    end
  end

  def valid?(%__MODULE__{expires_at: nil}), do: true

  def valid?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(:second), expires_at) == :lt
  end

  def changeset(api_token, attrs) do
    api_token
    |> cast(attrs, [:label, :expires_at, :user_id])
    |> validate_required([:user_id, :token])
    |> validate_length(:label, max: 120)
  end

  defp expires_at do
    DateTime.utc_now(:second)
    |> DateTime.add(@default_ttl_days * 24 * 60 * 60, :second)
  end
end
