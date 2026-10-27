///|
test "rational: normalization invariant" {
  // 4/6 -> 2/3 ; -3/-9 -> 1/3 ; 0/5 -> 0/1
  assert_eq(Rational::from_int2(4, 6).to_string(), "2/3")
  assert_eq(Rational::from_int2(-3, -9).to_string(), "1/3")
  assert_eq(Rational::from_int2(0, 5).to_string(), "0")
  assert_eq(Rational::from_int2(0, -5).to_string(), "0")
  // denominator always positive
  assert_eq(Rational::from_int2(3, -6).to_string(), "-1/2")
}

///|
test "rational: field axioms on samples" {
  let a = Rational::from_int2(2, 3)
  let b = Rational::from_int2(-5, 7)
  let c = Rational::from_int2(11, 13)
  // commutativity / associativity
  assert_eq(a.add(b), b.add(a))
  assert_eq(a.add(b.add(c)), a.add(b).add(c))
  assert_eq(a.mul(b), b.mul(a))
  assert_eq(a.mul(b.mul(c)), a.mul(b).mul(c))
  // distributivity
  assert_eq(a.mul(b.add(c)), a.mul(b).add(a.mul(c)))
  // inverse law: a * a^-1 = 1
  match a.inv() {
    Ok(ainv) => assert_eq(a.mul(ainv), Rational::one())
    Err(_) => abort("unreachable: a is nonzero")
  }
}

///|
test "rational: div by zero is an explicit error" {
  match Rational::from_int2(1, 2).div(Rational::zero()) {
    Ok(_) => abort("expected DivByZero")
    Err(DivByZero) => assert_true(true)
  }
}

///|
test "rational: big numbers stay exact" {
  // (10^30 + 1) / 3 * 3 == 10^30 + 1
  let big = BigInt::from_string("1000000000000000000000000000001")
  let r = match Rational::make(big, BigInt::from_int(3)) {
    Ok(v) => v
    Err(_) => abort("unreachable")
  }
  let back = r.mul(Rational::from_int(3))
  assert_eq(back.numerator().to_string(), "1000000000000000000000000000001")
  assert_eq(back.denominator().to_string(), "1")
}

///|
test "rational: pow exact" {
  let a = Rational::from_int2(2, 3)
  match a.pow(3) {
    Ok(v) => assert_eq(v.to_string(), "8/27")
    Err(_) => abort("unreachable")
  }
  match a.pow(0) {
    Ok(v) => assert_eq(v.to_string(), "1")
    Err(_) => abort("unreachable")
  }
  match a.pow(-2) {
    Ok(v) => assert_eq(v.to_string(), "9/4")
    Err(_) => abort("unreachable")
  }
}
