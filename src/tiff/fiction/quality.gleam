//// Qualities are our primary form of player state.
//// They are integer values identified by a unique id.
//// The complete set of qualities is basically a key-value
//// store where the values are all integers.

import gleam/dynamic/decode
import gleam/int
import gleam/json.{type Json}
import gleam/order

/// A quality is an integer value constrained to a given range.
pub type Quality {
  Quality(
    /// Unique internal id for the quality
    id: String,
    /// Quality name displayed to player
    name: String,
    /// Quality description displayed to player
    description: String,
    /// Valid range and default for the quality
    range: Range,
  )
}

/// The range of possible values for a quality.
///
/// The minimum and maximum are inclusive. The range is guaranteed to have `min
/// <= default <= max`.
pub opaque type Range {
  Range(min: Int, max: Int, default: Int)
}

/// Create a range
///
/// If the minimum argument is greater than the maximum then the values will be
/// swapped so that `minimum <= maximum`.
///
/// The default is clamped to the range given by the minimum and maximum.
pub fn range(minimum min: Int, maximum max: Int, default default: Int) -> Range {
  let #(min, max) = case int.compare(min, max) {
    order.Lt | order.Eq -> #(min, max)
    order.Gt -> #(max, min)
  }

  let default = int.clamp(default, min:, max:)
  Range(min:, max:, default:)
}

/// Clamp the input value to the valid range of the quality
pub fn clamp(value v: Int, with quality: Quality) -> Int {
  int.clamp(v, quality.range.min, quality.range.max)
}

pub fn to_json(quality: Quality) -> Json {
  [
    #("id", json.string(quality.id)),
    #("name", json.string(quality.name)),
    #("description", json.string(quality.description)),
    #("min", json.int(quality.range.min)),
    #("max", json.int(quality.range.max)),
    #("default", json.int(quality.range.default)),
  ]
  |> json.object
}

pub fn quality_decoder() -> decode.Decoder(Quality) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use description <- decode.optional_field("description", "", decode.string)
  use min <- decode.optional_field("min", 0, decode.int)
  // The default max is JavaScript's MAX_SAFE_INTEGER
  use max <- decode.optional_field("max", 9_007_199_254_740_991, decode.int)
  use default <- decode.optional_field("default", 0, decode.int)
  Quality(id:, name:, description:, range: Range(min:, max:, default:))
  |> decode.success
}
