module Home exposing (Model, Msg(..), init, main, update, view, viewHead)

import Array exposing (Array)
import Browser
import Browser.Dom as Dom
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as D exposing (Decoder)
import Json.Decode.Extra as D
import Json.Encode as E
import Task


type Msg
    = UpdateQuery String
    | PerformSearch
    | GetExamples
    | GotSearchResults (Result Http.Error (Array Searchres))
    | PostedWatch Int (Result Http.Error ())
    | PostedUnwatch Int (Result Http.Error ())
    | Togglewatch Int
    | UpdateEmail String
    | ConfirmEmail
    | Logout
    | ShowOverlay (Maybe String) -- is optional error string
    | HideOverlay
    | ToggleMore
    | ToggleDeleteOverlay String
    | ConfirmDelete String
    | DeletedRecords String (Result Http.Error ())
    | NoOp



-- | GotExamples (Result Http.Error (Array Searchres))


type alias Model =
    { state : LoadState
    , query : String
    , login : LoginState
    , overlay : OverlayState
    , selectedCourse : Maybe Int
    , showMore : Bool
    }


type OverlayState
    = EmailoverlayVisible String (Maybe String)
    | CourseconfirmoverlayVisible Int
    | DeleteoverlayVisible String (Maybe String)
    | MessageoverlayVisible String
    | OverlayHidden


type LoginState
    = Guest
    | LoggedIn String



-- | Authenticating String


type LoadState
    = LIdle
    | LBusy
    | LErr Http.Error
    | LSuccess (Array Searchres)


type alias Searchres =
    { id : String
    , name : String
    , link : String
    , time : String
    , places : Places
    , state : Sresstate
    }



-- , watching : Bool
-- , timefrom : String


type Sresstate
    = Sresunselected
    | Sresload
    | Sreserror Http.Error
    | Sresselected


type alias Places =
    { free : Int }



--, total : Int }


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


init : () -> ( Model, Cmd Msg )
init () =
    ( { query = ""
      , state = LIdle
      , login = Guest
      , selectedCourse = Nothing
      , overlay = OverlayHidden
      , showMore = False
      }
    , getExamples
    )


view : Model -> Browser.Document Msg
view model =
    let
        doc html =
            { title = "usiwatch"
            , body = html
            }
    in
    doc
        [ viewOverlay model.overlay model.login
        , div [ class "wrapper oflwrap" ]
            [ div [ class "innerwrapper oflwrap" ]
                [ viewHead True model.login, viewBody model.login model.state model.showMore ]
            ]
        ]


viewHead : Bool -> LoginState -> Html Msg
viewHead showExplaination login =
    let
        loggedInHtml =
            case login of
                LoggedIn email ->
                    [ span [ class "fade-msg" ] [ text "Eingeloggt!" ]
                    , span [ class "email", title "Ausloggen", onClick Logout ]
                        [ i [ class "fas fa-sign-out-alt" ] []
                        , text email
                        ]
                    ]

                _ ->
                    [ span [ class "login-link", onClick (ShowOverlay Nothing) ] [ text "Login" ] ]
    in
    div [ class "head" ]
        [ div [ class "logo-wrapper" ] <|
            [ div [ class "logo", onClick GetExamples ]
                [ h1 [ class "head-usi" ] [ text "USI" ]
                , h3 [ class "head-watch" ] [ text "watch" ]
                ]
            ]
                ++ loggedInHtml
        , p [ class "expl-bold" ] [ text "Willkommen bei USIWatch." ]
        , p [ class "expl-text" ] [ text "Hier kannst du nach Kursen des USI Graz suchen und dich benachrichtigen lassen, wenn Plätze frei werden." ]
        ]


viewBody : LoginState -> LoadState -> Bool -> Html Msg
viewBody loginstate loadstate showMore =
    div [ class "body" ]
        [ Html.form [ class "searchbarform", onSubmit PerformSearch ]
            [ input
                [ class "themed"
                , id "search-box"
                , onInput UpdateQuery
                , type_ "text"
                , placeholder "Suche nach Kursname, ID ..."
                , autofocus True
                , autocomplete True
                ]
                []
            ]
        , div [ class "searchresultswrapper" ]
            (viewSearchresults loadstate)
        , span [ class "signature" ] [ text "Filippo Orru, 2019" ]
        , case loginstate of
            LoggedIn email ->
                if showMore then
                    div [ class "more-wrapper" ]
                        [ span [ onClick ToggleMore, class "more-btn" ] [ text "Weniger anzeigen", i [ class "fas fa-sort-up" ] [] ]
                        , span [ onClick (ToggleDeleteOverlay email), class "delete-btn" ] [ text "Watchlist leeren / Account löschen", i [ class "fas fa-trash" ] [] ]
                        ]

                else
                    span [ onClick ToggleMore, class "more-btn" ] [ text "Mehr anzeigen", i [ class "fas fa-sort-down" ] [] ]

            _ ->
                text ""
        ]


viewOverlay : OverlayState -> LoginState -> Html Msg
viewOverlay ostate lstate =
    let
        overlay head body =
            div [ class "oflwrap overlay-wrapper" ]
                [ div [ class "overlay-window", stopPropagationOn "click" (D.succeed ( NoOp, False )) ]
                    [ div [ class "overlay-head" ]
                        (head ++ [ span [ onClick HideOverlay, class "overlay-close hoverbtn" ] [ i [ class "fas fa-times" ] [] ] ])
                    , div [ class "overlay-body" ] body
                    ]
                , div [ class "overlay-bg", onClick HideOverlay ] []
                ]
    in
    case ostate of
        OverlayHidden ->
            text ""

        EmailoverlayVisible email maybeerr ->
            overlay
                [ h2 [ class "overlay-title" ] [ text "Kurs zur Watchlist hinzufügen" ] ]
                [ text "Über welche Email möchtest du benachrichtigt werden?"
                , Html.form [ onSubmit ConfirmEmail ]
                    [ input
                        [ class "overlay-input themed"
                        , id "email-box"
                        , value email
                        , onInput UpdateEmail
                        , placeholder "deine@tolle.email"
                        , autofocus True
                        , autocomplete True
                        , type_ "email"
                        ]
                        []
                    , button [ class "overlay-btn themed" ] [ text "Yay!" ]
                    ]
                , case maybeerr of
                    Just err ->
                        span [ class "overlay-err" ] [ text err ]

                    Nothing ->
                        text ""
                ]

        CourseconfirmoverlayVisible index ->
            case lstate of
                LoggedIn email ->
                    overlay
                        [ h2 [ class "overlay-title" ] [ text "Bestätige" ] ]
                        [ p [ class "overlay-body-text" ] [ text <| "Möchtest du, wenn beim Kurs per email an " ++ email ++ " benachrichtigt werden?" ] ]

                _ ->
                    overlay [ text "Fehler" ] [ text "das hätte nicht passieren dürfen." ]

        DeleteoverlayVisible email maybeerr ->
            overlay
                [ h2 [ class "overlay-title" ] [ text "Bist du sicher?" ] ]
                [ p [ class "overlay-body-text" ] [ text <| "Möchtest du wirklich alle Einträge für " ++ email ++ " löschen?" ]
                , div [ class "overlay-body-buttons" ]
                    [ button [ onClick HideOverlay, class "themed secondary" ] [ text "Abbrechen" ]
                    , button [ onClick (ConfirmDelete email), class "themed primary red" ] [ text "Löschen" ]
                    ]
                , case maybeerr of
                    Just err ->
                        p [ class "overlay-body-error" ] [ text err ]

                    Nothing ->
                        text ""
                ]

        MessageoverlayVisible msg ->
            div [ class "oflwrap overlay-wrapper" ]
                [ div [ class "overlay-window", stopPropagationOn "click" (D.succeed ( NoOp, False )) ]
                    [ p [ class "overlay-body-text" ] [ text msg ]
                    , button [ onClick HideOverlay, class "themed primary" ] [ text "Okay" ]
                    ]
                , div [ class "overlay-bg", onClick HideOverlay ] []
                ]


viewSearchresults : LoadState -> List (Html Msg)
viewSearchresults lstate =
    case lstate of
        LIdle ->
            [ text "examples" ]

        LBusy ->
            [ span [ class "loadingtext" ] [ text "..." ] ]

        LErr err ->
            [ text "Error occured. Please try again.", p [] [ text <| Debug.toString err ] ]

        LSuccess sresults ->
            case Array.length sresults of
                0 ->
                    viewEmptyResults

                _ ->
                    Array.indexedMap viewResult sresults |> Array.toList


viewEmptyResults : List (Html Msg)
viewEmptyResults =
    [ div [ class "emptyresults" ] [ span [] [ text "No results were found." ] ] ]


viewResult : Int -> Searchres -> Html Msg
viewResult index sresult =
    let
        linkAtt =
            [ rel "noopener", target "_blank", href <| "https://" ++ sresult.link ]

        resultbtn action title_ faclass =
            a (action ++ [ class "result-btn", title title_ ]) [ i [ class <| "result-btn-icon " ++ faclass ] [] ]

        actionBtn =
            if sresult.places.free == 0 then
                case sresult.state of
                    Sresselected ->
                        resultbtn [ onClick <| Togglewatch index ] "Von Watchlist entfernen" "fas fa-bell"

                    Sresunselected ->
                        resultbtn [ onClick <| Togglewatch index ] "Zur Watchlist hinzufügen" "far fa-bell"

                    Sresload ->
                        resultbtn [] "" "fas fa-spinner"

                    Sreserror err ->
                        resultbtn [ onClick <| Togglewatch index ] "Fehler!" "fas fa-times"

            else
                a (linkAtt ++ [ class "result-btn" ]) <| [ i [ class "result-btn-icon fas fa-chevron-right" ] [] ]

        freePlacesText =
            case sresult.places.free of
                0 ->
                    "Keine Plätze frei"

                1 ->
                    "Ein Platz frei"

                _ ->
                    String.fromInt sresult.places.free ++ " Plätze frei"
    in
    div [ class "result" ]
        [ div [ class "result-left" ]
            [ a (linkAtt ++ [ class "result-title", title "In neuem Tab öffnen" ])
                [ text <| sresult.name ++ " (" ++ sresult.id ++ ")"
                , i [ class "fas fa-external-link-square-alt" ] []
                ]
            , span [ class "result-time" ] [ i [ class "far fa-clock" ] [], text <| sresult.time ]
            ]
        , div [ class "result-right" ]
            [ span [ class "result-places" ]
                [ text freePlacesText ]
            , actionBtn
            ]
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        cmdnone m =
            ( m, Cmd.none )
    in
    case msg of
        UpdateQuery query ->
            ( { model | query = query }, Cmd.none )

        PerformSearch ->
            if String.length model.query == 0 then
                update GetExamples model

            else
                case model.login of
                    LoggedIn email ->
                        ( { model | state = LBusy }, performsearch model.query (Just email) )

                    _ ->
                        ( { model | state = LBusy }, performsearch model.query Nothing )

        GetExamples ->
            ( model, getExamples )

        GotSearchResults result ->
            case result of
                Ok arr ->
                    ( { model | state = LSuccess arr }, Cmd.none )

                Err err ->
                    ( { model | state = LErr err }, Cmd.none )

        UpdateEmail email ->
            ( { model | overlay = EmailoverlayVisible email Nothing }, Cmd.none )

        ConfirmEmail ->
            case model.overlay of
                EmailoverlayVisible email _ ->
                    if validEmail email then
                        case model.selectedCourse of
                            Just index ->
                                let
                                    ( tglModel, tglCmd ) =
                                        update HideOverlay { model | login = LoggedIn email, selectedCourse = Nothing }
                                            |> Tuple.first
                                            |> update GetExamples
                                            |> Tuple.first
                                            |> update (Togglewatch index)

                                    message =
                                        "Der Kurs wurde zur Watchlist hinzugefügt. Du wirst benachrichtigt, wenn ein Platz frei wird."
                                in
                                ( { tglModel | overlay = MessageoverlayVisible message }, tglCmd )

                            Nothing ->
                                update GetExamples  { model | login = LoggedIn email }
                                    |> Tuple.first
                                    |> update HideOverlay

                    else
                        update (ShowOverlay (Just "Keine gültige Email!")) model

                _ ->
                    ( model, Cmd.none )

        Logout ->
            cmdnone { model | login = Guest, selectedCourse = Nothing }

        Togglewatch index ->
            case model.login of
                LoggedIn email ->
                    case model.state of
                        LSuccess sres ->
                            case Array.get index sres of
                                Just res ->
                                    case res.state of
                                        Sresunselected ->
                                            if res.places.free == 0 then
                                                toggleWatchRes postWatch model email sres index res

                                            else
                                                cmdnone model

                                        Sresselected ->
                                            toggleWatchRes postUnwatch model email sres index res

                                        Sreserror _ ->
                                            let
                                                newsres =
                                                    Array.set index { res | state = Sresunselected } sres
                                            in
                                            cmdnone { model | state = LSuccess newsres }

                                        Sresload ->
                                            cmdnone model

                                _ ->
                                    cmdnone model

                        _ ->
                            cmdnone model

                Guest ->
                    update (ShowOverlay Nothing) { model | selectedCourse = Just index }

        PostedWatch index result ->
            case model.state of
                LSuccess resarr ->
                    case Array.get index resarr of
                        Just sres ->
                            let
                                newstate =
                                    case result of
                                        Ok _ ->
                                            Sresselected

                                        Err e ->
                                            Sreserror e

                                newresarr =
                                    Array.set index { sres | state = newstate } resarr
                            in
                            cmdnone { model | state = LSuccess newresarr }

                        _ ->
                            cmdnone model

                _ ->
                    cmdnone model

        PostedUnwatch index result ->
            case model.state of
                LSuccess resarr ->
                    case Array.get index resarr of
                        Just sres ->
                            let
                                newstate =
                                    case result of
                                        Ok _ ->
                                            Sresunselected

                                        Err e ->
                                            Sreserror e

                                newresarr =
                                    Array.set index { sres | state = newstate } resarr
                            in
                            cmdnone { model | state = LSuccess newresarr }

                        _ ->
                            cmdnone model

                _ ->
                    cmdnone model

        ShowOverlay mbs ->
            ( { model | overlay = EmailoverlayVisible "" mbs }, Task.attempt (\_ -> NoOp) (Dom.focus "email-box") )

        HideOverlay ->
            ( { model | overlay = OverlayHidden }, Task.attempt (\_ -> NoOp) (Dom.focus "search-box") )

        ToggleMore ->
            ( { model | showMore = not model.showMore }, Cmd.none )

        ToggleDeleteOverlay email ->
            ( { model | overlay = DeleteoverlayVisible email Nothing }, Cmd.none )

        ConfirmDelete email ->
            ( model, deleteRecords email )

        DeletedRecords email result ->
            case result of
                Ok _ ->
                    update GetExamples { model | login = Guest, overlay = OverlayHidden }

                Err _ ->
                    cmdnone { model | login = Guest, overlay = DeleteoverlayVisible email (Just "Konnte Account nicht löschen. Probiere es später erneut") }

        NoOp ->
            cmdnone model


toggleWatchRes : (String -> Searchres -> Int -> Cmd Msg) -> Model -> String -> Array Searchres -> Int -> Searchres -> ( Model, Cmd Msg )
toggleWatchRes cmd model email sres index res =
    let
        newres =
            { res | state = Sresload }

        newsres =
            Array.set index newres sres
    in
    ( { model | state = LSuccess newsres }, cmd email newres index )


getExamples : Cmd Msg
getExamples =
    Http.get
        { url = "/api/examples"
        , expect = Http.expectJson GotSearchResults decodeSearchresults
        }


performsearch : String -> Maybe String -> Cmd Msg
performsearch query maybeemail =
    case maybeemail of
        Just email ->
            Http.request
                { method = "POST"
                , headers = []
                , url = "/api/search/" ++ query
                , body = Http.jsonBody <| E.object [ ( "email", E.string email ) ]
                , expect = Http.expectJson GotSearchResults decodeSearchresults
                , timeout = Nothing
                , tracker = Nothing
                }

        Nothing ->
            Http.get
                { url = "/api/search/" ++ query
                , expect = Http.expectJson GotSearchResults decodeSearchresults
                }


postWatch : String -> Searchres -> Int -> Cmd Msg
postWatch email result index =
    Http.post
        { url = "/api/watch"
        , body = Http.jsonBody (encodeResult email result)
        , expect = Http.expectWhatever (PostedWatch <| index)
        }


postUnwatch : String -> Searchres -> Int -> Cmd Msg
postUnwatch email result index =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/watch"
        , body = Http.jsonBody (encodeResult email result)
        , expect = Http.expectWhatever (PostedUnwatch <| index)
        , timeout = Nothing
        , tracker = Nothing
        }


deleteRecords : String -> Cmd Msg
deleteRecords email =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = "/api/watching"
        , body = Http.jsonBody (E.object [ ( "email", E.string email ) ])
        , expect = Http.expectWhatever (DeletedRecords email)
        , timeout = Nothing
        , tracker = Nothing
        }


decodeSearchresultshttp : msg -> String -> msg
decodeSearchresultshttp msg str =
    msg


decodeSearchresults : Decoder (Array Searchres)
decodeSearchresults =
    -- let
    --     exampleres =
    --         Searchres "test" "10" "11" { 1, 10}
    -- in
    D.array
        (D.map6 Searchres
            (D.field "id" D.string)
            (D.field "name" D.string)
            (D.field "link" D.string)
            (D.field "time" D.string)
            -- (D.field "to" D.string)
            (D.field "places" decodePlaces)
            (D.withDefault Sresunselected (D.field "watching" decodeWatching))
         -- (D.succeed False)
        )


decodeWatching : D.Decoder Sresstate
decodeWatching =
    D.bool
        |> D.andThen
            (\b ->
                if b then
                    D.succeed Sresselected

                else
                    D.succeed Sresunselected
            )


decodePlaces : Decoder Places
decodePlaces =
    D.map Places
        (D.field "free" D.int)


encodeResult : String -> Searchres -> E.Value
encodeResult email res =
    E.object
        [ ( "email", E.string email )
        , ( "id", E.string res.id )
        ]



-- (D.field "total" D.int)


validEmail email =
    String.contains "@" email && String.length email /= 0 && String.contains "." email
