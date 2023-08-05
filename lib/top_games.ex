defmodule Steamex.TopGames do
  @per_page 100 # Max is 100

  def fetch(n \\ 1000) do
    Enum.reduce(1..Integer.floor_div(n, @per_page), [], fn i, acc ->
      acc ++ extract_ids_from_url(url((i-1) * @per_page))
    end) |> Enum.take(n)
  end

  defp url(offset) do
    "https://store.steampowered.com/search/results/?query&start=#{offset}&count=#{@per_page}&sort_by=_ASC&supportedlang=english&filter=topsellers&infinite=1"
  end

  defp extract_ids_from_url(url) do
    IO.puts "Fetching #{url}"
    case make_web_request(url) do
      {:ok, response_body} -> extract_ids(response_body)
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_ids(text) do
    extract_ids_with_regex(text)
  end

  defp extract_ids_with_regex(text) do
    Regex.scan(~r/App_(\d+)/, text)
      |> Enum.map(&extract_id_from_match(&1))
      |> Enum.filter(&is_integer/1)
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
end
