// LLM-assisted development: OpenAI GPT-5 Codex
namespace Maifetch

open System
open System.IO
open System.Text.Json
open System.Text.Json.Serialization

type Config =
    { [<JsonPropertyName("accessToken")>]
      AccessToken: string
      [<JsonPropertyName("scoreCount")>]
      ScoreCount: int
      [<JsonPropertyName("logoSize")>]
      LogoSize: int
      ConfigFile: string }

module Config =
    let private defaults =
        { AccessToken = ""
          ScoreCount = 4
          LogoSize = 20
          ConfigFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "maifetch.json") }

    let private env names =
        names
        |> List.tryPick (fun name ->
            let value = Environment.GetEnvironmentVariable(name)
            if String.IsNullOrWhiteSpace value then None else Some value)

    let private parseInt value =
        match Int32.TryParse value with
        | true, parsed -> Some parsed
        | false, _ -> None

    let private applyConfigFile path config =
        if File.Exists path then
            use doc = JsonDocument.Parse(File.ReadAllText path)
            let root = doc.RootElement

            let stringProp name fallback =
                match root.TryGetProperty name with
                | true, value when value.ValueKind = JsonValueKind.String && not (String.IsNullOrWhiteSpace(value.GetString())) -> value.GetString()
                | _ -> fallback

            let intProp name fallback =
                match root.TryGetProperty name with
                | true, value when value.ValueKind = JsonValueKind.Number ->
                    match value.TryGetInt32() with
                    | true, parsed -> parsed
                    | false, _ -> fallback
                | _ -> fallback

            { config with
                AccessToken = stringProp "accessToken" config.AccessToken
                ScoreCount = intProp "scoreCount" config.ScoreCount
                LogoSize = intProp "logoSize" config.LogoSize
                ConfigFile = path }
        else
            { config with ConfigFile = path }

    let private parseArgs (args: string[]) =
        let rec loop index config =
            if index >= args.Length then
                config
            else
                let nextValue () =
                    if index + 1 >= args.Length then "" else args[index + 1]

                match args[index] with
                | "--access-token" | "-a" | "-t" -> loop (index + 2) { config with AccessToken = nextValue () }
                | "--logo-size" | "-l" ->
                    loop (index + 2) { config with LogoSize = parseInt (nextValue ()) |> Option.defaultValue config.LogoSize }
                | "--score-count" | "-s" ->
                    loop (index + 2) { config with ScoreCount = parseInt (nextValue ()) |> Option.defaultValue config.ScoreCount }
                | "--config-file" | "-c" -> loop (index + 2) { config with ConfigFile = nextValue () }
                | "--help" | "-h" ->
                    printfn "Usage: maifetch [--access-token TOKEN] [--logo-size SIZE] [--score-count COUNT] [--config-file FILE]"
                    exit 0
                | _ -> loop (index + 1) config

        loop 0 defaults

    let load args =
        let cliOnly = parseArgs args
        let configPath =
            env [ "MAITEA_CONFIG_FILE"; "MAIFETCH_CONFIG_FILE" ]
            |> Option.defaultValue cliOnly.ConfigFile

        let config =
            defaults
            |> applyConfigFile configPath

        let withEnv =
            { config with
                AccessToken = env [ "MAITEA_TOKEN"; "MAIFETCH_TOKEN" ] |> Option.defaultValue config.AccessToken
                ConfigFile = configPath
                ScoreCount =
                    env [ "MAITEA_SCORE_COUNT"; "MAIFETCH_SCORE_COUNT" ]
                    |> Option.bind parseInt
                    |> Option.defaultValue config.ScoreCount
                LogoSize =
                    env [ "MAITEA_LOGO_SIZE"; "MAIFETCH_LOGO_SIZE" ]
                    |> Option.bind parseInt
                    |> Option.defaultValue config.LogoSize }

        let merged =
            { withEnv with
                AccessToken = if String.IsNullOrWhiteSpace cliOnly.AccessToken then withEnv.AccessToken else cliOnly.AccessToken
                ScoreCount = if cliOnly.ScoreCount = defaults.ScoreCount then withEnv.ScoreCount else cliOnly.ScoreCount
                LogoSize = if cliOnly.LogoSize = defaults.LogoSize then withEnv.LogoSize else cliOnly.LogoSize
                ConfigFile = configPath }

        if String.IsNullOrWhiteSpace merged.AccessToken then
            Error "access token is required"
        elif merged.ScoreCount > 12 then
            Error "score count cannot be higher than 12"
        else
            Ok merged
