import gleam/dict
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import tiff/fiction/choice.{type Choice}
import tiff/fiction/validation.{type ValidationError}

pub type Storylet {
  Storylet(id: String, body: List(String), choices: List(Choice))
}

pub fn to_json(storylet: Storylet) -> Json {
  let Storylet(id:, body:, choices:) = storylet
  json.object([
    #("id", json.string(id)),
    #("body", json.array(body, json.string)),
    #("choices", json.array(choices, choice.to_json)),
  ])
}

pub fn storylet_decoder() -> decode.Decoder(Storylet) {
  use id <- decode.field("id", decode.string)
  use body <- decode.field(
    "body",
    decode.one_of(decode.list(decode.string), [
      decode.string |> decode.map(list.wrap),
    ]),
  )
  use choices <- decode.field("choices", decode.list(choice.choice_decoder()))
  decode.success(Storylet(id:, body:, choices:))
}

pub fn storylet_validator(
  storylet: Storylet,
  valid_storylet_ids: dict.Dict(String, Nil),
  valid_quality_ids: dict.Dict(String, Nil),
) -> List(ValidationError) {
  let id_errors = case storylet.id {
    "parent" | "self" -> [
      validation.ForbiddenStoryletId(["id"], "Storylet", storylet.id),
    ]
    _ -> []
  }

  let choice_errors =
    storylet.choices
    |> list.flat_map(choice.choice_validator(
      _,
      valid_storylet_ids,
      valid_quality_ids,
    ))
    |> validation.add_parent_to_all("choices")

  list.flatten([id_errors, choice_errors])
}
