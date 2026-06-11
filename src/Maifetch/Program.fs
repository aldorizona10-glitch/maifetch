// LLM-assisted development: OpenAI GPT-5 Codex
namespace Maifetch

open System

module Program =
    [<EntryPoint>]
    let main argv =
        match Config.load argv with
        | Error message ->
            printfn "%s" message
            1
        | Ok config ->
            try
                let client = MaiteaClient(config.AccessToken)
                let profiles = client.GetProfiles() |> Async.RunSynchronously

                match profiles with
                | [] ->
                    printfn "No profiles found"
                    0
                | profile :: _ ->
                    let plays = client.GetPlays() |> Async.RunSynchronously
                    Render.printText profile plays config.ScoreCount
                    0
            with ex ->
                printfn "%s" ex.Message
                1
