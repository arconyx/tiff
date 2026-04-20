import tiff/fiction/choice/effect.{type Effect}
import tiff/fiction/choice/requirement.{type Requirement}

pub type Choice {
  Choice(
    body: String,
    response: List(String),
    goto: Target,
    requirements: List(Requirement),
    effects: List(Effect),
  )
}

/// A `Target` is a relative reference to a storylet.
/// It is used to point to the outcome of a choice.
pub type Target {
  /// This target returns to the start of the current storylet
  Self
  /// This target returns to the previous storylet
  Parent
  /// This points to the storylet with the given id
  Named(id: String)
}
