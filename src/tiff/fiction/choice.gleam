import gleam/dict
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import tiff/fiction/choice/effect.{type Effect}
import tiff/fiction/choice/requirement.{type Requirement}
import tiff/fiction/validation.{type ValidationError}

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

pub fn to_json(choice: Choice) -> Json {
  [
    #("body", json.string(choice.body)),
    #("response", json.array(choice.response, json.string)),
    #(
      "goto",
      case choice.goto {
        Self -> "self"
        Parent -> "parent"
        Named(id:) -> id
      }
        |> json.string,
    ),
    #("requirements", json.array(choice.requirements, requirement.to_json)),
    #("effects", json.array(choice.effects, effect.to_json)),
  ]
  |> json.object
}

pub fn choice_decoder() -> decode.Decoder(Choice) {
  use body <- decode.field("body", decode.string)
  use response <- decode.optional_field(
    "response",
    [],
    decode.one_of(decode.list(decode.string), [
      decode.string |> decode.map(list.wrap),
    ]),
  )
  use goto <- decode.optional_field("goto", Self, target_decoder())
  use requirements <- decode.optional_field(
    "requirements",
    [],
    decode.list(requirement.requirement_decoder()),
  )
  use effects <- decode.optional_field(
    "effects",
    [],
    decode.list(effect.effect_decoder()),
  )
  decode.success(Choice(body:, response:, goto:, requirements:, effects:))
}

fn target_decoder() -> decode.Decoder(Target) {
  use variant <- decode.then(decode.string)
  case variant {
    "self" -> decode.success(Self)
    "parent" -> decode.success(Parent)
    id -> decode.success(Named(id))
  }
}

fn target_validator(
  target: Target,
  valid_storylet_ids: dict.Dict(String, Nil),
) -> List(ValidationError) {
  case target {
    Self | Parent -> []
    Named(id) ->
      case dict.has_key(valid_storylet_ids, id) {
        True -> []
        False -> [validation.InvalidStoryletReference(["named"], "Target", id)]
      }
  }
}

pub fn choice_validator(
  choice: Choice,
  valid_storylet_ids: dict.Dict(String, Nil),
  valid_quality_ids: dict.Dict(String, Nil),
) -> List(ValidationError) {
  // use <- validation.with_parent("choice")
  let target_errors =
    target_validator(choice.goto, valid_storylet_ids)
    |> validation.add_parent_to_all("goto")
  let effect_errors =
    list.flat_map(choice.effects, effect.effect_validator(_, valid_quality_ids))
    |> validation.add_parent_to_all("effects")
  let requirement_errors =
    list.flat_map(choice.requirements, requirement.requirement_validator(
      _,
      valid_quality_ids,
    ))
    |> validation.add_parent_to_all("requirements")
  list.flatten([target_errors, effect_errors, requirement_errors])
}
