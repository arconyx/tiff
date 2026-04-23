import gleam/json
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element/html
import lustre/event
import tiff/app/viewer
import tiff/fiction

pub fn main() {
  let app = lustre.application(init, update, view)

  let assert Ok(_) = viewer.register()
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

type Model {
  Unloaded(String)
  Loaded(fiction: fiction.Fiction)
  Failure(Error)
}

fn init(_) {
  #(Unloaded(""), effect.none())
}

type Message {
  LoadEngine
  UpdateInput(String)
}

type Error {
  DecodeError(json.DecodeError)
}

fn update(model: Model, msg: Message) {
  case model, msg {
    Unloaded(string), LoadEngine ->
      case json.parse(string, fiction.fiction_decoder()) {
        Ok(fiction) -> #(fiction |> Loaded, effect.none())
        Error(e) -> #(e |> DecodeError |> Failure, effect.none())
      }
    Unloaded(_), UpdateInput(string) -> #(Unloaded(string), effect.none())
    _, _ -> #(model, effect.none())
  }
}

fn view(model: Model) {
  case model {
    Unloaded(text) ->
      html.div([], [
        html.p([], [html.text("Load a story")]),
        html.textarea(
          [attribute.value(text), event.on_change(UpdateInput)],
          text,
        ),
        html.button([event.on_click(LoadEngine)], [html.text("submit")]),
      ])
    Loaded(fiction:) ->
      html.div([attribute.class("bg-white dark:bg-black")], [
        viewer.element([
          attribute.property("fiction", fiction |> fiction.to_json),
          attribute.class("w-screen h-screen pt-4 pb-8"),
        ]),
      ])
    Failure(e) -> html.p([], [html.text(string.inspect(e))])
  }
}
