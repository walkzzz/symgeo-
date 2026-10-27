///|
/// Explicit errors of the polynomial layer.
pub(all) enum PolyError {
  /// Exact division required but divisor does not divide dividend.
  NotExactDivision
  /// Operation requires a univariate polynomial but got more variables.
  NotUnivariate
  /// Division by the zero polynomial.
  DivisionByZeroPoly
} derive(Eq, Debug)

///|
pub impl Show for PolyError with output(self, logger) {
  let s = match self {
    NotExactDivision => "not exact division"
    NotUnivariate => "not univariate"
    DivisionByZeroPoly => "division by zero polynomial"
  }
  logger.write_string(s)
}

///|
/// Immutable sparse polynomial with Rational coefficients.
///
/// Invariant:
/// - `terms` sorted by Monomial::compare_canonical;
/// - no zero coefficients, no duplicate monomials.
pub struct Polynomial {
  priv terms : Array[(Monomial, @arithmetic.Rational)]
} derive(Eq, Debug)

///|
/// Helper: rebuild from unsorted terms, dropping zeros and merging duplicates.
fn normalize(terms : Array[(Monomial, @arithmetic.Rational)]) -> Polynomial {
  terms.sort_by(fn(a : (Monomial, @arithmetic.Rational), b : (Monomial, @arithmetic.Rational)) { a.0.compare_canonical(b.0) })
  let out : Array[(Monomial, @arithmetic.Rational)] = []
  for t in terms {
    if t.1.is_zero() {
      continue
    }
    if out.length() > 0 && out[out.length() - 1].0.equal(t.0) {
      let last = out[out.length() - 1]
      let s = last.1.add(t.1)
      if s.is_zero() {
        let _ = out.pop()
      } else {
        out[out.length() - 1] = (t.0, s)
      }
    } else {
      out.push(t)
    }
  }
  Polynomial::{ terms: out }
}

///|
pub fn Polynomial::zero() -> Polynomial {
  Polynomial::{ terms: [] }
}

///|
pub fn Polynomial::one() -> Polynomial {
  Polynomial::{ terms: [(Monomial::one(), @arithmetic.Rational::one())] }
}

///|
pub fn Polynomial::constant(c : @arithmetic.Rational) -> Polynomial {
  if c.is_zero() {
    Polynomial::zero()
  } else {
    Polynomial::{ terms: [(Monomial::one(), c)] }
  }
}

///|
/// x_i^e as a polynomial.
pub fn Polynomial::variable(i : Int, e? : Int = 1) -> Polynomial {
  if e <= 0 {
    Polynomial::one()
  } else {
    Polynomial::{ terms: [(Monomial::make([(i, e)]), @arithmetic.Rational::one())] }
  }
}

///|
/// Build from (var, exp) pairs with coefficient 1, e.g. x^2*y.
pub fn Polynomial::mono(pairs : Array[(Int, Int)], c? : @arithmetic.Rational = @arithmetic.Rational::one()) -> Polynomial {
  if c.is_zero() {
    Polynomial::zero()
  } else {
    Polynomial::{ terms: [(Monomial::make(pairs), c)] }
  }
}

///|
/// Build from raw (monomial, coeff) term list.
pub fn Polynomial::from_terms(terms : Array[(Monomial, @arithmetic.Rational)]) -> Polynomial {
  normalize(terms)
}

///|
pub fn Polynomial::is_zero(self : Polynomial) -> Bool {
  self.terms.is_empty()
}

///|
pub fn Polynomial::is_one(self : Polynomial) -> Bool {
  self.terms.length() == 1 && self.terms[0].0.is_one() && self.terms[0].1.is_one()
}

///|
pub fn Polynomial::is_constant(self : Polynomial) -> Bool {
  self.terms.length() <= 1 && (self.terms.is_empty() || self.terms[0].0.is_one())
}

///|
pub fn Polynomial::constant_value(self : Polynomial) -> @arithmetic.Rational {
  if self.terms.is_empty() {
    @arithmetic.Rational::zero()
  } else if self.terms[0].0.is_one() {
    self.terms[0].1
  } else {
    @arithmetic.Rational::zero()
  }
}

///|
/// All variable indices involved (ascending).
pub fn Polynomial::variables(self : Polynomial) -> Array[Int] {
  let set : Map[Int, Bool] = {}
  for t in self.terms {
    for p in t.0.exponents() {
      set[p.0] = true
    }
  }
  let out : Array[Int] = []
  for k in set.keys() {
    out.push(k)
  }
  out.sort()
  out
}

///|
pub fn Polynomial::terms_of(self : Polynomial) -> Array[(Monomial, @arithmetic.Rational)] {
  self.terms
}

///|
/// Term count.
pub fn Polynomial::length(self : Polynomial) -> Int {
  self.terms.length()
}

///|
/// Add: merge two canonically sorted term arrays.
pub fn Polynomial::add(self : Polynomial, other : Polynomial) -> Polynomial {
  let a = self.terms
  let b = other.terms
  let out : Array[(Monomial, @arithmetic.Rational)] = []
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    let ta = a[i]
    let tb = b[j]
    let c = ta.0.compare_canonical(tb.0)
    if c < 0 {
      out.push(ta)
      i = i + 1
    } else if c > 0 {
      out.push(tb)
      j = j + 1
    } else {
      let s = ta.1.add(tb.1)
      if not(s.is_zero()) {
        out.push((ta.0, s))
      }
      i = i + 1
      j = j + 1
    }
  }
  while i < a.length() {
    out.push(a[i])
    i = i + 1
  }
  while j < b.length() {
    out.push(b[j])
    j = j + 1
  }
  Polynomial::{ terms: out }
}

///|
pub fn Polynomial::sub(self : Polynomial, other : Polynomial) -> Polynomial {
  self.add(other.neg())
}

///|
pub fn Polynomial::neg(self : Polynomial) -> Polynomial {
  let out : Array[(Monomial, @arithmetic.Rational)] = []
  for t in self.terms {
    out.push((t.0, t.1.neg()))
  }
  Polynomial::{ terms: out }
}

///|
pub fn Polynomial::mul(self : Polynomial, other : Polynomial) -> Polynomial {
  if self.is_zero() || other.is_zero() {
    return Polynomial::zero()
  }
  // accumulate into a hash map keyed by monomial string-free equality via
  // canonical list; MoonBit Map works on Eq+Hash keys, so wrap in small key.
  let acc : Map[String, @arithmetic.Rational] = {}
  let key_of : (Array[(Int, Int)]) -> String = fn(vars) {
    let sb = StringBuilder::new()
    for p in vars {
      sb.write_string("\{p.0}:\{p.1};")
    }
    sb.to_string()
  }
  let varmap : Map[String, Array[(Int, Int)]] = {}
  for ta in self.terms {
    for tb in other.terms {
      let m = ta.0.mul(tb.0)
      let k = key_of(m.exponents())
      varmap[k] = m.exponents()
      match acc.get(k) {
        Some(v) => acc[k] = v.add(ta.1.mul(tb.1))
        None => acc[k] = ta.1.mul(tb.1)
      }
    }
  }
  let raw : Array[(Monomial, @arithmetic.Rational)] = []
  for k in acc.keys() {
    raw.push((Monomial::make(varmap[k]), acc[k]))
  }
  normalize(raw)
}

///|
pub fn Polynomial::pow(self : Polynomial, e : Int) -> Polynomial {
  if e < 0 {
    abort("Polynomial::pow: negative exponent")
  }
  let mut result = Polynomial::one()
  let mut k = 0
  while k < e {
    result = result.mul(self)
    k = k + 1
  }
  result
}

///|
/// Scalar multiplication.
pub fn Polynomial::scale(self : Polynomial, c : @arithmetic.Rational) -> Polynomial {
  if c.is_zero() {
    return Polynomial::zero()
  }
  let out : Array[(Monomial, @arithmetic.Rational)] = []
  for t in self.terms {
    out.push((t.0, t.1.mul(c)))
  }
  Polynomial::{ terms: out }
}

///|
/// Exact division by a rational scalar.
pub fn Polynomial::div_scalar(self : Polynomial, c : @arithmetic.Rational) -> Result[Polynomial, PolyError] {
  match c.inv() {
    Ok(cinv) => Ok(self.scale(cinv))
    Err(_) => Err(DivisionByZeroPoly)
  }
}

///|
/// Exact division by a monomial (used by term reduction later).
pub fn Polynomial::div_monomial(self : Polynomial, m : Monomial) -> Result[Polynomial, PolyError] {
  if m.is_one() {
    return Ok(self)
  }
  let out : Array[(Monomial, @arithmetic.Rational)] = []
  for t in self.terms {
    match t.0.divide(m) {
      Some(q) => out.push((q, t.1))
      None => return Err(NotExactDivision)
    }
  }
  Ok(Polynomial::{ terms: out })
}

///|
/// Leading term under a chosen monomial order (strategy parameter, red line #2).
/// `nvars` is the number of variables in the ambient ring (>= any used index + 1).
pub fn Polynomial::leading_term(self : Polynomial, order : MonomialOrder, nvars : Int) -> Option[(Monomial, @arithmetic.Rational)] {
  if self.is_zero() {
    return None
  }
  let mut best = self.terms[0]
  for t in self.terms {
    let c = t.0.cmp_by(best.0, order, nvars)
    if c > 0 {
      best = t
    }
  }
  Some(best)
}

///|
/// Leading coefficient under the given order.
pub fn Polynomial::leading_coeff(self : Polynomial, order : MonomialOrder, nvars : Int) -> @arithmetic.Rational {
  match self.leading_term(order, nvars) {
    Some(t) => t.1
    None => @arithmetic.Rational::zero()
  }
}

///|
/// Total degree (max over terms); zero polynomial has degree -1 by convention.
/// Proved: result >= -1. Relies on the callee contract of total_degree (>= 0).
pub fn Polynomial::degree(self : Polynomial) -> Int where {
  proof_ensure: result => -1 <= result,
} {
  let mut d = -1
  for i = 0; i < self.terms.length(); {
    let td = self.terms[i].0.total_degree()
    if td > d {
      d = td
    }
    continue i + 1
  } where {
    proof_invariant: -1 <= d,
    proof_invariant: 0 <= i,
    proof_invariant: i <= self.terms.length(),
  }
  d
}

///|
/// Content: gcd of numerators / lcm of denominators (positive).
pub fn Polynomial::content(self : Polynomial) -> @arithmetic.Rational {
  if self.is_zero() {
    return @arithmetic.Rational::zero()
  }
  let zero : BigInt = BigInt::from_int(0)
  let one : BigInt = BigInt::from_int(1)
  let mut g = zero
  let mut l = one
  for t in self.terms {
    g = @arithmetic.bigint_gcd(g, t.1.numerator())
    // lcm of denominators
    let d = t.1.denominator()
    l = l.mul(d).div(@arithmetic.bigint_gcd(l, d))
  }
  match @arithmetic.Rational::make(g, l) {
    Ok(c) => c
    Err(_) => abort("content: unreachable, denominators positive")
  }
}

///|
/// Primitive part: self divided by its content (zero polynomial -> zero).
pub fn Polynomial::primitive_part(self : Polynomial) -> Result[Polynomial, PolyError] {
  let c = self.content()
  if c.is_zero() {
    return Ok(Polynomial::zero())
  }
  self.div_scalar(c)
}

///|
/// Remainder of p divided by q over Q (multivariate supported for degree
/// elimination only in later iterations; here univariate Euclid remainder).
pub fn Polynomial::rem_univariate(self : Polynomial, q : Polynomial) -> Result[Polynomial, PolyError] {
  if q.is_zero() {
    return Err(DivisionByZeroPoly)
  }
  if self.variables().length() > 1 || q.variables().length() > 1 {
    return Err(NotUnivariate)
  }
  let mut r = self
  let nvars = 1
  while r.degree() >= q.degree() && !r.is_zero() {
    let dr = match r.leading_term(Lex, nvars) {
      Some(t) => t
      None => break
    }
    let dq = match q.leading_term(Lex, nvars) {
      Some(t) => t
      None => break
    }
    // factor = lc_r / lc_q * x^(deg_r - deg_q)
    let lc_ratio = match dr.1.div(dq.1) {
      Ok(v) => v
      Err(_) => return Err(DivisionByZeroPoly)
    }
    let vi = if dr.0.is_one() {
      0
    } else {
      dr.0.exponents()[0].0
    }
    let deg_diff = dr.0.total_degree() - dq.0.total_degree()
    let factor = Polynomial::mono([(vi, deg_diff)], c=lc_ratio)
    r = r.sub(factor.mul(q))
  }
  Ok(r)
}

///|
/// Univariate GCD over Q via Euclid, normalized monic; result is the primitive
/// part scaled to monic leading coefficient. Error if inputs are not univariate.
pub fn Polynomial::gcd_univariate(self : Polynomial, other : Polynomial) -> Result[Polynomial, PolyError] {
  let mut a = self
  let mut b = other
  while !b.is_zero() {
    match a.rem_univariate(b) {
      Ok(r) => {
        a = b
        b = r
      }
      Err(e) => return Err(e)
    }
  }
  if a.is_zero() {
    return Ok(Polynomial::zero())
  }
  // normalize to monic
  let lc = a.leading_coeff(Lex, 1)
  match a.div_scalar(lc) {
    Ok(m) => Ok(m)
    Err(e) => Err(e)
  }
}

///|
/// Deterministic hash: fold over canonically sorted terms.
pub fn Polynomial::hash(self : Polynomial) -> Int {
  let mut h = 19
  for t in self.terms {
    h = h * 31 + t.0.hash()
    h = h * 31 + t.1.hash()
  }
  h
}

///|
pub fn Polynomial::to_string(self : Polynomial) -> String {
  if self.is_zero() {
    return "0"
  }
  let parts : Array[String] = []
  for t in self.terms {
    let coef = t.1.to_string()
    let mono = t.0.to_string()
    if mono == "1" {
      parts.push(coef)
    } else {
      parts.push("\{coef}*\{mono}")
    }
  }
  parts.join(" + ")
}

///|
pub impl Show for Polynomial with output(self, logger) {
  logger.write_string(self.to_string())
}
