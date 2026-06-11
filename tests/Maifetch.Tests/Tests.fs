// LLM-assisted development: OpenAI GPT-5 Codex
module Maifetch.Tests

open System
open Maifetch

let private assertEqual expected actual =
    if not (Object.Equals(expected, actual)) then
        failwithf "expected %A but got %A" expected actual

let testWideConversion () =
    assertEqual "ABC123" (Render.wideToNormal "ＡＢＣ１２３")

let testDifficultyLabels () =
    if not ((Render.difficulty "expert").Contains("Expert")) then
        failwith "expert label missing"
    assertEqual "unknown" (Render.difficulty "unknown")

let testMissingTokenValidation () =
    match Config.load [||] with
    | Error "access token is required" -> ()
    | other -> failwithf "unexpected config result: %A" other

let testCliPrecedence () =
    match Config.load [| "--access-token"; "abc"; "--score-count"; "3"; "--logo-size"; "-1" |] with
    | Ok config ->
        assertEqual "abc" config.AccessToken
        assertEqual 3 config.ScoreCount
        assertEqual -1 config.LogoSize
    | Error message -> failwith message

[<EntryPoint>]
let main _ =
    testWideConversion ()
    testDifficultyLabels ()
    testMissingTokenValidation ()
    testCliPrecedence ()
    printfn "Maifetch.Tests passed"
    0
