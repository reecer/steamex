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
  
  def start_link(appid) do
    GenServer.start_link(__MODULE__, %{
      appid: appid, 
    }, name: {:global, {:via, Registry, {Registry, __MODULE__}}})
  end
  
  def init(state) do
    {:ok, state, {:continue, :start}}
  end
  
  defp url(appid, cursor \\ "*") do
    "https://store.steampowered.com/appreviews/#{appid}?cursor=#{cursor}&json=0&num_per_page=500&language=english"
  end

  defp meta_url(appid) do
    "https://store.steampowered.com/apphoverpublic/#{appid}?review_score_preference=0&l=english&pagev6=true"


    # Image
    # "https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg"
  end
  
  

  def handle_continue(:start, state) do
    send(self, :fetch_reviews)
    send(self, :fetch_metadata)
    {:noreply, state}
  end
  
  def handle_info(:fetch_metadata, state) do
    IO.puts "TODO: fetch_metadata"
    {:noreply, state}
  end
  
  def handle_info(:fetch_reviews, state) do
    fetch_reviews_recursive(state.appid)
    {:noreply, state}
  end

  defp fetch_reviews_recursive(appid, cursor \\ "*", reviews \\ []) do
    uri = url(appid, cursor)
    case fetch_reviews_from_url(uri) do
      {:ok, %{"error" => error}} ->
        IO.puts "Error fetching: #{error}"
      
      {:ok, %{"success" => 1, "html" => html, "cursor" => cursor}} ->
        IO.puts("Fetched #{String.length(html)} characters for app #{appid}.")
        case extract_from_html(html) do
            {:error, err} ->
                IO.puts "Error parsing html. Stopping..."
                IO.inspect err
            review ->
                reviews = reviews ++ [review]
            
                case cursor do
                  "" -> # No more cursor, we're done.
                    handle_final_reviews(appid, reviews)
        
                  _ ->
                    IO.puts "TODO: next cursor: #{cursor}"
                    fetch_reviews_recursive(appid, cursor, reviews)
                end
        end
      {:error, reason} ->
        IO.puts reason
    end
  end
  
  defp fetch_reviews_from_url(url) do
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

