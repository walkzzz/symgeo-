///|
/// Probe 1: FixedArray[Int32] loop with invariant (doc-style example).
pub fn probe_fixed_i32(xs : FixedArray[Int32]) -> Int32 where {
  proof_ensure: result => 0 <= result,
} {
  let mut d : Int32 = 0
  for i = 0; i < xs.length(); {
    d = d + xs[i]
    continue i + 1
  } where {
    proof_invariant: 0 <= i,
    proof_invariant: i <= xs.length(),
    proof_invariant: 0 <= d,
  }
  d
}
