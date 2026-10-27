///|
/// I3 placeholder: Wu engine (pseudo-division + triangular/ascending sets).
/// Contract (from the approved plan):
/// - Hypotheses triangularized by principal variable via pseudo-division
///   (integer coefficients throughout, no rationals).
/// - Goal pseudo-divided layer by layer against the ascending set; final
///   remainder == 0 with nonvanishing initials => theorem holds.
/// - Non-degeneracy conditions (initial != 0) are emitted automatically.
/// - Output is a verifiable certificate, never a bare boolean.
