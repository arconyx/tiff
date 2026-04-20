//// Requirements are boolean checked based on game state,
//// in the form of checks against qualities.

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
