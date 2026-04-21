//// The fiction is the definition of a story.
//// It contains defintions for all the storylets and qualities.
//// It contains no player state and minimal runtime logic.

import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/list
import tiff/fiction/quality.{type Quality}
import tiff/fiction/storylet.{type Storylet}
import tiff/fiction/validation.{type ValidationError}

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

pub fn validate(fiction: Fiction) -> List(ValidationError) {
  let #(storylet_ids, duplicate_storylets) =
    fiction.storylets |> list.map(fn(s) { s.id }) |> scan_id_list
  let #(quality_ids, duplicate_qualities) =
    fiction.qualities |> list.map(fn(q) { q.id }) |> scan_id_list

  // All quality and storylet ids should be unique amongst their type
  let dupe_sid_errors =
    duplicate_storylets
    |> list.map(validation.DuplicateStoryletId(["storylets"], "Fiction", _))
  let dupe_qid_errors =
    duplicate_qualities
    |> list.map(validation.DuplicateQualityId(["qualities"], "Fiction", _))

  // A storylet with the id 'root' is required
  let root_error = case dict.has_key(storylet_ids, "root") {
    True -> []
    False -> [validation.NoRootStorylet(["storylets"], "Fiction")]
  }

  // Validate all choice gotos point to valid storylets
  // Validate all effects refer to valid qualities
  // Validate all requirements refer to valid qualities
  let storylet_errors =
    fiction.storylets
    |> list.flat_map(storylet.storylet_validator(_, storylet_ids, quality_ids))

  list.flatten([dupe_sid_errors, dupe_qid_errors, root_error, storylet_errors])
}

/// Process a list of ids and check for uniqueness.
///
/// Returns a dictonary with all ids found and a list of duplicate ids.
///
/// Based on stdlib `list.unique`, which runs in log-linear time.
pub fn scan_id_list(list: List(a)) -> #(Dict(a, Nil), List(a)) {
  scan_id_list_loop(list, dict.new(), [])
}

fn scan_id_list_loop(
  list: List(a),
  seen: Dict(a, Nil),
  duplicates: List(a),
) -> #(Dict(a, Nil), List(a)) {
  case list {
    [] -> #(seen, duplicates)
    [first, ..rest] ->
      case dict.has_key(seen, first) {
        True -> scan_id_list_loop(rest, seen, [first, ..duplicates])
        False ->
          scan_id_list_loop(rest, dict.insert(seen, first, Nil), duplicates)
      }
  }
}
