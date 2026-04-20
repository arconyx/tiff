import gleam/list
import gleam/string

/// All errors have a location field. This is a list of strings where each
/// value is the id of an element containing the error. The element referenced
/// by an id wraps the element referenced by the next id in the list.
/// This means the first element is the outermost object and the innermost
/// element is the original source of the error.
///
/// They also have a `broken_type` field which is a string representation
/// of the name of the type where the validation error was found.
pub type ValidationError {
  DuplicateStoryletId(
    location: List(String),
    broken_type: String,
    duplicate_id: String,
  )
  DuplicateQualityId(
    location: List(String),
    broken_type: String,
    duplicate_id: String,
  )
  InvalidStoryletReference(
    location: List(String),
    broken_type: String,
    invalid_ref: String,
  )
  InvalidQualityReference(
    location: List(String),
    broken_type: String,
    invalid_ref: String,
  )
}

/// Prepend parent location to `location field`
fn add_parent(error: ValidationError, parent: String) -> ValidationError {
  case error {
    DuplicateStoryletId(location:, ..) as o ->
      DuplicateStoryletId(..o, location: [parent, ..location])
    DuplicateQualityId(location:, ..) as o ->
      DuplicateQualityId(..o, location: [parent, ..location])
    InvalidStoryletReference(location:, ..) as o ->
      InvalidStoryletReference(..o, location: [parent, ..location])
    InvalidQualityReference(location:, ..) as o ->
      InvalidQualityReference(..o, location: [parent, ..location])
  }
}

/// Prepend parent location to `location field` for all errors in list
pub fn add_parent_to_all(
  errors: List(ValidationError),
  parent: String,
) -> List(ValidationError) {
  errors
  |> list.map(add_parent(_, parent))
}

pub fn to_string(error: ValidationError) -> String {
  let inner = case error {
    DuplicateStoryletId(duplicate_id:, ..) ->
      "Duplicate storylet id '" <> duplicate_id <> "'"
    DuplicateQualityId(duplicate_id:, ..) ->
      "Duplicate quality id '" <> duplicate_id <> "'"
    InvalidStoryletReference(invalid_ref:, ..) ->
      "Reference to invalid storylet '" <> invalid_ref <> "'"
    InvalidQualityReference(invalid_ref:, ..) ->
      "Reference to invalid quality '" <> invalid_ref <> "'"
  }
  let path = string.join(error.location, ".")
  "Error in " <> error.broken_type <> " at " <> path <> ": " <> inner
}
