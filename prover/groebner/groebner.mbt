///|
/// I2 placeholder: Buchberger Groebner engine.
/// Contract (from the approved plan):
/// - Candidate-pair heap ordered by minimal lcm degree (normal strategy).
/// - S-polynomial reduced to zero -> discarded; nonzero -> joins the basis.
/// - Degree-bound guard: exceeding the bound returns Timeout, never hangs.
/// - The reduction step is an isolated interface so F4 batch reduction can be
///   swapped in later without touching the engine loop (extension red line #5).
