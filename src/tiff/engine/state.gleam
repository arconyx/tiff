import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/result
import tiff/fiction/choice
import tiff/fiction/quality.{type Quality}

/// Persistent player state
pub opaque type State {
  State(history: List(String), qualities: Dict(String, Int))
}

pub fn state_decoder() -> decode.Decoder(State) {
  use history <- decode.field("history", decode.list(decode.string))
  use qualities <- decode.field(
    "qualities",
    decode.dict(decode.string, decode.int),
  )
  decode.success(State(history:, qualities:))
}

/// Goto the given target.
///
/// If the destination storylet is the same as the current
/// storylet history is not updated. `choice.Self` behaves
/// identically to `choice.Named(current_storylet_id)`.
/// e.g 'storylet1' -> goto 'storylet2' -> goto 'storylet2' -> goto parent
/// will end on 'storylet1'.
pub fn goto(state: State, target: choice.Target) -> State {
  case target {
    choice.Self -> state
    choice.Parent ->
      case state.history {
        [] -> state
        [_self, ..rest] -> State(..state, history: rest)
      }
    // TODO: This doesn't validate the target exists
    choice.Named(id:) ->
      case state.history {
        [self, ..] if self == id -> state
        history -> State(..state, history: [id, ..history])
      }
  }
}

/// Return the id of the current storylet according to the internal history
/// stack. If the stack is empty returns `'root'`.
pub fn get_current_storylet_id(state: State) -> String {
  case state.history {
    [] -> "root"
    [first, ..] -> first
  }
}

/// Get the current value of a quality. Returns the default if it is unset.
pub fn get_quality(state: State, quality: Quality) -> Int {
  state.qualities
  |> dict.get(quality.id)
  |> result.unwrap(quality |> quality.default)
}

/// Set the value of a quality. The input is clamped to the valid range
/// for the quality.
pub fn set_quality(state: State, quality: Quality, to value: Int) -> State {
  let qualities =
    state.qualities
    |> dict.insert(quality.id, value |> quality.clamp(quality))
  State(..state, qualities:)
}

pub fn new() -> State {
  State([], dict.new())
}
