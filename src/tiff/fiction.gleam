//// The fiction is the definition of a story.
//// It contains defintions for all the storylets and qualities.
//// It contains no player state and minimal runtime logic.

import gleam/dynamic/decode
import gleam/json.{type Json}
import tiff/fiction/quality.{type Quality}
import tiff/fiction/storylet.{type Storylet}

pub type Fiction {
  Fiction(storylets: List(Storylet), qualities: List(Quality))
}

pub fn to_json(fiction: Fiction) -> Json {
  let Fiction(storylets:, qualities:) = fiction
  json.object([
    #("storylets", json.array(storylets, storylet.to_json)),
    #("qualities", json.array(qualities, quality.to_json)),
  ])
}

pub fn fiction_decoder() -> decode.Decoder(Fiction) {
  use storylets <- decode.field(
    "storylets",
    decode.list(storylet.storylet_decoder()),
  )
  use qualities <- decode.field(
    "qualities",
    decode.list(quality.quality_decoder()),
  )
  decode.success(Fiction(storylets:, qualities:))
}
