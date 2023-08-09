defmodule Steamex.Worker do
  def get_metadata(from, appid) do
    IO.puts "MetaWorker created for #{appid}"
    res = Steamex.SteamAPI.fetch_metadata(appid)
    # t = Task.async(Steamex.SteamAPI, :fetch_metadata, [appid])
    # case Task.await(t) do
    case res do
      {:ok, meta} ->
        send(from, {:metadata, appid, meta})

      {:error, error} ->
        IO.puts "MetaWorker error: #{error}"
    end
  end

  def get_reviews(from, appid, cursor, count, max) do
    IO.puts "ReviewWorker created for #{appid} (#{cursor})"
    res = Steamex.SteamAPI.fetch_reviews(appid, cursor)
    # t = Task.async(Steamex.SteamAPI, :fetch_reviews, [appid, cursor])
    # case Task.await(t) do
    case res do
      {:ok, reviews, cursor} ->
        send(from, {:reviews, appid, reviews})
        new_count = count + Enum.count(reviews)

        if new_count < max && String.length(cursor) > 0 do
          OPQ.enqueue(:steam, Steamex.Worker, :get_reviews, [from, appid, cursor, new_count, max])
        else
          IO.puts "ReviewWorker: Done grabbing reviews for #{appid}. Count: #{new_count}"
        end

      {:error, error} ->
        IO.puts "ReviewWorker error: #{error}"
    end
  end
end
