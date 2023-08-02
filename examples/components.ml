module Xs = Hex_ui.Xstream
module Dom = Hex_ui.Dom
module Run = Hex_ui.Run
module Attrs = Hex_ui.Attrs
module Events = Hex_ui.Events
module Effect = Hex_ui.Effect

(*
  First method of composition: components that return a dom_source, and an event_source.
  In this case we have a text_input component that encapsulates it's own input value state.
  It uses `Xstream.with_latest_on` to expose that to the parent only after the input change
  event has been triggered. This pattern is useful useful for any sort of components that have
  internal state, that they only wish to pass upwards after some "submit event" has occurred
*)
let text_input ~tag dom_source _effect_source =
  let input_tag, input_events = Events.create_tag dom_source tag in
  let input_value = input_events |> Events.on_input' in
  let input_blurred =
    input_value
    |> Xs.with_latest_on (Events.on_change' input_events) 
    |> Xs.map (fun (_, value) -> value)
  in
  let dom =
    input_value |> Xs.start_with ""
    |> Xs.map (fun v ->
           Dom.input [ input_tag; Attrs.type_ "text"; Attrs.value v ] [||])
  in
  (dom, input_blurred)

type msg = FirstNameChanged of string | LastNameChanged of string
type state = { first_name : string; last_name : string }

let app dom_source effect_source =
  let initial_state : state = { first_name = ""; last_name = "" } in
  let first_name_input, first_name_events =
    text_input ~tag:"first-name" dom_source effect_source
  in
  let last_name_input, last_name_events =
    text_input ~tag:"last-name" dom_source effect_source
  in
  let state =
    Xs.merge
      (first_name_events |> Xs.map (fun v -> FirstNameChanged v))
      (last_name_events |> Xs.map (fun v -> LastNameChanged v))
    |> Xs.fold
         (fun s msg ->
           match msg with
           | FirstNameChanged v -> { s with first_name = v }
           | LastNameChanged v -> { s with last_name = v })
         initial_state
  in
  let dom =
    Xs.combine first_name_input last_name_input
    |> Xs.flat_map (fun (first_name, second_name) ->
           state
           |> Xs.map (fun s ->
                  Dom.div []
                    [|
                      Dom.h1 [] [| Dom.text "Hello" |];
                      Dom.p [] [| Dom.text (s.first_name ^ " " ^ s.last_name) |];
                      Dom.div [] [| first_name |];
                      Dom.div [] [| second_name |];
                    |]))
  in
  { Run.dom; effects = Xs.empty () }
