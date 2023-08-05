defmodule Steamex do
  @doc """
  Scrape n reviews of top n games
  """

  def init(workers) do
    OPQ.init(name: :steam, workers: workers)
  end

  def stop do
    OPQ.stop(:steam)
  end

  def scrape_top(reply_to, n_games \\ 100, n_reviews \\ 1000) do
    for appid <- Steamex.TopGames.fetch(n_games) do
      OPQ.enqueue(:steam, Steamex.Worker, :get_metadata, [reply_to, appid])
      OPQ.enqueue(:steam, Steamex.Worker, :get_reviews, [reply_to, appid, "*", 0, n_reviews])
    end
  end
end
