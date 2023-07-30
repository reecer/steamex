defmodule TopGames do
  
  defp url do
    "https://store.steampowered.com/search/results/?query&start=0&count=100&sort_by=_ASC&supportedlang=english&filter=topsellers&infinite=1"
  end

  def fetch do
    extract_ids_from_url url()
  end
  
  defp extract_ids(text) do
    extract_ids_with_regex(text)
  end

  defp extract_ids_with_regex(text) do
    regex = ~r/App_(\d+)/
    case Regex.scan(regex, text) do
      nil -> []
      matches ->
        matches
        |> Enum.map(&extract_id_from_match(&1))
        |> Enum.filter(&is_integer/1)
    end
  end

  defp extract_id_from_match([_, id | _]) do
    String.to_integer(id)
  end

  defp extract_id_from_match(_), do: nil

  defp make_web_request(url) do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "Request failed with status code #{status}"}

      {:error, reason} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp extract_ids_from_url(url) do
    case make_web_request(url) do
      {:ok, response_body} -> extract_ids(response_body)
      {:error, reason} -> {:error, reason}
    end
  end
end

