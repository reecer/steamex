# Steamex
Fetch n reviews from the top n games.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `steamex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:steamex, "~> 0.1.0"}
  ]
end
```

### Usage
```elixir
# These are the default values
workers = 10
n_games = 100
n_reviews = 1000

Steamex.init(workers)
Steamex.scrape_top(Example.EventHandler, n_games, n_reviews)

# Clean up
Steamex.stop()
```

Handle events async as they come in:
```elixir
defmodule Example.EventHandler do
  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    IO.puts "EventHandler starting..."
    {:ok, nil}
  end

  def handle_info({:reviews, appid, reviews}, state) do
    IO.puts "EventHandler: AppID: #{appid}, Reviews: #{Enum.count(reviews)}"
    {:noreply, state}
  end

  def handle_info({:metadata, appid, meta}, state) do
    IO.puts "EventHandler: AppID: #{appid}, #{meta.title}"
    {:noreply, state}
  end
end
```

Start your handler if you want:
```elixir
defmodule Example do
  use Application

  def start(_type, _args) do
    children = [
      Example.EventHandler
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

TODO
====
header img: "https://cdn.akamai.steamstatic.com/steam/apps/#{appid}/header.jpg"

Game
 - Name
 - AppId

Review
 - AppId
 - Content (html)

Tag
 - Name

Game-Tags
 - AppId
 - TagId