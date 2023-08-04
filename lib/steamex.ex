defmodule Steamex do
  @moduledoc """
  Do all the fetching.
  """
  use Application

  def start(_type, _args) do
    IO.puts "Steamex starting..."
    # List all child processes to be supervised
    children = [
      {OPQ, name: :steam, workers: 10, interval: 100},
      Steamex.EventHandler
    ]

    opts = [strategy: :one_for_one, name: Steamex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc """
  Scrape n reviews of top n games
  """
  def scrape_top(n_games \\ 100, n_reviews \\ 1000) do
    games = TopGames.fetch(n_games)
    IO.puts "Fetched #{Enum.count(games)} games"
    for appid <- games do
      IO.puts "Processing appid #{appid}"
      OPQ.enqueue(:steam, Steamex.Worker, :get_metadata, [appid])
      OPQ.enqueue(:steam, Steamex.Worker, :get_reviews, [appid, "*", 0, n_reviews])
    end
  end
end


defmodule Steamex.EventHandler do
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
    IO.puts "EventHandler: AppID: #{appid}, Metadata: #{inspect(meta)}"
    {:noreply, state}
  end
end


defmodule Steamex.Worker do
  def get_metadata(appid) do
    IO.puts "MetaWorker created for #{appid}"
    t = Task.async(Steamex.SteamAPI, :fetch_metadata, [appid])
    case Task.await(t) do
      {:ok, meta} ->
        send(Steamex.EventHandler, {:metadata, appid, meta})

      {:error, error} ->
        IO.puts "MetaWorker error: #{error}"
    end
  end

  def get_reviews(appid, cursor, count, max) do
    IO.puts "ReviewWorker created for #{appid} (#{cursor})"
    t = Task.async(Steamex.SteamAPI, :fetch_reviews, [appid, cursor])
    case Task.await(t) do
      {:ok, reviews, cursor} ->
        send(Steamex.EventHandler, {:reviews, appid, reviews})
        new_count = count + Enum.count(reviews)

        if new_count < max && String.length(cursor) > 0 do
          OPQ.enqueue(:steam, Steamex.Worker, :get_reviews, [appid, cursor, new_count, max])
        else
          IO.puts "ReviewWorker: Done grabbing reviews for #{appid}. Count: #{new_count}"
        end

      {:error, error} ->
        IO.puts "ReviewWorker error: #{error}"
    end
  end
end
