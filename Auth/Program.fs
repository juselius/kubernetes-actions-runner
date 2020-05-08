module RunnerToken

open System
open Octokit
open GitHubJwt
open Thoth.Json.Net
open FSharp.Data
open Argu

type GHApp = {
    PrivateKeyPath : string
    AppId : int
    InstallationId : int
    Owner : string
}

type AuthSettings = {
    App : GHApp option
    PersonalAccessToken : string option
}

type RunnerToken = {
    Token : string
    ExpiresAt : string
}

type Arguments =
    | Token
    | Repository of repo:string
    | [<Mandatory>] Config of path:string
with
    interface IArgParserTemplate with
        member this.Usage =
            match this with
            | Token -> "use personal access token"
            | Repository _-> "repository"
            | Config _ -> "config file"

let readSettings file =
    let json = IO.File.ReadAllText file
    match Decode.Auto.fromString<AuthSettings> json with
    | Ok s -> s
    | Error e -> failwith e

let getJwtToken conf =
    let key = FilePrivateKeySource conf.PrivateKeyPath
    let opts = GitHubJwtFactoryOptions ()
    opts.AppIntegrationId <- conf.AppId
    opts.ExpirationSeconds <- 600
    let gen = GitHubJwtFactory (key, opts)
    gen.CreateEncodedJwtToken ()

let appClient conf =
    let jwtToken = getJwtToken conf
    let client = GitHubClient (ProductHeaderValue("ActionsRunner"))
    client.Credentials <- Credentials(jwtToken, AuthenticationType.Bearer)
    client

let apiUrl x =
    sprintf "https://api.github.com/%s/actions/runners/registration-token" x

let getAppRunnerToken conf repo =
    let token =
        let iid = conf.InstallationId |> int64
        let client = appClient conf
        client.GitHubApps.CreateInstallationToken iid
        |> Async.AwaitTask
        |> Async.RunSynchronously
    let url =
        match repo with
        | Some r -> "repos/" + r |> apiUrl
        | None -> "orgs/" + conf.Owner |> apiUrl
    let resp =
        Http.RequestString (
            url = url,
            httpMethod = "POST",
            headers = [
                "Authorization", "token " + token.Token
                "User-Agent", "Octocat-App"
            ]
        )
    let resp' =
        Decode.Auto.fromString<RunnerToken> (resp, caseStrategy = SnakeCase)
    match resp' with
    | Ok x ->  x.Token
    | Error e -> failwith e

let getPatRunnerToken token repo =
    let url = "repos/" + repo |> apiUrl
    let resp =
        Http.RequestString (
            url = url,
            httpMethod = "POST",
            headers = [
                "Authorization", "token " + token
                "User-Agent", "Octocat-App"
            ]
        )
    let resp' =
        Decode.Auto.fromString<RunnerToken> (resp, caseStrategy = SnakeCase)
    match resp' with
    | Ok x ->  x.Token
    | Error e -> failwith e

let colorizer =
    function
    | ErrorCode.HelpText -> None
    | _ -> Some ConsoleColor.Red

let errorHandler = ProcessExiter (colorizer = colorizer )

[<EntryPoint>]
let main argv =
    let parser =
        ArgumentParser.Create<Arguments>(
            programName = "GetRunnerToken",
            errorHandler = errorHandler
        )
    let args = parser.Parse argv
    let configFile = args.GetResult (Config, defaultValue = "auth.json")
    let settings = readSettings configFile
    let repo = args.TryGetResult Repository
    match args.TryGetResult Token with
    | Some _ ->
        let pat = settings.PersonalAccessToken
        match pat, repo with
        | Some t, Some r ->  printfn "%s" (getPatRunnerToken t r)
        | _ ->
            if repo.IsNone then
                args.Raise "No repository given."
            else
                "PersonalAccessToken missing in " + configFile |> args.Raise
    | None ->
        match settings.App with
        | Some conf ->
            printfn "%s" (getAppRunnerToken conf repo)
        | None -> "App section missing in " + configFile |> args.Raise
    0
