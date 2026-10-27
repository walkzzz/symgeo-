///|
/// Deterministic monomial: sorted sparse exponent vector.
///
/// Invariant:
/// - variables strictly ascending, no duplicates;
/// - all exponents > 0 (absent variable = exponent 0);
/// - variable index is a nonnegative Int.
pub struct Monomial {
  priv vars : Array[(Int, Int)]
} derive(Eq, Debug)

///|
/// Build from (var, exp) pairs; filters zero exponents, sorts, merges duplicates.
pub fn Monomial::make(pairs : Array[(Int, Int)]) -> Monomial {
  let filtered : Array[(Int, Int)] = []
  for p in pairs {
    if p.1 > 0 {
      filtered.push(p)
    }
  }
  filtered.sort_by(fn(a, b) { a.0.compare(b.0) })
  // merge duplicates (same var appearing twice)
  let merged : Array[(Int, Int)] = []
  for p in filtered {
    if merged.length() > 0 && merged[merged.length() - 1].0 == p.0 {
      let last = merged[merged.length() - 1]
      merged[merged.length() - 1] = (p.0, last.1 + p.1)
    } else {
      merged.push(p)
    }
  }
  Monomial::{ vars: merged }
}

///|
pub fn Monomial::one() -> Monomial {
  Monomial::{ vars: [] }
}

///|
pub fn Monomial::is_one(self : Monomial) -> Bool {
  self.vars.is_empty()
}

///|
pub fn Monomial::exponents(self : Monomial) -> Array[(Int, Int)] {
  self.vars
}

///|
/// Product of two monomials: merge exponent vectors by variable.
pub fn Monomial::mul(self : Monomial, other : Monomial) -> Monomial {
  let out : Array[(Int, Int)] = []
  let a = self.vars
  let b = other.vars
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    let pa = a[i]
    let pb = b[j]
    if pa.0 < pb.0 {
      out.push(pa)
      i = i + 1
    } else if pa.0 > pb.0 {
      out.push(pb)
      j = j + 1
    } else {
      out.push((pa.0, pa.1 + pb.1))
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
  Monomial::{ vars: out }
}

///|
/// Divide by another monomial; None if not exactly divisible.
pub fn Monomial::divide(self : Monomial, other : Monomial) -> Option[Monomial] {
  // check other's vars are a subset with <= exponents
  let a = self.vars
  let b = other.vars
  for pb in b {
    // find pa with same var
    let mut found = false
    for pa in a {
      if pa.0 == pb.0 && pa.1 < pb.1 {
        return None
      }
      if pa.0 == pb.0 {
        found = true
        break
      }
    }
    if not(found) {
      // other has a variable self lacks -> exponent 0 < pb.1 -> not divisible
      return None
    }
  }
  let out : Array[(Int, Int)] = []
  for pa in a {
    let mut e = pa.1
    for pb in b {
      if pb.0 == pa.0 {
        e = e - pb.1
        break
      }
    }
    if e > 0 {
      out.push((pa.0, e))
    }
  }
  Some(Monomial::{ vars: out })
}

///|
/// Divides check: does `other` divide `self`?
pub fn Monomial::divides(self : Monomial, other : Monomial) -> Bool {
  other.divide(self) is Some(_)
}

///|
/// Total degree = sum of exponents.
/// Nonnegativity is established on the proof model `sum_degrees` (proof_model.mbt):
/// this Array-backed body is outside the current moon prove supported subset.
pub fn Monomial::total_degree(self : Monomial) -> Int {
  let mut d = 0
  for p in self.vars {
    d = d + p.1
  }
  d
}

///|
/// Number of variables involved.
pub fn Monomial::num_vars(self : Monomial) -> Int {
  self.vars.length()
}

///|
/// Canonical storage order: lexicographic on the sparse (var, exp) list.
/// Deterministic and total; used for term-array sorting (independent of the
/// mathematical monomial order strategy).
pub fn Monomial::compare_canonical(self : Monomial, other : Monomial) -> Int {
  let a = self.vars
  let b = other.vars
  let n = if a.length() < b.length() { a.length() } else { b.length() }
  for i in 0..<n {
    let pa = a[i]
    let pb = b[i]
    if pa.0 != pb.0 {
      return pa.0.compare(pb.0)
    }
    if pa.1 != pb.1 {
      return pa.1.compare(pb.1)
    }
  }
  a.length().compare(b.length())
}

///|
/// Expand to a dense exponent array of length nvars.
fn expand(vars : Array[(Int, Int)], nvars : Int) -> Array[Int] {
  let exps : Array[Int] = Array::make(nvars, 0)
  for p in vars {
    if p.0 < nvars {
      exps[p.0] = p.1
    }
  }
  exps
}

///|
/// Pure lex order over `nvars` variables: first differing exponent decides.
pub fn Monomial::compare_lex(self : Monomial, other : Monomial, nvars : Int) -> Int {
  let a = expand(self.vars, nvars)
  let b = expand(other.vars, nvars)
  for i in 0..<nvars {
    if a[i] != b[i] {
      return a[i].compare(b[i])
    }
  }
  0
}

///|
/// Grevlex order: total degree first; ties broken from the last variable
/// backwards, where the *smaller* exponent wins (standard grevlex).
pub fn Monomial::compare_grevlex(self : Monomial, other : Monomial, nvars : Int) -> Int {
  let da = self.total_degree()
  let db = other.total_degree()
  if da != db {
    return da.compare(db)
  }
  let a = expand(self.vars, nvars)
  let b = expand(other.vars, nvars)
  for i = nvars - 1; i >= 0; i = i - 1 {
    if a[i] != b[i] {
      // smaller exponent at the last differing position => larger monomial
      return b[i].compare(a[i])
    }
  }
  0
}

///|
/// Monomial order strategy (extension red line #2).
pub(all) enum MonomialOrder {
  Lex
  Grevlex
} derive(Eq, Debug)

///|
pub fn Monomial::cmp_by(self : Monomial, other : Monomial, order : MonomialOrder, nvars : Int) -> Int {
  match order {
    Lex => self.compare_lex(other, nvars)
    Grevlex => self.compare_grevlex(other, nvars)
  }
}

///|
pub fn Monomial::hash(self : Monomial) -> Int {
  let mut h = 17
  for p in self.vars {
    h = h * 31 + p.0
    h = h * 31 + p.1
  }
  h
}

///|
pub fn Monomial::to_string(self : Monomial) -> String {
  if self.is_one() {
    "1"
  } else {
    let parts : Array[String] = []
    for p in self.vars {
      if p.1 == 1 {
        parts.push("x\{p.0}")
      } else {
        parts.push("x\{p.0}^\{p.1}")
      }
    }
    parts.join("*")
  }
}
