import gleam/dict.{type Dict}
import tiff/fiction/choice

pub opaque type State {
  State(history: List(String), qualities: Dict(String, Int))
}

/// Goto the given target.
///
/// If the destination storylet is the same as the current
/// storylet history is not updated. `choice.Self` behaves
/// identically to `choice.Named(current_storylet_id)`.
/// e.g 'storylet1' -> goto 'storylet2' -> goto 'storylet2' -> goto parent
/// will end on 'storylet1'.
/// 
pub fn goto(state: State, target: choice.Target) -> State {
  case target {
    choice.Self -> state
    choice.Parent ->
      case state.history {
        [] -> state
        [_self, ..rest] -> State(..state, history: rest)
      }
    choice.Named(id:) ->
      case state.history {
        [self, ..] if self == id -> state
        history -> State(..state, history: [id, ..history])
      }
  }
}
