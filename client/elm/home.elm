module Home exposing (Model, Msg(..), init, main, update, view, viewHead)

import Array exposing (Array)
import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as D exposing (Decoder)
import Json.Encode as E


type Msg
    = UpdateQuery String
    | PerformSearch
    | GotSearchResults (Result Http.Error (Array Searchres))
    | Togglewatch Int
    | UpdateEmail String
    | ConfirmEmail
    | ShowOverlay (Maybe String)
    | HideOverlay



-- | GotExamples (Result Http.Error (Array Searchres))


type alias Model =
    { state : LoadState
    , query : String
    , login : LoginState
    , overlay : OverlayState
    , selectedCourse : Maybe Int
    }


type OverlayState
    = OverlayVisible String (Maybe String)
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

    -- , timefrom : String
    , time : String
    , places : Places

    -- , watching : Bool
    , state : Sresstate
    }


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
                [ viewHead True model.login, viewBody model.state ]
            ]
        ]


viewHead : Bool -> LoginState -> Html Msg
viewHead showExplaination login =
    let
        loggedInHtml =
            case login of
                LoggedIn email ->
                    [ span [ class "fade-msg" ] [ text "Eingeloggt!" ]
                    , span [ class "email", title "Ausloggen" ]
                        [ i [ class "fas fa-sign-out-alt" ] []
                        , text email
                        ]
                    ]

                _ ->
                    [ span [ class "login-link", onClick (ShowOverlay Nothing) ] [ text "Login" ] ]
    in
    div [ class "head" ]
        [ div [ class "logo" ] <|
            [ h1 [ class "head-usi" ] [ text "USI" ]
            , h3 [ class "head-watch" ] [ text "watch" ]
            ]
                ++ loggedInHtml
        , p [ class "expl-bold" ] [ text "Willkommen bei USIWatch." ]
        , p [ class "expl-text" ] [ text "Hier kannst du nach Kursen des USI Graz suchen und dich benachrichtigen lassen, wenn Plätze frei werden." ]
        ]


viewBody : LoadState -> Html Msg
viewBody lstate =
    div [ class "body" ]
        [ Html.form [ class "searchbarform", onSubmit PerformSearch ]
            [ input
                [ class "themed"
                , onInput UpdateQuery
                , type_ "text"
                , placeholder "Suche nach Kursname, ID ..."
                , autofocus True
                , autocomplete True
                ]
                []
            ]
        , div [ class "searchresultswrapper" ]
            (viewSearchresults lstate)
        , span [ class "signature" ] [ text "Filippo Orru, 2019" ]
        ]


viewOverlay : OverlayState -> LoginState -> Html Msg
viewOverlay ostate lstate =
    case ostate of
        OverlayVisible email maybeerr ->
            div [ class "oflwrap overlay-bg" ]
                [ div [ class "overlay-window" ]
                    [ div [ class "overlay-head" ]
                        [ h2 [ class "overlay-title" ] [ text "Kurs zur Watchlist hinzufügen" ]
                        , span [ onClick HideOverlay, class "overlay-close hoverbtn" ] [ i [ class "fas fa-times" ] [] ]
                        ]

                    -- , hr [] []
                    , span [ class "overlay-body" ] [ text "Wir benachrichtigen dich per Email, wenn der Kurs wieder frei wird." ]
                    , Html.form [ onSubmit ConfirmEmail ]
                        [ input
                            [ class "overlay-input themed"
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
                ]

        _ ->
            text ""


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

        resultbtn title_ faclass =
            a [ onClick (Togglewatch index), class "result-btn", title title_ ] [ i [ class <| "result-btn-icon " ++ faclass ] [] ]

        actionBtn =
            if sresult.places.free == 0 then
                case sresult.state of
                    Sresselected ->
                        resultbtn "Von Watchlist entfernen" "far fa-minus-square"

                    Sresunselected ->
                        resultbtn "Zur Watchlist hinzufügen" "far fa-plus-square"

                    Sresload ->
                        resultbtn "" "fas fa-spinner"

                    Sreserror err ->
                        resultbtn "Fehler!" "fas fa-times"

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
    case msg of
        UpdateQuery query ->
            ( { model | query = query }, Cmd.none )

        PerformSearch ->
            ( { model | state = LBusy }, performsearch model.query )

        GotSearchResults result ->
            case result of
                Ok arr ->
                    ( { model | state = LSuccess arr }, Cmd.none )

                Err err ->
                    ( { model | state = LErr err }, Cmd.none )

        UpdateEmail email ->
            ( { model | overlay = OverlayVisible email Nothing }, Cmd.none )

        ConfirmEmail ->
            case model.overlay of
                OverlayVisible email _ ->
                    if validEmail email then
                        ( { model | login = LoggedIn email, overlay = OverlayHidden }, Cmd.none )

                    else
                        update (ShowOverlay (Just "Keine gültige Email!")) model

                _ ->
                    ( model, Cmd.none )

        Togglewatch index ->
            case model.login of
                LoggedIn email ->
                    case model.state of
                        LSuccess sres ->
                            case Array.get index sres of
                                Just res ->
                                    let
                                        newres =
                                            if res.state == Sresunselected then
                                                { res | state = Sresselected }

                                            else
                                                { res | state = Sresunselected }

                                        newsres =
                                            Array.set index newres sres

                                        -- |> Debug.log "newsres pressed btn"
                                    in
                                    ( { model | state = LSuccess newsres }, Cmd.none )

                                _ ->
                                    ( model, Cmd.none )

                        _ ->
                            ( model, Cmd.none )

                Guest ->
                    update (ShowOverlay Nothing) { model | selectedCourse = Just index }

        ShowOverlay mbs ->
            ( { model | overlay = OverlayVisible "" mbs }, Cmd.none )

        HideOverlay ->
            ( { model | overlay = OverlayHidden }, Cmd.none )



-- GotExamples result ->
--     case result of
--         Ok arr ->
--             ({model | state = LSuccess arr }, Cmd.none )
--         Err err ->
--             ({ model | state = LErr err}, Cmd.none)


getExamples =
    Http.get
        { url = "/api/examples"
        , expect = Http.expectJson GotSearchResults decodeSearchresults
        }


performsearch query =
    Http.get
        { url = "/api/search/" ++ query

        -- https://usionline.uni-graz.at/usiweb/myusi.kurse?suche_in=go&sem_id_in=2019W&kursnr_in="
        , expect = Http.expectJson GotSearchResults decodeSearchresults
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
            -- (D.succeed False)
            (D.succeed Sresunselected)
        )


decodePlaces : Decoder Places
decodePlaces =
    D.map Places
        (D.field "free" D.int)



-- (D.field "total" D.int)


validEmail email =
    String.contains "@" email && String.length email /= 0 && String.contains "." email



-- _ ->
--     ( model, Cmd.none )
