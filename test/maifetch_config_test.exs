defmodule Maifetch.ConfigTest do
  use ExUnit.Case, async: true

  alias Maifetch.Config

  test "loads CLI values before env values" do
    env = fn
      "MAITEA_TOKEN" -> "env-token"
      "MAITEA_SCORE_COUNT" -> "2"
      _ -> nil
    end

    assert {:ok, config} = Config.load(["--access-token", "cli-token", "--score-count", "3", "--logo-size", "0"], env)
    assert config.access_token == "cli-token"
    assert config.score_count == 3
    assert config.logo_size == 0
  end

  test "rejects missing access token" do
    assert {:error, "access token is required"} = Config.load([], fn _ -> nil end)
  end

  test "caps score count at 12" do
    assert {:error, "score count cannot be higher than 12"} =
             Config.load(["--access-token", "token", "--score-count", "13"], fn _ -> nil end)
  end
end
