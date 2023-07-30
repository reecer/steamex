defmodule ReviewFetcher do
  use GenServer

  # TODO: use a database instead of ETS. Faster, more permanent and flexible.
  # Easier to fetch random
  def start_link(appid) do
    GenServer.start_link(__MODULE__, %{
      appid: appid, 
    }, name: {:global, {:via, Registry, {Registry, __MODULE__}}})
  end
  
  def init(state) do
    {:ok, state}
  end
  
  defp url(appid, cursor \\ "*") do
    "https://store.steampowered.com/appreviews/#{appid}?cursor=#{cursor}&json=1&num_per_page=500&language=english"
  end

  def handle_info(:fetch_reviews, state) do
    fetch_reviews_recursive(url(state.appid))
    {:noreply, state}
  end

  defp fetch_reviews_recursive(url, table) do
    case fetch_reviews_from_url(url) do
      {:ok, %{"success" => 1, "html" => html, "cursor" => cursor}} ->
        table |> ets_put(appid, html)
        IO.puts("Fetched #{String.length(html)} characters for app #{appid}.")
        case cursor do
          "" -> # No more cursor, we're done.
            handle_final_reviews(table, appid)

          _ ->
            IO.puts "TODO: next cursor: #{cursor}"
            # fetch_reviews_recursive("#{url}&cursor=#{cursor}", table)
        end
      {:error, reason} ->
        IO.puts reason
    end
  end
  
  defp fetch_reviews_from_url(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode(body)}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Request failed with status code #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp handle_final_reviews(table, appid) do
    reviews = ets_get_all(table, appid)
    # Do something with the final fetched reviews here, like storing them or processing them in some way.
    # For this example, we simply print the reviews.
    IO.puts("Final reviews for app #{appid}: #{inspect(reviews)}")
  end

  defp ets_new(appid) do
    :ets.new(appid, [:bag, :named_table, {:read_concurrency, true}])
  end

  defp ets_put(appid, key, value) do
    :ets.insert(appid, {key, value})
  end

  defp ets_get_all(appid, key) do
    :ets.lookup(appid, key)
  end
end