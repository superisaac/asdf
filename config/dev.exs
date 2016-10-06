use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :asdf, Asdf.Endpoint,
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                    cd: Path.expand("../", __DIR__)]]


# Watch static and templates for browser reloading.
config :asdf, Asdf.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{priv/gettext/.*(po)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :asdf, Asdf.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "dev",
  password: "dev",
  database: "asdf_dev",
  hostname: "localhost",
  pool_size: 10

# config :asdf, Asdf.Repo,
#   adapter: Sqlite.Ecto,
#   database: "asdf_dev.sqlite3",
#   size: 1,
#   max_overflow: 10,
#   pool_size: 10

config :asdf, :github_auth,
  clientid: "",
  secret: ""

import_config "dev.secret.exs"
 
