defmodule PhxApp.Repo do
  use Ecto.Repo,
    otp_app: :phx_app,
    adapter: Ecto.Adapters.SQLite3
end
