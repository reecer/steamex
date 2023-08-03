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
  @max_reviews 1000
  
  def start_link(appid) do
    GenServer.start_link(__MODULE__, %{
      appid: appid,
      reviews: [],
      cursor: "*",
      meta: %{title: "", tags: []}
    }, name: {:global, {:via, Registry, {Registry, __MODULE__}}})
  end
  
  def init(state) do
    {:ok, state}
  end
  
  def url(appid, cursor \\ "*") do
    "https://store.steampowered.com/appreviews/#{appid}?cursor=#{URI.encode_www_form(cursor)}&json=0&language=english"
  end

  def meta_url(appid) do
    "https://store.steampowered.com/apphoverpublic/#{appid}?l=english"
  end
  
  # def img_url(appid) do
  #   "https://cdn.akamai.steamstatic.com/steam/apps/#{appid}/header.jpg"
  # end
  
  

  def fetch(self) do
    send(self, :fetch_metadata)
    send(self, :fetch_reviews)
  end
  
  def get(self) do
    GenServer.call(self, :get_state)
  end
  
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
  
  def handle_info(:fetch_metadata, state) do
    IO.puts "fetch_metadata"
    uri = meta_url(state.appid)
    case fetch_from_url(uri, false) do
      {:ok, raw_html} ->
        case Floki.parse_document(raw_html) do
          {:ok, doc} ->
            title = doc
              |> Floki.find(".hover_title")
              |> Floki.text
              
            tags = doc 
              |> Floki.find("div.app_tag") 
              |> Enum.map(&Floki.text/1)
            {:noreply, %{state | meta: %{title: title, tags: tags}}}
          {:error, error} ->
            IO.puts error
            {:stop, error, state}
        end
      {:error, error} ->
        IO.puts error
        {:stop, error, state}
    end
  end
  
  def handle_info(:fetch_reviews, state = %{appid: appid, reviews: reviews, cursor: cursor}) do
    IO.puts "fetch_reviews"
    uri = url(appid, cursor)
    case fetch_from_url(uri) do
      {:ok, %{"success" => 1, "html" => html, "cursor" => next_cursor}} ->
        case extract_from_html(html) do
            {:error, error} ->
                IO.puts "Error parsing html. Stopping..."
                IO.inspect error
                {:stop, error, state}

            next_reviews ->
                reviews = reviews ++ next_reviews
                IO.puts("Fetched #{Enum.count(next_reviews)} reviews for app #{appid}. Total: #{Enum.count(reviews)}.")
                IO.puts("Next cursor: #{next_cursor}")
                
                if next_cursor == "" || Enum.count(reviews) >= @max_reviews do
                    handle_final_reviews(appid, reviews)
                    {:noreply, %{state | cursor: next_cursor, reviews: reviews}}
                else
                    Process.send_after(self(), :fetch_reviews, @fetch_delay)
                    {:noreply, %{state | cursor: next_cursor, reviews: reviews}}
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
  
  def fetch_from_url(url, json? \\ true) do
    IO.puts "Fetching #{url}"
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        if json? do
          Jason.decode(body) 
        else
          {:ok, body}
        end
          
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Request failed with status code #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  def extract_from_html(review_html) do
      html = review_html 
          |> String.replace(~r/\\n|\\t|\\r/u, "") 
          |> String.replace("\\\"", "\"") 
          
      case Floki.parse_document(html) do
          {:ok, doc} ->
            doc 
              |> Floki.find("div.review_box")
              |> Enum.map(&Floki.raw_html/1)
          err ->
            err
      end
  end

  defp handle_final_reviews(appid, reviews) do
    # Do something with the reviews
    IO.puts("Final review count for app #{appid}: #{Enum.count(reviews)}")
  end
end

