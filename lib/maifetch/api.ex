defmodule Maifetch.API do
  @moduledoc false

  @base_url "https://maitea.app"

  def profiles(token), do: get(token, "/api/v1/profiles") |> unwrap_data()
  def plays(token), do: get(token, "/api/v1/plays") |> unwrap_data()
  def tracks(token), do: get(token, "/api/v1/tracks") |> unwrap_data()
  def status(token), do: get(token, "/api/status")
  def all_plays(token), do: get(token, "/api/v1/plays/all") |> unwrap_data()
  def best_scores(token), do: get(token, "/api/v1/scores") |> unwrap_data()
  def all_best_scores(token), do: get(token, "/api/v1/scores/all") |> unwrap_data()

  def get(token, path) do
    url = @base_url <> path

    case Req.get(url, auth: {:bearer, token}, headers: [{"accept", "application/json"}, {"content-type", "application/json"}], receive_timeout: 30_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "MaiTea API returned HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, "MaiTea API request failed: #{Exception.message(reason)}"}
    end
  end

  defp unwrap_data({:ok, %{"data" => data}}), do: {:ok, data}
  defp unwrap_data({:ok, data}), do: {:ok, data}
  defp unwrap_data(error), do: error
end
