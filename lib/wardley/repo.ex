defmodule Wardley.Repo do
  use Ecto.Repo,
    otp_app: :wardley,
    adapter: Ecto.Adapters.Postgres
end
