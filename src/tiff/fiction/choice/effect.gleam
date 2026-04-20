//// The effects of choices
//// Set the value of a quality.
//// The value will be clamped to the valid range.

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
