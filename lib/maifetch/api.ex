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
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)

    url = @base_url <> path

    headers = [
      {~c"authorization", ~c"Bearer " ++ String.to_charlist(token)},
      {~c"accept", ~c"application/json"},
      {~c"content-type", ~c"application/json"}
    ]

    request = {String.to_charlist(url), headers}
    options = [timeout: 30_000]
    http_options = [body_format: :binary]

    case :httpc.request(:get, request, options, http_options) do
      {:ok, {{_, status, _}, _headers, body}} when status in 200..299 ->
        Jason.decode(body)

      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, "MaiTea API returned HTTP #{status}: #{body}"}

      {:error, reason} ->
        {:error, "MaiTea API request failed: #{inspect(reason)}"}
    end
  end

  defp unwrap_data({:ok, %{"data" => data}}), do: {:ok, data}
  defp unwrap_data({:ok, data}), do: {:ok, data}
  defp unwrap_data(error), do: error
end
