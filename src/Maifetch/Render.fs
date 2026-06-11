// LLM-assisted development: OpenAI GPT-5 Codex
namespace Maifetch

open System

module Render =
    let private esc = "\u001b["

    let rgb fgR fgG fgB bgR bgG bgB text =
        $"{esc}38;2;{fgR};{fgG};{fgB};48;2;{bgR};{bgG};{bgB}m{text}{esc}0m"

    let fg r g b text =
        $"{esc}38;2;{r};{g};{b}m{text}{esc}0m"

    let colour text = fg 72 184 200 text

    let wideToNormal (text: string) =
        text
        |> Seq.map (fun ch ->
            let code = int ch
            if code >= 0xFF01 && code <= 0xFF5E then char (code - 0xFEE0) else ch)
        |> Seq.toArray
        |> String

    let difficulty value =
        match value with
        | "easy" -> rgb 255 255 255 69 174 255 "Easy"
        | "basic" -> rgb 255 255 255 111 212 61 "Basic"
        | "advanced" -> rgb 255 255 255 248 183 9 "Advanced"
        | "expert" -> rgb 255 255 255 255 46 66 "Expert"
        | "master" -> rgb 255 255 255 171 140 233 "Master"
        | "remaster"
        | "re:master" -> rgb 255 255 255 207 114 237 "Re:Master"
        | "utage" -> rgb 255 255 255 255 68 1 "Utage"
        | other -> other

    let rank value =
        match value with
        | "SSS+" -> fg 255 200 54 "S" + fg 225 38 165 "S" + fg 73 64 233 "S" + fg 21 203 148 "+"
        | "SSS" -> fg 255 200 54 "S" + fg 232 39 148 "S" + fg 18 195 144 "S"
        | "SS+" -> rgb 248 200 75 143 71 33 "SS+"
        | "SS" -> rgb 248 200 75 143 71 33 "SS"
        | "S+" -> rgb 248 200 75 75 82 82 "S+"
        | "S" -> rgb 248 200 75 75 82 82 "S"
        | "AAA" -> fg 23 163 255 "AAA"
        | "AA" -> fg 23 163 255 "AA"
        | "A" -> fg 23 163 255 "A"
        | other -> other

    let infoLines profile plays scoreCount =
        let name = wideToNormal profile.Name
        let idLabel = colour "ID"
        let ratingLabel = colour "Rating"
        let levelLabel = colour "Level"
        let creditsLabel = colour "Total Credits"
        let scoresLabel = colour "Recent Scores"
        let scoreLines =
            plays
            |> List.truncate scoreCount
            |> List.collect (fun play ->
                let fc = play.FullComboLabel |> Option.defaultValue ""
                [ $"  {play.Song.Name.En}  {difficulty play.DifficultyLevel.Value}"
                  $"  {play.ScoreFormatted} {play.AchievementFormatted}%% {rank play.Rank} {fc}"
                  "" ])

        [ colour name
          String.replicate name.Length "-"
          $"{idLabel}: {profile.Id}"
          $"{ratingLabel}: {float profile.Rating / 100.0:F2} / {float profile.RatingHighest / 100.0:F2}"
          $"{levelLabel}: {profile.Level}"
          $"{creditsLabel}: {profile.PlayStats.Total}"
          $"{scoresLabel}:" ]
        @ scoreLines

    let printText profile plays scoreCount =
        infoLines profile plays scoreCount
        |> String.concat Environment.NewLine
        |> printfn "%s"
