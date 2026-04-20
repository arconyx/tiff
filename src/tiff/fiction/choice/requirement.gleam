//// Requirements are boolean checked based on game state,
//// in the form of checks against qualities.

import gleam/dict
import gleam/dynamic/decode
import gleam/json
import gleam/list
import tiff/fiction/validation.{type ValidationError}

/// A quality-backed requirement to make a choice
pub type Requirement {
  /// Compare the current value of a quality against a constant target
  /// Comparison goes `QUALITY OPERATOR TARGET`.
  /// For example operator `GreaterThan` means `quality > target`
  CompareWithConstant(
    quality_id: String,
    target_value: Int,
    operator: ComparisonOperator,
  )
  /// This requirement passes if all the given requirements are met
  All(List(Requirement))
  /// This requirement passes if any of the given requirements are met
  Any(List(Requirement))
  /// This requirement inverts the result of the requirement
  Not(Requirement)
}

pub type ComparisonOperator {
  GreaterThan
  LessThan
  Equal
  AtLeast
  AtMost
}

pub fn to_json(requirement: Requirement) -> json.Json {
  case requirement {
    CompareWithConstant(quality_id:, target_value:, operator:) -> [
      #("type", json.string("compare_quality")),
      #("quality", json.string(quality_id)),
      #("value", json.int(target_value)),
      #(
        "op",
        case operator {
          GreaterThan -> ">"
          LessThan -> "<"
          Equal -> "="
          AtLeast -> ">="
          AtMost -> "<="
        }
          |> json.string,
      ),
    ]
    All(children) -> [
      #("type", json.string("all")),
      #("args", json.array(children, to_json)),
    ]
    Any(children) -> [
      #("type", json.string("Any")),
      #("args", json.array(children, to_json)),
    ]
    Not(child) -> [#("type", json.string("not")), #("arg", to_json(child))]
  }
  |> json.object
}

pub fn requirement_decoder() -> decode.Decoder(Requirement) {
  use id <- decode.field("type", decode.string)
  case id {
    "compare_quality" -> {
      use quality_id <- decode.field("quality", decode.string)
      use target_value <- decode.field("value", decode.int)
      use operator <- decode.field("op", comparison_operator_decoder())
      CompareWithConstant(quality_id:, target_value:, operator:)
      |> decode.success
    }
    "all" -> {
      use args <- decode.field("args", decode.list(requirement_decoder()))
      All(args) |> decode.success
    }
    "any" -> {
      use args <- decode.field("args", decode.list(requirement_decoder()))
      Any(args) |> decode.success
    }
    "not" -> {
      use arg <- decode.field("arg", requirement_decoder())
      Not(arg) |> decode.success
    }
    _ ->
      decode.failure(
        CompareWithConstant("placeholder", 0, Equal),
        "UnrecognisedRequirementId",
      )
  }
}

fn comparison_operator_decoder() -> decode.Decoder(ComparisonOperator) {
  use variant <- decode.then(decode.string)
  case variant {
    ">" -> decode.success(GreaterThan)
    "<" -> decode.success(LessThan)
    "=" -> decode.success(Equal)
    ">=" -> decode.success(AtLeast)
    "<=" -> decode.success(AtMost)
    _ -> decode.failure(GreaterThan, "ComparisonOperator")
  }
}

pub fn requirement_validator(
  requirement: Requirement,
  valid_quality_ids: dict.Dict(String, Nil),
) -> List(ValidationError) {
  case requirement {
    CompareWithConstant(quality_id:, ..) ->
      case dict.has_key(valid_quality_ids, quality_id) {
        True -> []
        False -> [
          validation.InvalidQualityReference(
            ["compare_quality"],
            "Requirement",
            quality_id,
          ),
        ]
      }
    All(args) ->
      list.flat_map(args, requirement_validator(_, valid_quality_ids))
      |> validation.add_parent_to_all("all")
    Any(args) ->
      list.flat_map(args, requirement_validator(_, valid_quality_ids))
      |> validation.add_parent_to_all("any")
    Not(arg) ->
      requirement_validator(arg, valid_quality_ids)
      |> validation.add_parent_to_all("not")
  }
}
