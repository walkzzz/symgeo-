///|
test "monomial: make normalizes (sort/filter/merge)" {
  let m = Monomial::make([(2, 1), (0, 2), (2, 3), (1, 0)])
  // expect x0^2 * x2^4
  assert_eq(m.exponents(), [(0, 2), (2, 4)])
  assert_eq(m.total_degree(), 6)
  assert_true(Monomial::make([]).is_one())
}

///|
test "monomial: mul and divide are inverse" {
  let a = Monomial::make([(0, 2), (1, 1)])
  let b = Monomial::make([(1, 3), (2, 1)])
  let p = a.mul(b)
  assert_eq(p.total_degree(), 7)
  match p.divide(b) {
    Some(q) => assert_eq(q, a)
    None => abort("unreachable: p is divisible by b")
  }
  // non-divisible case
  assert_eq(a.divide(Monomial::make([(0, 3)])), None)
  // divides predicate
  assert_true(Monomial::make([(0, 3)]).divides(Monomial::make([(0, 5), (1, 2)])))
  assert_false(Monomial::make([(1, 1)]).divides(Monomial::make([(0, 5)])))
}

///|
test "monomial: orders are deterministic" {
  let x = Monomial::make([(0, 1)])
  let x2 = Monomial::make([(0, 2)])
  let y = Monomial::make([(1, 1)])
  let xy = Monomial::make([(0, 1), (1, 1)])
  // lex: x2 > xy > x*y0? standard: x^2 > xy > y^? compare with nvars=2
  assert_true(x2.compare_lex(xy, 2) > 0)
  assert_true(xy.compare_lex(y, 2) > 0)
  // grevlex: x^2 > xy (same degree 2; last differing pos x2 has exp0 vs xy exp1 -> x2 larger)
  assert_true(x2.compare_grevlex(xy, 2) > 0)
  // grevlex: xy > y^2... y2 = y*y
  let y2 = Monomial::make([(1, 2)])
  assert_true(xy.compare_grevlex(y2, 2) > 0)
  // canonical order is total and antisymmetric on storage
  assert_eq(x.compare_canonical(x), 0)
  assert_eq(x.compare_canonical(y), -y.compare_canonical(x))
}

///|
test "polynomial: (x+1)*(x-1) = x^2 - 1" {
  let x = Polynomial::variable(0)
  let p = x.add(Polynomial::one()).mul(x.sub(Polynomial::one()))
  let expect = Polynomial::mono([(0, 2)]).sub(Polynomial::one())
  assert_eq(p, expect)
  assert_eq(p.to_string(), "-1 + 1*x0^2")
}

///|
test "polynomial: (x+y)^2 = x^2 + 2xy + y^2" {
  let x = Polynomial::variable(0)
  let y = Polynomial::variable(1)
  let p = x.add(y).pow(2)
  let expect = Polynomial::mono([(0, 2)])
    .add(Polynomial::mono([(0, 1), (1, 1)], c=@arithmetic.Rational::from_int(2)))
    .add(Polynomial::mono([(1, 2)]))
  assert_eq(p, expect)
}

///|
test "polynomial: canonical storage order (determinism)" {
  // build the same polynomial via two different construction paths
  let p1 = Polynomial::variable(1).add(Polynomial::variable(0)).mul(Polynomial::variable(1))
  let p2 = Polynomial::variable(1).mul(Polynomial::variable(1)).add(Polynomial::mono([(0, 1), (1, 1)]))
  assert_eq(p1, p2)
  assert_eq(p1.hash(), p2.hash())
  assert_eq(p1.to_string(), p2.to_string())
}

///|
test "polynomial: leading term under lex vs grevlex" {
  // p = x^2 + x*y + 1, nvars = 2
  let p = Polynomial::mono([(0, 2)])
    .add(Polynomial::mono([(0, 1), (1, 1)]))
    .add(Polynomial::one())
  match p.leading_term(Lex, 2) {
    Some(t) => assert_eq(t.0.to_string(), "x0^2")
    None => abort("unreachable")
  }
  // grevlex: degree tie between x^2 and xy -> x^2 wins (smaller exponent at
  // the last differing position x1: 0 < 1)
  match p.leading_term(Grevlex, 2) {
    Some(t) => assert_eq(t.0.to_string(), "x0^2")
    None => abort("unreachable")
  }
  // lex vs grevlex divergence with 3 vars: a = x0^2*x2, b = x0*x1^2
  let a = Monomial::make([(0, 2), (2, 1)])
  let b = Monomial::make([(0, 1), (1, 2)])
  // lex: first exponent 2 > 1 -> a larger
  assert_true(a.compare_lex(b, 3) > 0)
  // grevlex: degree tie 3; last position x2: a=1 > b=0 -> b larger
  assert_true(a.compare_grevlex(b, 3) < 0)
  // zero polynomial has no leading term
  assert_true(Polynomial::zero().leading_term(Lex, 2) is None)
}

///|
test "polynomial: content and primitive part" {
  // p = (2/3)x^2 + (4/5)x -> content = gcd(2,4)/lcm(3,5) = 2/15
  // primitive = (2/3)/(2/15) x^2 + (4/5)/(2/15) x = 5x^2 + 6x
  let p = Polynomial::mono([(0, 2)], c=@arithmetic.Rational::from_int2(2, 3))
    .add(Polynomial::mono([(0, 1)], c=@arithmetic.Rational::from_int2(4, 5)))
  assert_eq(p.content().to_string(), "2/15")
  match p.primitive_part() {
    Ok(q) => assert_eq(q.to_string(), "6*x0 + 5*x0^2")
    Err(_) => abort("unreachable: content is nonzero")
  }
  // content of zero polynomial is zero
  assert_true(Polynomial::zero().content().is_zero())
}

///|
test "polynomial: exact division by scalar and monomial" {
  let p = Polynomial::mono([(0, 2)], c=@arithmetic.Rational::from_int(4))
    .add(Polynomial::mono([(1, 1)], c=@arithmetic.Rational::from_int(6)))
  match p.div_scalar(@arithmetic.Rational::from_int(2)) {
    Ok(q) => assert_eq(q.to_string(), "2*x0^2 + 3*x1")
    Err(_) => abort("unreachable")
  }
  // division by zero scalar is an error
  assert_true(p.div_scalar(@arithmetic.Rational::zero()) is Err(_))
  // monomial division: term 6*x1 not divisible by x0 -> explicit error
  assert_true(p.div_monomial(Monomial::make([(0, 1)])) is Err(NotExactDivision))
  // divisible case: 4*x0^2 / x0 = 4*x0
  let p2 = Polynomial::mono([(0, 2)], c=@arithmetic.Rational::from_int(4))
  match p2.div_monomial(Monomial::make([(0, 1)])) {
    Ok(q) => assert_eq(q.to_string(), "4*x0")
    Err(_) => abort("should divide")
  }
}

///|
test "polynomial: univariate gcd via Euclid" {
  // gcd(x^2 - 1, x + 1) = x + 1
  let a = Polynomial::mono([(0, 2)]).sub(Polynomial::one())
  let b = Polynomial::variable(0).add(Polynomial::one())
  match a.gcd_univariate(b) {
    Ok(g) => assert_eq(g, b)
    Err(e) => abort("gcd failed: \{e}")
  }
  // gcd(x^2 - 1, x^2 + 2x + 1) = x + 1
  let c = Polynomial::mono([(0, 2)])
    .add(Polynomial::mono([(0, 1)], c=@arithmetic.Rational::from_int(2)))
    .add(Polynomial::one())
  match a.gcd_univariate(c) {
    Ok(g) => assert_eq(g, b)
    Err(e) => abort("gcd failed: \{e}")
  }
  // coprime: gcd(x, x+1) = 1
  match Polynomial::variable(0).gcd_univariate(b) {
    Ok(g) => assert_true(g.is_one())
    Err(e) => abort("gcd failed: \{e}")
  }
  // multivariate input is rejected explicitly
  let multi = Polynomial::variable(0).add(Polynomial::variable(1))
  assert_true(multi.gcd_univariate(b) is Err(NotUnivariate))
}
