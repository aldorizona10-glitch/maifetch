// LLM-assisted development: OpenAI GPT-5 Codex
namespace Maifetch

open System
open System.Net.Http
open System.Net.Http.Headers
open System.Text.Json

type MaiteaClient(accessToken: string, ?httpClient: HttpClient) =
    let baseUrl = Uri("https://maitea.app")
    let client = defaultArg httpClient (new HttpClient())
    let jsonOptions = JsonSerializerOptions(PropertyNameCaseInsensitive = true)

    member _.GetJson<'T>(path: string) =
        async {
            use request = new HttpRequestMessage(HttpMethod.Get, Uri(baseUrl, path))
            request.Headers.Authorization <- AuthenticationHeaderValue("Bearer", accessToken)
            request.Headers.Accept.Add(MediaTypeWithQualityHeaderValue("application/json"))
            let! response = client.SendAsync(request) |> Async.AwaitTask
            response.EnsureSuccessStatusCode() |> ignore
            let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
            return JsonSerializer.Deserialize<'T>(body, jsonOptions)
        }

    member this.GetProfiles() =
        async {
            let! result = this.GetJson<ApiData<Profile list>>("/api/v1/profiles")
            return result.Data
        }

    member this.GetPlays() =
        async {
            let! result = this.GetJson<ApiData<Play list>>("/api/v1/plays")
            return result.Data
        }

    member this.GetTracks() =
        async {
            let! result = this.GetJson<ApiData<TrackInfo list>>("/api/v1/tracks")
            return result.Data
        }

    member this.Status() =
        this.GetJson<Status>("/api/status")
