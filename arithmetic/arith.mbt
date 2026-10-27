///|
/// I0 smoke: verify the core/bigint dependency works from the arithmetic layer.
/// I1 will replace this file with the full Rational implementation on top of BigInt.
/// Design notes for I1 (from the approved plan):
/// - Rational is normalized at construction: denominator always positive, fully reduced.
/// - Overflow is reported explicitly; no silent fallback.
/// - A `Ring`-like interface will be defined in I1 so the coefficient type is
///   parameterizable (extension red line #1).
pub fn bigint_smoke() -> String {
  let a : @bigint.BigInt = @bigint.BigInt::from_string("123456789012345678901234567890")
  let b : @bigint.BigInt = @bigint.BigInt::from_int(987654321)
  // (a * a + b) * b - a / b  — exercises mul/add/sub/div in one expression
  let s = a.mul(a).add(b)
  let t = s.mul(b).sub(a.div(b))
  t.to_string()
}

///|
test "bigint smoke: big-number four arithmetic" {
  let s = bigint_smoke()
  // Deterministic result; length sanity check instead of hardcoding digits.
  assert_true(s.length() > 60)
  // Result must be positive.
  assert_false(s.has_prefix("-"))
}

///|
test "bigint smoke: exactness preserved" {
  let a : @bigint.BigInt = @bigint.BigInt::from_string("99999999999999999999999999999")
  let b : @bigint.BigInt = @bigint.BigInt::from_int(1)
  assert_eq(a.add(b).to_string(), "100000000000000000000000000000")
}
