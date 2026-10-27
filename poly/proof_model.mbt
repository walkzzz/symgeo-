///|
/// Proof model of `Monomial::total_degree` over a FixedArray of exponents.
/// Proved: the sum of exponents is always nonnegative (loop invariant 0 <= d).
/// This lives in the moon prove supported subset (FixedArray[Int32] + for loop).
pub fn sum_degrees(xs : FixedArray[Int32]) -> Int32 where {
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

///|
/// Proof model of `Polynomial::degree` over a FixedArray of term degrees
/// (empty array models the zero polynomial, degree -1 by convention).
/// Proved: the result is at least -1.
pub fn max_exponent(xs : FixedArray[Int32]) -> Int32 where {
  proof_ensure: result => -1 <= result,
} {
  let mut m : Int32 = -1
  for i = 0; i < xs.length(); {
    if xs[i] > m {
      m = xs[i]
    }
    continue i + 1
  } where {
    proof_invariant: -1 <= m,
    proof_invariant: 0 <= i,
    proof_invariant: i <= xs.length(),
  }
  m
}
