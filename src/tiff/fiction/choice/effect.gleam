//// The effects of choices
//// Set the value of a quality.
//// The value will be clamped to the valid range.

import gleam/dynamic/decode
import gleam/json.{type Json}

/// An effect mutates the game state.
/// They are used as the outcome of choices.
pub type Effect {
  /// Add to the current value of a quality.
  /// If the quality is not set then the default value is used. Negative values
  /// will be subtracted. The result is clamped by the range of the quality.
  QualityAdd(quality_id: String, amount: Int)
  /// Set the current value of a quality.
  /// The value will be clamped to the valid range of the quality.
  QualitySet(quality_id: String, to: Int)
}

pub fn to_json(effect: Effect) -> Json {
  case effect {
    QualityAdd(quality_id:, amount:) -> [
      #("effect", json.string("quality_add")),
      #("quality", json.string(quality_id)),
      #("value", json.int(amount)),
    ]
    QualitySet(quality_id:, to:) -> [
      #("effect", json.string("quality_add")),
      #("quality", json.string(quality_id)),
      #("value", json.int(to)),
    ]
  }
  |> json.object
}

pub fn effect_decoder() -> decode.Decoder(Effect) {
  use id <- decode.field("effect", decode.string)
  case id {
    "quality_add" -> {
      use quality_id <- decode.field("quality", decode.string)
      use amount <- decode.field("value", decode.int)
      QualityAdd(quality_id:, amount:)
      |> decode.success
    }
    "quality_set" -> {
      use quality_id <- decode.field("quality", decode.string)
      use to <- decode.field("value", decode.int)
      QualitySet(quality_id:, to:)
      |> decode.success
    }
    _ -> decode.failure(QualityAdd("placeholder", 0), "UnrecognisedEffectId")
  }
}
