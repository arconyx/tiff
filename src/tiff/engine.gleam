import gleam/bool
import gleam/dynamic/decode
import gleam/function
import gleam/list
import gleam/option
import gleam/result
import tiff/engine/state.{type State}
import tiff/fiction
import tiff/fiction/choice.{type Choice}
import tiff/fiction/choice/effect.{type Effect}
import tiff/fiction/choice/requirement.{type Requirement}
import tiff/fiction/quality.{type Quality}
import tiff/fiction/storylet.{type Storylet}
import tiff/fiction/validation
import tiff/utils/id_dict.{type IdDict}

pub opaque type Engine {
  Engine(
    player_state: State,
    storylets: IdDict(String, Storylet),
    qualities: IdDict(String, Quality),
  )
}

pub fn engine_decoder() -> decode.Decoder(Engine) {
  use player_state <- decode.field("player_state", state.state_decoder())
  use storylets <- decode.field(
    "storylets",
    id_dict.id_dict_decoder(decode.string, storylet.storylet_decoder()),
  )
  use qualities <- decode.field(
    "qualities",
    id_dict.id_dict_decoder(decode.string, quality.quality_decoder()),
  )
  decode.success(Engine(player_state:, storylets:, qualities:))
}

pub type Error {
  InvalidFiction(List(validation.ValidationError))
  InvalidQuality(id: String)
  InvalidStorylet(id: String)
}

/// Create an engine from player state and a `fiction.Fiction`.
/// The function will error if the fiction fails validation.
pub fn create_engine(
  player_state: State,
  fiction: fiction.Fiction,
) -> Result(Engine, _) {
  case fiction.validate(fiction) {
    [] ->
      Engine(
        player_state:,
        storylets: fiction.storylets |> id_dict.from_list(fn(s) { s.id }),
        qualities: fiction.qualities |> id_dict.from_list(fn(q) { q.id }),
      )
      |> Ok
    errors -> InvalidFiction(errors) |> Error
  }
}

/// We use the type system to enforce only passing checked requirements
pub fn make_choice(engine: Engine, choice: ValidChoice) -> Result(Engine, Error) {
  let ValidChoice(choice) = choice
  use engine <- result.try(apply_effects(engine, choice.effects))
  change_storylet(engine, choice.goto)
}

fn check_requirement(
  engine: Engine,
  requirement: Requirement,
) -> Result(Bool, Error) {
  case requirement {
    requirement.CompareWithConstant(quality_id:, target_value:, operator:) -> {
      use #(_, current) <- result.map(get_quality(engine, quality_id))
      case operator {
        requirement.GreaterThan -> current > target_value
        requirement.LessThan -> current < target_value
        requirement.Equal -> current == target_value
        requirement.AtLeast -> current >= target_value
        requirement.AtMost -> current <= target_value
      }
    }
    requirement.All(requirements) -> {
      requirements
      |> list.try_map(check_requirement(engine, _))
      |> result.map(list.all(_, function.identity))
    }
    requirement.Any(requirements) -> {
      requirements
      |> list.try_map(check_requirement(engine, _))
      |> result.map(list.any(_, function.identity))
    }
    requirement.Not(requirement) ->
      check_requirement(engine, requirement)
      |> result.map(bool.negate)
  }
}

fn check_requirements(
  engine: Engine,
  requirements: List(Requirement),
) -> Result(Bool, Error) {
  requirements
  |> list.try_map(check_requirement(engine, _))
  |> result.map(list.all(_, function.identity))
}

fn validate_choice(
  engine: Engine,
  choice: Choice,
) -> Result(option.Option(ValidChoice), Error) {
  case check_requirements(engine, choice.requirements) {
    Ok(True) -> choice |> ValidChoice |> option.Some |> Ok
    Ok(False) -> option.None |> Ok
    Error(e) -> Error(e)
  }
}

fn get_quality(engine: Engine, id: String) -> Result(#(Quality, Int), Error) {
  case engine.qualities |> id_dict.get(id) {
    Ok(quality) ->
      #(quality, state.get_quality(engine.player_state, quality)) |> Ok
    Error(_) -> InvalidQuality(id) |> Error
  }
}

fn set_quality(engine: Engine, quality: Quality, to: Int) -> Engine {
  Engine(
    ..engine,
    player_state: engine.player_state |> state.set_quality(quality, to),
  )
}

fn apply_effect(engine: Engine, effect: Effect) -> Result(Engine, Error) {
  case effect {
    effect.QualityAdd(quality_id:, amount:) -> {
      use #(quality, current) <- result.map(get_quality(engine, quality_id))
      set_quality(engine, quality, current + amount)
    }
    effect.QualitySet(quality_id:, to:) -> {
      use #(quality, _) <- result.map(get_quality(engine, quality_id))
      set_quality(engine, quality, to)
    }
  }
}

fn apply_effects(engine: Engine, effects: List(Effect)) -> Result(Engine, Error) {
  list.try_fold(over: effects, from: engine, with: apply_effect)
}

fn change_storylet(
  engine: Engine,
  target: choice.Target,
) -> Result(Engine, Error) {
  let target = case target {
    choice.Self | choice.Parent -> Ok(target)
    choice.Named(id:) ->
      case id_dict.get(engine.storylets, id) {
        Ok(_) -> Ok(target)
        Error(_) -> InvalidStorylet(id) |> Error
      }
  }
  use target <- result.map(target)
  Engine(..engine, player_state: engine.player_state |> state.goto(target))
}

pub type CurrentStorylet {
  CurrentStorylet(body: List(String), choices: List(ValidChoice))
}

pub fn get_current_storylet(engine: Engine) -> Result(CurrentStorylet, Error) {
  let storylet_id = engine.player_state |> state.get_current_storylet_id
  use storylet <- result.try(
    engine.storylets
    |> id_dict.get(storylet_id)
    |> result.replace_error(InvalidStorylet(storylet_id)),
  )
  use choices <- result.map(
    storylet.choices |> list.try_map(validate_choice(engine, _)),
  )
  let valid_choices = option.values(choices)
  CurrentStorylet(body: storylet.body, choices: valid_choices)
}

pub opaque type ValidChoice {
  ValidChoice(Choice)
}

pub fn get_choice_body(choice: ValidChoice) -> String {
  let ValidChoice(choice) = choice
  choice.body
}

pub fn get_choice_response(choice: ValidChoice) -> List(String) {
  let ValidChoice(choice) = choice
  choice.response
}
