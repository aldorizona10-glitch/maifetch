// LLM-assisted development: OpenAI GPT-5 Codex
namespace Maifetch

open System.Text.Json.Serialization

type Image =
    { [<JsonPropertyName("id")>]
      Id: int
      [<JsonPropertyName("png")>]
      Png: string
      [<JsonPropertyName("webp")>]
      Webp: string }

type NamedText =
    { [<JsonPropertyName("en")>]
      En: string
      [<JsonPropertyName("jp")>]
      Jp: string }

type TrackInfo =
    { [<JsonPropertyName("id")>]
      Id: int
      [<JsonPropertyName("code")>]
      Code: string
      [<JsonPropertyName("name")>]
      Name: NamedText
      [<JsonPropertyName("artist")>]
      Artist: NamedText }

type PlayStats =
    { [<JsonPropertyName("total")>]
      Total: int
      [<JsonPropertyName("wins")>]
      Wins: int
      [<JsonPropertyName("vs")>]
      Vs: int
      [<JsonPropertyName("sync")>]
      Sync: int }

type ProfileOptions =
    { [<JsonPropertyName("icon")>]
      Icon: Image }

type Profile =
    { [<JsonPropertyName("id")>]
      Id: int
      [<JsonPropertyName("name")>]
      Name: string
      [<JsonPropertyName("rating")>]
      Rating: int
      [<JsonPropertyName("rating_highest")>]
      RatingHighest: int
      [<JsonPropertyName("level")>]
      Level: int
      [<JsonPropertyName("play_stats")>]
      PlayStats: PlayStats
      [<JsonPropertyName("options")>]
      Options: ProfileOptions }

type DifficultyLevel =
    { [<JsonPropertyName("key")>]
      Key: int
      [<JsonPropertyName("value")>]
      Value: string
      [<JsonPropertyName("label")>]
      Label: string }

type Play =
    { [<JsonPropertyName("id")>]
      Id: int
      [<JsonPropertyName("achievement_formatted")>]
      AchievementFormatted: string
      [<JsonPropertyName("score_formatted")>]
      ScoreFormatted: string
      [<JsonPropertyName("rank")>]
      Rank: string
      [<JsonPropertyName("full_combo_label")>]
      FullComboLabel: string option
      [<JsonPropertyName("difficulty_level")>]
      DifficultyLevel: DifficultyLevel
      [<JsonPropertyName("song")>]
      Song: TrackInfo }

type ApiData<'T> =
    { [<JsonPropertyName("data")>]
      Data: 'T }

type StatusDb =
    { [<JsonPropertyName("status")>]
      Status: string
      [<JsonPropertyName("query_time")>]
      QueryTime: string }

type StatusWebui =
    { [<JsonPropertyName("api")>]
      Api: string
      [<JsonPropertyName("db_read")>]
      DbRead: StatusDb
      [<JsonPropertyName("db_write")>]
      DbWrite: StatusDb }

type StatusGame =
    { [<JsonPropertyName("status")>]
      Status: string }

type Status =
    { [<JsonPropertyName("webui")>]
      Webui: StatusWebui
      [<JsonPropertyName("game")>]
      Game: StatusGame
      [<JsonPropertyName("last_updated")>]
      LastUpdated: int64 }
