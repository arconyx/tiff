import gleam/dynamic/decode
import gleam/list
import gleam/option
import gleam/string
import lustre
import lustre/attribute.{class}
import lustre/component
import lustre/effect
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import tiff/engine.{type Engine, type ValidChoice}
import tiff/engine/state
import tiff/fiction
import tiff/fiction/validation

pub type HistoryEntry {
  PastText(String)
  SelectedChoice(String)
}

pub type CurrentEntry {
  Story(body: List(String), choices: List(ValidChoice))
  Response(List(String))
}

pub type Model {
  /// The most recent stuff is at the start of the history list
  Model(
    engine: Engine,
    current: CurrentEntry,
    history: List(HistoryEntry),
    error: option.Option(Error),
  )
}

pub type Error {
  EngineError(engine.Error)
}

pub type Message {
  Advance
  Choose(ValidChoice)
  SetFiction(fiction.Fiction)
}

pub type Update =
  #(Model, effect.Effect(Message))

pub fn register() -> Result(Nil, lustre.Error) {
  lustre.component(init, update, view, [
    component.on_property_change(
      "fiction",
      fiction.fiction_decoder() |> decode.map(SetFiction),
    ),
  ])
  |> lustre.register("game-viewer")
}

pub fn element(attributes: List(attribute.Attribute(msg))) -> Element(msg) {
  element.element("game-viewer", attributes, [])
}

fn init(_args: Nil) -> Update {
  let model =
    Model(
      engine: engine.none(),
      // This is a placeholder that will get overwritten when we reset the
      // storylet
      current: Response([]),
      history: [],
      error: option.None,
    )
    |> reset_storylet()
  #(model, effect.none())
}

fn update(model: Model, msg: Message) -> Update {
  case msg {
    Advance -> advance(model) |> with_scroll()
    Choose(choice) -> make_choice(model, choice) |> with_scroll()
    SetFiction(fiction) -> set_fiction(model, fiction) |> with_scroll()
  }
}

fn with_scroll(model: Model) -> Update {
  #(model, scroll_to_current())
}

fn scroll_to_current() -> effect.Effect(Message) {
  use _dispatch, root <- effect.after_paint()
  do_scroll_to_bottom(root, "#" <> current_text_id)
  Nil
}

@external(javascript, "./app_ffi.mjs", "scrollToBottom")
fn do_scroll_to_bottom(root: decode.Dynamic, selector: String) -> Nil

fn reset_storylet(model: Model) -> Model {
  case engine.get_current_storylet(model.engine) {
    Ok(current) -> Model(..model, current: Story(current.body, current.choices))
    Error(e) -> Model(..model, error: e |> EngineError |> option.Some)
  }
}

fn set_fiction(model: Model, fiction: fiction.Fiction) -> Model {
  case engine.create_engine(state.new(), fiction) {
    Ok(engine) ->
      Model(..model, engine:, history: [], error: option.None)
      |> reset_storylet()
    Error(e) -> Model(..model, error: e |> EngineError |> option.Some)
  }
}

fn advance(model: Model) -> Model {
  case model.current {
    Story([], _) -> model
    Story([current, ..rest], choices) ->
      Model(..model, current: Story(rest, choices), history: [
        PastText(current),
        ..model.history
      ])
    Response([]) -> reset_storylet(model)
    Response([current, ..rest]) ->
      Model(..model, current: Response(rest), history: [
        PastText(current),
        ..model.history
      ])
  }
}

fn make_choice(model: Model, choice: ValidChoice) -> Model {
  case engine.make_choice(model.engine, choice) {
    Ok(engine) -> {
      Model(
        ..model,
        engine: engine,
        current: Response(engine.get_choice_response(choice)),
        history: [
          SelectedChoice(engine.get_choice_body(choice)),
          ..model.history
        ],
      )
    }
    Error(e) -> Model(..model, error: e |> EngineError |> option.Some)
  }
}

fn view(model: Model) -> Element(Message) {
  element.fragment([
    html.style(
      [],
      ":host { display:block; contain: strict; max-height: 100%; max-width: 100%;}",
    ),
    case model.error {
      option.Some(e) -> view_error_message(e)
      option.None -> view_game(model.current, model.history)
    },
  ])
}

fn base_class() -> attribute.Attribute(a) {
  class(string.join(
    [
      "text-black", "dark:text-slate-300", "bg-white", "dark:bg-black",
      "size-full", "overflow-auto", "px-8", "py-2",
    ],
    with: " ",
  ))
}

fn view_error_message(error: Error) -> Element(Message) {
  let EngineError(error) = error
  let error_msgs = case error {
    engine.InvalidFiction(validation_errors) ->
      validation_errors |> list.map(validation.to_string)
    engine.InvalidQuality(id:) -> [
      "Invalid runtime reference to non-existent quality with id '" <> id <> "'",
    ]
    engine.InvalidStorylet(id:) -> [
      "Invalid runtime reference to non-existent storylet with id '"
      <> id
      <> "'",
    ]
  }
  html.ul(
    [base_class(), class("text-rose-500")],
    list.map(error_msgs, html.text),
  )
}

fn view_game(
  current: CurrentEntry,
  history: List(HistoryEntry),
) -> Element(Message) {
  html.div([base_class(), event.on_click(Advance)], [
    view_history(history),
    view_current(current),
  ])
}

const current_text_id = "current_story_element"

fn current_id() -> attribute.Attribute(a) {
  attribute.id(current_text_id)
}

fn view_current(current: CurrentEntry) -> Element(Message) {
  case current {
    Story(body: [first, ..], ..) | Response([first, ..]) ->
      html.p([current_id()], [html.text(first)])
    Response([]) -> element.none()
    Story(body: [], choices:) -> view_choices(choices)
  }
}

fn view_history(history: List(HistoryEntry)) -> Element(Message) {
  let entries =
    history
    |> list.map(view_history_entry)
    |> list.reverse
  html.div([class("text-slate-400")], entries)
}

fn view_history_entry(entry: HistoryEntry) {
  case entry {
    PastText(text) -> html.p([], [html.text(text)])
    SelectedChoice(text) -> html.p([class("italic")], [html.text(text)])
  }
}

fn view_choices(choices: List(ValidChoice)) -> Element(Message) {
  html.ul([current_id()], {
    use choice <- list.map(choices)
    html.li([event.on_click(Choose(choice))], [
      html.text(choice |> engine.get_choice_body()),
    ])
  })
}
