defmodule ReviewFetcher do
  use GenServer

  def start_link(appid) do
    GenServer.start_link(__MODULE__, %{appid: appid}, name: {:global, {:via, Registry, {Registry, __MODULE__}}})
  end

  def init(state) do
    table_name = :"reviews_#{state.appid}"
    :ets.new(table_name, [:set, :protected, :heir, :named_table, {:read_concurrency, true}])
    {:ok, %{state | table_name: table_name}}
  end

  def handle_info(:fetch_reviews, state) do
    appid = state.appid
    url = "https://store.steampowered.com/appreviews/#{appid}?cursor=*&json=1&num_per_page=500&language=english"
    fetch_reviews_recursive(url, state.table_name)
    {:noreply, state}
  end

  defp fetch_reviews_recursive(url, table_name) do
    case fetch_reviews_from_url(url) do
      {:ok, %{"success" => 1, "html" => html, "cursor" => cursor}} ->
        table_name |> ets_put(appid, html)
        IO.puts("Fetched #{String.length(html)} characters for app #{appid}.")
        case cursor do
          "" -> # No more cursor, we're done.
            handle_final_reviews(table_name, appid)

          _ ->
            fetch_reviews_recursive("#{url}&cursor=#{cursor}", table_name)
        end

      {:ok, _} -> # Some unexpected JSON structure or missing keys
        IO.puts("Failed to fetch reviews for app #{appid}. Unexpected JSON structure.")
        handle_final_reviews(table_name, appid)

      {:error, reason} ->
        IO.puts("Failed to fetch reviews for app #{appid}. Reason: #{reason}")
        handle_final_reviews(table_name, appid)
    end
  end

  defp handle_final_reviews(table_name, appid) do
    reviews = ets_get_all(table_name, appid)
    # Do something with the final fetched reviews here, like storing them or processing them in some way.
    # For this example, we simply print the reviews.
    IO.puts("Final reviews for app #{appid}: #{inspect(reviews)}")
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

  defp ets_put(table_name, key, value) do
    ets :ets.insert(table_name, {key, value})
  end

  defp ets_get_all(table_name, key) do
    ets :ets.lookup(table_name, key)
  end
end