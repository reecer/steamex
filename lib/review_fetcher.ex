defmodule ReviewFetcher do
  @moduledoc """
  Grab a games metadata and reviews.
  """
  use GenServer

  # TODO: use a database instead of ETS. Faster, more permanent and flexible.
  # Easier to fetch random and similar games

  # Only grab X number of reviews...some have millions

  # Game
  # - Name
  # - AppId

  # Review
  # - AppId
  # - Content (html)

  # Tag
  # - Name

  # Game-Tags
  # - AppId
  # - TagId

  @fetch_delay 500
  
  def start_link(appid) do
    GenServer.start_link(__MODULE__, %{
      appid: appid,
      reviews: [],
      cursor: "*"
    }, name: {:global, {:via, Registry, {Registry, __MODULE__}}})
  end
  
  def init(state) do
    {:ok, state}
  end
  
  defp url(appid, cursor \\ "*") do
    "https://store.steampowered.com/appreviews/#{appid}?cursor=#{URI.encode_www_form(cursor)}&json=0&num_per_page=500&language=english"
  end

  defp meta_url(appid) do
    "https://store.steampowered.com/apphoverpublic/#{appid}?review_score_preference=0&l=english&pagev6=true"


    # Image
    # "https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg"
  end
  
  

  def fetch(self) do
    send(self, :fetch_metadata)
    send(self, :fetch_reviews)
  end
  
  def handle_info(:fetch_metadata, state) do
    IO.puts "TODO: fetch_metadata"
    {:noreply, state}
  end
  
  def handle_info(:fetch_reviews, state = %{appid: appid, reviews: reviews, cursor: cursor}) do
    uri = url(appid, cursor)
    case fetch_reviews_from_url(uri) do
      {:ok, %{"success" => 1, "html" => html, "cursor" => next_cursor}} ->
        case extract_from_html(html) do
            {:error, error} ->
                IO.puts "Error parsing html. Stopping..."
                IO.inspect error
                {:stop, error, state}

            next_reviews ->
                reviews = reviews ++ [next_reviews]
                IO.puts("Fetched #{Enum.count(next_reviews)} reviews for app #{appid}. Total: #{Enum.count(reviews)}.")
                IO.puts("Next cursor: #{next_cursor}")
            
                case next_cursor do
                  "" -> # No more cursor, we're done.
                    handle_final_reviews(appid, reviews)
                    {:noreply, %{appid: appid, cursor: next_cursor, reviews: reviews}}
        
                  _ ->
                    Process.send_after(self(), :fetch_reviews, @fetch_delay)
                    {:noreply, %{appid: appid, cursor: next_cursor, reviews: reviews}}
                end
        end

      {:ok, %{"error" => error}} ->
        IO.puts "Error fetching: #{error}"
        {:stop, error, state}
      
      {:error, error} ->
        IO.puts error
        {:stop, error, state}
    end
  end
  
  defp fetch_reviews_from_url(url) do
    IO.puts "Fetching #{url}"
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        Jason.decode(body) 
          
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Request failed with status code #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp handle_final_reviews(appid, reviews) do
    # Do something with the reviews
    IO.puts("Final review count for app #{appid}: #{Enum.count(reviews)}")
  end

  defp extract_from_html(review_html) do
      html = review_html 
          |> String.replace(~r/\\n|\\t|\\r/u, "") 
          |> String.replace("\\\"", "\"") 
          
      case Floki.parse_document(html) do
          {:ok, doc} ->
            doc |> Floki.find("div.review_box")
          err ->
            err
      end
  end
end

