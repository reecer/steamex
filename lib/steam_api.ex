defmodule Steamex.SteamAPI do
  def url(appid, cursor \\ "*") do
    "https://store.steampowered.com/appreviews/#{appid}?cursor=#{URI.encode_www_form(cursor)}&json=0&language=english&filter=funny&purchase_type=all"
  end

  def meta_url(appid) do
    "https://store.steampowered.com/apphoverpublic/#{appid}?l=english"
  end

  def fetch_metadata(appid) do
    uri = meta_url(appid)
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

            meta = %{title: title, tags: tags}
            {:ok, meta}
          {:error, error} ->
            IO.puts error
            {:error, error}
        end
      {:error, error} ->
        IO.puts error
        {:error, error}
    end
  end

  def fetch_reviews(appid, cursor) do
    uri = url(appid, cursor)
    case fetch_from_url(uri) do
      {:ok, %{"success" => 1, "html" => html, "cursor" => next_cursor}} ->
        case extract_from_html(html) do
          {:error, error} ->
            {:error, error}

          reviews ->
            {:ok, reviews, next_cursor}
        end

      {:ok, %{"error" => error}} ->
        IO.puts "Error fetching: #{error}"
        {:error, error}

      {:error, error} ->
        IO.puts error
        {:error, error}
    end
  end

  def fetch_from_url(url, json? \\ true) do
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
end
