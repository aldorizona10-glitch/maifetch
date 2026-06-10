defmodule Maifetch.CLI do
  @moduledoc false

  alias Maifetch.{API, Config, Render}

  def main(argv) do
    case run(argv) do
      :ok -> :ok
      {:error, message} -> IO.puts(message)
    end
  end

  def run(argv) do
    with {:ok, config} <- Config.load(argv),
         {:ok, profiles} <- API.profiles(config.access_token),
         {:profile, profile} <- first_profile(profiles),
         {:ok, plays} <- API.plays(config.access_token) do
      IO.puts(Render.output(profile, plays, config.logo_size, config.score_count))
      :ok
    else
      {:profile, nil} -> IO.puts("No profiles found")
      {:error, message} -> {:error, message}
    end
  end

  defp first_profile([profile | _]), do: {:profile, profile}
  defp first_profile(_), do: {:profile, nil}
end
