# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :asdf,
  ecto_repos: [Asdf.Repo]

# Configures the endpoint
config :asdf, Asdf.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "KlRfoq0EvGWlhz5xYW7GGiyd1Lzcyw6x9BKv1AIyZY9Jlj76rjLk2z04+nxr/D+B",
  render_errors: [view: Asdf.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Asdf.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
