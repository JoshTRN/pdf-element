port module Main exposing (..)

import Browser as B
import Element as E
import Element.Background as EBg
import Element.Border as EB
import Element.Font as EF
import Element.Input as EI
import File exposing (File)
import File.Select as FS
import Html exposing (Html)
import Html.Attributes as HA
import Json.Decode as JD
import Json.Encode as JE
import Pdf
import Task


type alias Model =
    { show : Bool
    , pdfName : Maybe String
    }


type Msg
    = ShowHide
    | OpenClick
    | LoadClick
    | PdfOpened File
    | PdfExtracted String
    | PdfMsg (Result JD.Error Pdf.PdfMsg)


port sendPdfCommand : JE.Value -> Cmd msg


pdfsend : Pdf.PdfCmd -> Cmd Msg
pdfsend =
    Pdf.send sendPdfCommand


port receivePdfMsg : (JD.Value -> msg) -> Sub msg


pdfreceive : Sub Msg
pdfreceive =
    receivePdfMsg <| Pdf.receive PdfMsg


url : String
url =
    "https://raw.githubusercontent.com/mozilla/pdf.js/ba2edeae/examples/learning/helloworld.pdf"


buttonStyle =
    [ EBg.color <| E.rgb 0.1 0.1 0.1
    , EF.color <| E.rgb 1 1 0
    , EB.color <| E.rgb 1 0 1
    , E.paddingXY 10 10
    , EB.rounded 3
    ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ShowHide ->
            ( { model | show = not model.show }, Cmd.none )

        LoadClick ->
            ( model, pdfsend <| Pdf.OpenUrl { name = "blah", url = url } )

        OpenClick ->
            ( model, FS.file [ "application/pdf" ] PdfOpened )

        PdfOpened file ->
            ( model, Task.perform PdfExtracted (File.toUrl file) )

        PdfExtracted string ->
            case String.split "base64," string of
                [ a, b ] ->
                    ( model, pdfsend <| Pdf.OpenString { name = "blah", string = b } )

                _ ->
                    ( model, Cmd.none )

        PdfMsg ms ->
            let
                _ =
                    Debug.log "pdfmsg: " ms
            in
            case ms of
                Ok (Pdf.Loaded lm) ->
                    ( { model | pdfName = Just lm.name }, Cmd.none )

                Ok (Pdf.Error e) ->
                    ( model, Cmd.none )

                Err e ->
                    ( model, Cmd.none )


view : Model -> Html Msg
view model =
    E.layout
        []
    <|
        E.column [ E.spacing 5 ]
            [ E.text "greetings from elm"
            , EI.button buttonStyle { label = E.text "open pdf", onPress = Just OpenClick }
            , EI.button buttonStyle { label = E.text "load pdf", onPress = Just LoadClick }
            , EI.button buttonStyle { label = E.text "show/hide", onPress = Just ShowHide }
            , case model.pdfName of
                Just name ->
                    if model.show then
                        E.column []
                            [ E.el [ E.width <| E.px 800, E.height <| E.px 800, EB.width 5 ] <|
                                E.html <|
                                    Html.node "pdf-element" [ HA.attribute "name" name ] []
                            , E.text name
                            ]

                    else
                        E.none

                Nothing ->
                    E.none
            ]


type alias Flags =
    ()


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { show = True, pdfName = Nothing }, Cmd.none )


main : Program Flags Model Msg
main =
    B.element
        { init = init
        , subscriptions = \_ -> pdfreceive
        , view = view
        , update = update
        }
