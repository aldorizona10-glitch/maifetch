defmodule Maifetch.RenderTest do
  use ExUnit.Case, async: true

  alias Maifetch.Render

  test "normalizes full-width ASCII characters" do
    assert Render.wide_to_normal("ＡＢＣ１２３！") == "ABC123!"
  end

  test "maps difficulty and rank labels" do
    assert Render.difficulty_string("remaster") == "Re:MASTER"
    assert Render.rank_string("sssp") == "SSS+"
    assert Render.rank_string("wat") == "UNKNOWN"
  end

  test "renders profile and recent score lines" do
    profile = %{
      "id" => 7,
      "name" => "Ｍａｉ",
      "rating" => 1234,
      "rating_highest" => 1300,
      "level" => 8,
      "play_stats" => %{"total" => 44},
      "options" => %{"icon" => %{"png" => "https://example.com/icon.png"}}
    }

    plays = [
      %{
        "song" => %{"name" => %{"en" => "Song"}},
        "difficulty_level" => %{"value" => "master"},
        "score_formatted" => "1,000,000",
        "achievement_formatted" => "100.0000",
        "rank" => "sss",
        "full_combo_label" => "FC"
      }
    ]

    output = Render.output(profile, plays, 0, 1)
    assert output =~ "Mai"
    assert output =~ "12.34 / 13.00"
    assert output =~ "Song  MASTER"
    assert output =~ "SSS FC"
  end
end
