defmodule PhxApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      PhxAppWeb.Telemetry,
      # Start the Ecto repository
      PhxApp.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: PhxApp.PubSub},
      # Start the Endpoint (http/https)
      PhxAppWeb.Endpoint
      # Start a worker by calling: PhxApp.Worker.start_link(arg)
      # {PhxApp.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PhxApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
