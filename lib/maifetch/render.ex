defmodule Maifetch.Render do
  @moduledoc false

  def colour(value), do: IO.ANSI.color(72, 184, 200) <> value <> IO.ANSI.reset()

  def wide_to_normal(value) do
    value
    |> String.to_charlist()
    |> Enum.map(fn code -> if code >= 0xFF01 and code <= 0xFF5E, do: code - 0xFEE0, else: code end)
    |> List.to_string()
  end

  def difficulty_string(value) do
    %{
      "basic" => "BASIC",
      "advanced" => "ADVANCED",
      "expert" => "EXPERT",
      "master" => "MASTER",
      "remaster" => "Re:MASTER"
    }
    |> Map.get(value, "UNKNOWN")
  end

  def rank_string(value) do
    %{
      "d" => "D",
      "c" => "C",
      "b" => "B",
      "bb" => "BB",
      "bbb" => "BBB",
      "a" => "A",
      "aa" => "AA",
      "aaa" => "AAA",
      "s" => "S",
      "sp" => "S+",
      "ss" => "SS",
      "ssp" => "SS+",
      "sss" => "SSS",
      "sssp" => "SSS+"
    }
    |> Map.get(value, "UNKNOWN")
  end

  def info_lines(profile, plays, score_count) do
    name = profile |> get_in(["name"]) |> to_string() |> wide_to_normal()

    base = [
      colour(name),
      String.duplicate("-", String.length(name)),
      "#{colour("ID")}: #{profile["id"]}",
      "#{colour("Rating")}: #{rating(profile["rating"])} / #{rating(profile["rating_highest"])}",
      "#{colour("Level")}: #{profile["level"]}",
      "#{colour("Total Credits")}: #{get_in(profile, ["play_stats", "total"])}",
      "#{colour("Recent Scores")}:"
    ]

    scores =
      plays
      |> Enum.take(score_count)
      |> Enum.flat_map(fn play ->
        fc_label = play["full_combo_label"] || ""
        song_name = get_in(play, ["song", "name", "en"]) || "Unknown"
        difficulty = play |> get_in(["difficulty_level", "value"]) |> difficulty_string()
        rank = play |> Map.get("rank") |> rank_string()

        [
          "  #{song_name}  #{difficulty}",
          "  #{play["score_formatted"]} #{play["achievement_formatted"]}% #{rank} #{fc_label}",
          ""
        ]
      end)

    base ++ scores
  end

  def output(profile, plays, logo_size, score_count) do
    lines = info_lines(profile, plays, score_count)

    if logo_size > 0 do
      profile
      |> get_in(["options", "icon", "png"])
      |> ascii_logo(logo_size)
      |> print_combined(lines, logo_size)
    else
      Enum.join(lines, "\n")
    end
  end

  defp rating(nil), do: "0.00"
  defp rating(value) when is_integer(value), do: :io_lib.format("~.2f", [value / 100]) |> IO.iodata_to_binary()
  defp rating(value) when is_float(value), do: :io_lib.format("~.2f", [value / 100]) |> IO.iodata_to_binary()
  defp rating(value), do: rating(String.to_integer(to_string(value)))

  defp ascii_logo(_url, size) do
    width = max(size * 2, 1)
    height = max(size, 1)
    label = "MaiTea"
    pad = max(div(width - String.length(label), 2), 0)
    middle = String.duplicate(" ", pad) <> label

    Enum.map(1..height, fn row ->
      if row == div(height, 2) + 1 do
        String.pad_trailing(middle, width)
      else
        String.duplicate(" ", width)
      end
    end)
  end

  defp print_combined(logo_lines, info_lines, logo_size) do
    max_len = max(length(logo_lines), length(info_lines))
    blank_logo = String.duplicate(" ", max(logo_size * 2, 0))

    0..(max_len - 1)
    |> Enum.map(fn idx ->
      logo = Enum.at(logo_lines, idx, blank_logo)
      info = Enum.at(info_lines, idx, "")
      "#{logo}  #{info}"
    end)
    |> Enum.join("\n")
  end
end
