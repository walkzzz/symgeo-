///|
/// Explicit error type for exact arithmetic (plan rule: no silent fallbacks).
pub(all) enum ArithmeticError {
  DivByZero
} derive(Eq, Debug)

///|
pub impl Show for ArithmeticError with output(self, logger) {
  logger.write_string("DivByZero")
}

///|
/// Greatest common divisor of two BigInts (Euclid on absolute values, iterative).
pub fn bigint_gcd(a : BigInt, b : BigInt) -> BigInt {
  let mut x = big_abs(a)
  let mut y = big_abs(b)
  while !y.is_zero() {
    let t = x.mod(y)
    x = y
    y = t
  }
  x
}

///|
pub fn big_abs(a : BigInt) -> BigInt {
  let zero : BigInt = BigInt::from_int(0)
  if a.compare(zero) < 0 {
    a.neg()
  } else {
    a
  }
}

///|
fn big_sign(a : BigInt) -> Int {
  a.compare(BigInt::from_int(0))
}

///|
/// Exact rational number over BigInt.
///
/// Invariant (maintained by all constructors below):
/// - `den` is always positive;
/// - `gcd(|num|, den) == 1`;
/// - zero is represented as `0/1`.
pub struct Rational {
  priv num : BigInt
  priv den : BigInt
} derive(Eq, Debug)

///|
/// Construct from integer components; normalizes and rejects zero denominator.
pub fn Rational::make(num : BigInt, den : BigInt) -> Result[Rational, ArithmeticError] {
  if den.is_zero() {
    Err(DivByZero)
  } else {
    let (n1, d1) = if big_sign(den) < 0 { (num.neg(), den.neg()) } else { (num, den) }
    if n1.is_zero() {
      Ok(Rational::zero())
    } else {
      let g = bigint_gcd(n1, d1)
      Ok(Rational::{ num: n1.div(g), den: d1.div(g) })
    }
  }
}

///|
pub fn Rational::zero() -> Rational {
  Rational::{ num: BigInt::from_int(0), den: BigInt::from_int(1) }
}

///|
pub fn Rational::one() -> Rational {
  Rational::{ num: BigInt::from_int(1), den: BigInt::from_int(1) }
}

///|
pub fn Rational::from_int(v : Int) -> Rational {
  Rational::{ num: BigInt::from_int(v), den: BigInt::from_int(1) }
}

///|
/// Construct a "small" rational n/d without error plumbing (d must be nonzero;
/// panics otherwise — use `make` for fallible construction).
pub fn Rational::from_int2(n : Int, d : Int) -> Rational {
  match Rational::make(BigInt::from_int(n), BigInt::from_int(d)) {
    Ok(r) => r
    Err(_) => abort("Rational::from_int2: zero denominator")
  }
}

///|
pub fn Rational::is_zero(self : Rational) -> Bool {
  self.num.is_zero()
}

///|
pub fn Rational::is_one(self : Rational) -> Bool {
  self.num.equal(BigInt::from_int(1)) && self.den.equal(BigInt::from_int(1))
}

///|
pub fn Rational::sign(self : Rational) -> Int {
  big_sign(self.num)
}

///|
pub fn Rational::is_positive(self : Rational) -> Bool {
  self.sign() > 0
}

///|
pub fn Rational::is_negative(self : Rational) -> Bool {
  self.sign() < 0
}

///|
pub fn Rational::numerator(self : Rational) -> BigInt {
  self.num
}

///|
pub fn Rational::denominator(self : Rational) -> BigInt {
  self.den
}

///|
pub fn Rational::add(self : Rational, other : Rational) -> Rational {
  // a/b + c/d = (ad + cb) / bd, then normalized by make
  let a = self.num
  let b = self.den
  let c = other.num
  let d = other.den
  let n = a.mul(d).add(c.mul(b))
  let q = b.mul(d)
  match Rational::make(n, q) {
    Ok(r) => r
    Err(_) => abort("Rational::add: unreachable, denominators are nonzero")
  }
}

///|
pub fn Rational::sub(self : Rational, other : Rational) -> Rational {
  self.add(other.neg())
}

///|
pub fn Rational::mul(self : Rational, other : Rational) -> Rational {
  match Rational::make(self.num.mul(other.num), self.den.mul(other.den)) {
    Ok(r) => r
    Err(_) => abort("Rational::mul: unreachable, denominators are nonzero")
  }
}

///|
pub fn Rational::neg(self : Rational) -> Rational {
  Rational::{ num: self.num.neg(), den: self.den }
}

///|
pub fn Rational::div(self : Rational, other : Rational) -> Result[Rational, ArithmeticError] {
  if other.is_zero() {
    Err(DivByZero)
  } else {
    Rational::make(self.num.mul(other.den), self.den.mul(other.num))
  }
}

///|
pub fn Rational::inv(self : Rational) -> Result[Rational, ArithmeticError] {
  Rational::one().div(self)
}

///|
/// Exact power with integer exponent (negative = inverse of positive power).
pub fn Rational::pow(self : Rational, e : Int) -> Result[Rational, ArithmeticError] {
  if e < 0 {
    match self.inv() {
      Ok(inv) => inv.pow(-e)
      Err(err) => Err(err)
    }
  } else {
    let mut result = Rational::one()
    for _i in 0..<e {
      result = result.mul(self)
    }
    Ok(result)
  }
}

///|
pub fn Rational::compare(self : Rational, other : Rational) -> Int {
  // ad vs cb with positive denominators
  self.num.mul(other.den).compare(other.num.mul(self.den))
}

///|
/// Deterministic hash of the normalized form.
pub fn Rational::hash(self : Rational) -> Int {
  let h1 = self.num.hash()
  let h2 = self.den.hash()
  h1 * 31 + h2
}

///|
pub fn Rational::to_string(self : Rational) -> String {
  if self.den.equal(BigInt::from_int(1)) {
    self.num.to_string()
  } else {
    "\{self.num.to_string()}/\{self.den.to_string()}"
  }
}

///|
pub impl Show for Rational with output(self, logger) {
  logger.write_string(self.to_string())
}

///|
/// Ring interface (extension red line #1: coefficient domain parameterizable).
/// Rational is the reference instance; ModP / number fields can implement this
/// later without touching the polynomial layer's algorithms.
pub trait Ring {
  zero() -> Self
  one() -> Self
  add(Self, Self) -> Self
  sub(Self, Self) -> Self
  mul(Self, Self) -> Self
  neg(Self) -> Self
  is_zero_value(Self) -> Bool
}

///|
impl Ring for Rational with zero() {
  Rational::zero()
}

///|
impl Ring for Rational with one() {
  Rational::one()
}

///|
impl Ring for Rational with add(self, other) {
  self.add(other)
}

///|
impl Ring for Rational with sub(self, other) {
  self.sub(other)
}

///|
impl Ring for Rational with mul(self, other) {
  self.mul(other)
}

///|
impl Ring for Rational with neg(self) {
  self.neg()
}

///|
impl Ring for Rational with is_zero_value(self) {
  self.is_zero()
}
