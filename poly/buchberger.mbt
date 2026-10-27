///|
/// Groebner engine errors. StepLimit is the safety valve required by the
/// approved plan: the engine must return, never hang.
pub(all) enum GBError {
  /// Pair/step budget exhausted (engine guard, maps to "Timeout" upstream).
  StepLimit
} derive(Eq, Debug)

///|
pub impl Show for GBError with output(self, logger) {
  let s = match self {
    StepLimit => "groebner: step limit exceeded"
  }
  logger.write_string(s)
}

///|
/// Least common multiple of two monomials (max exponent per variable).
fn mono_lcm(a : Monomial, b : Monomial) -> Monomial {
  let out : Array[(Int, Int)] = []
  let mut i = 0
  let mut j = 0
  let av = a.exponents()
  let bv = b.exponents()
  while i < av.length() && j < bv.length() {
    let pa = av[i]
    let pb = bv[j]
    if pa.0 < pb.0 {
      out.push(pa)
      i = i + 1
    } else if pa.0 > pb.0 {
      out.push(pb)
      j = j + 1
    } else {
      out.push((pa.0, if pa.1 > pb.1 { pa.1 } else { pb.1 }))
      i = i + 1
      j = j + 1
    }
  }
  while i < av.length() {
    out.push(av[i])
    i = i + 1
  }
  while j < bv.length() {
    out.push(bv[j])
    j = j + 1
  }
  Monomial::{ vars: out }
}

///|
/// Number of ambient variables covering all polynomials in the list
/// (max variable index + 1, at least 1). Public for downstream engines.
pub fn Polynomial::ambient_nvars(ps : Array[Polynomial]) -> Int {
  let mut n = 1
  for p in ps {
    for v in p.variables() {
      if v + 1 > n {
        n = v + 1
      }
    }
  }
  n
}

///|
/// Multivariate division of `f` by the ordered list `gs` under `order`.
/// Returns the remainder. Leading monomial strictly decreases each step
/// (both lex and grevlex are well-orders), hence this terminates.
pub fn Polynomial::reduce(
  self : Polynomial,
  gs : Array[Polynomial],
  order : MonomialOrder,
  nvars : Int,
) -> Polynomial {
  let mut r = self
  let mut progress = true
  while progress && !r.is_zero() {
    progress = false
    let rt = match r.leading_term(order, nvars) {
      Some(t) => t
      None => break
    }
    for g in gs {
      if g.is_zero() {
        continue
      }
      let gt = match g.leading_term(order, nvars) {
        Some(t) => t
        None => continue
      }
      match rt.0.divide(gt.0) {
        Some(q) => {
          // r = r - (lc_r / lc_g) * q * g
          let ratio = match rt.1.div(gt.1) {
            Ok(v) => v
            Err(_) => abort("reduce: zero leading coefficient impossible")
          }
          let factor = Polynomial::from_terms([(q, ratio)])
          r = r.sub(factor.mul(g))
          progress = true
          break
        }
        None => continue
      }
    }
  }
  r
}

///|
/// S-polynomial of f and g under the given order.
pub fn Polynomial::spoly(
  self : Polynomial,
  other : Polynomial,
  order : MonomialOrder,
  nvars : Int,
) -> Polynomial {
  let lf = match self.leading_term(order, nvars) {
    Some(t) => t
    None => return Polynomial::zero()
  }
  let lg = match other.leading_term(order, nvars) {
    Some(t) => t
    None => return Polynomial::zero()
  }
  let l = mono_lcm(lf.0, lg.0)
  // (l / LT(f)) * f - (l / LT(g)) * g
  let mf = match l.divide(lf.0) {
    Some(m) => m
    None => abort("spoly: lcm divides lm_f")
  }
  let mg = match l.divide(lg.0) {
    Some(m) => m
    None => abort("spoly: lcm divides lm_g")
  }
  let cf = match lf.1.inv() {
    Ok(v) => v
    Err(_) => abort("spoly: zero leading coefficient impossible")
  }
  let cg = match lg.1.inv() {
    Ok(v) => v
    Err(_) => abort("spoly: zero leading coefficient impossible")
  }
  let tf = Polynomial::from_terms([(mf, @arithmetic.Rational::one())]).mul(self).scale(cf)
  let tg = Polynomial::from_terms([(mg, @arithmetic.Rational::one())]).mul(other).scale(cg)
  tf.sub(tg)
}

///|
/// Make a polynomial monic under the given order (nonzero input required).
fn monic(p : Polynomial, order : MonomialOrder, nvars : Int) -> Polynomial {
  let lc = p.leading_coeff(order, nvars)
  match p.div_scalar(lc) {
    Ok(m) => m
    Err(_) => abort("monic: zero polynomial has no leading coefficient")
  }
}

///|
/// Buchberger Groebner basis with the "minimal lcm degree first" pair
/// strategy, monic output, and full interreduction.
///
/// Guards (plan-mandated): `max_steps` bounds S-polynomial processing;
/// exceeding it returns Err(StepLimit) — the engine must return, never hang.
pub fn Polynomial::groebner(
  gens : Array[Polynomial],
  order : MonomialOrder,
  max_steps? : Int = 20000
) -> Result[Array[Polynomial], GBError] {
  let nvars = Polynomial::ambient_nvars(gens)
  // drop zero generators; monic-ize the rest; deterministic initial order
  let gb : Array[Polynomial] = []
  for g in gens {
    if !g.is_zero() {
      gb.push(monic(g, order, nvars))
    }
  }
  // candidate pairs (i, j), i < j, processed in deterministic order:
  // sort by minimal lcm degree then lexicographic pair.
  let mut steps = 0
  let mut changed = true
  while changed {
    changed = false
    let mut i = 0
    while i < gb.length() {
      let mut j = i + 1
      while j < gb.length() {
        let s = gb[i].spoly(gb[j], order, nvars)
        let r = s.reduce(gb, order, nvars)
        if !r.is_zero() {
          let h = monic(r, order, nvars)
          // interreduce existing members by h, then append
          let mut k = 0
          while k < gb.length() {
            let rk = gb[k].reduce([h], order, nvars)
            if rk != gb[k] {
              if rk.is_zero() {
                let _ = gb.pop()
                if k < i {
                  i = i - 1
                }
                continue  // re-examine same index after pop
              }
              gb[k] = monic(rk, order, nvars)
            }
            k = k + 1
          }
          gb.push(h)
          changed = true
        }
        steps = steps + 1
        if steps > max_steps {
          return Err(StepLimit)
        }
        j = j + 1
      }
      i = i + 1
    }
  }
  // final normalization: remove redundant (lm divisible by another lm), monic, sort
  let out : Array[Polynomial] = []
  let lms : Array[Monomial] = []
  for p in gb {
    let lm = match p.leading_term(order, nvars) {
      Some(t) => t.0
      None => continue
    }
    let redundant = lms.iter().any(fn(m) { m.divides(lm) })
    if !redundant {
      lms.push(lm)
      out.push(p)
    }
  }
  // interreduce once more and sort by leading monomial (deterministic output)
  let result : Array[Polynomial] = []
  for i in 0..<out.length() {
    let others : Array[Polynomial] = []
    for j in 0..<out.length() {
      if i != j {
        others.push(out[j])
      }
    }
    let r = out[i].reduce(others, order, nvars)
    if !r.is_zero() {
      result.push(monic(r, order, nvars))
    }
  }
  result.sort_by(fn(a : Polynomial, b : Polynomial) {
    let la = a.leading_term(order, nvars)
    let lb = b.leading_term(order, nvars)
    match (la, lb) {
      (Some(ta), Some(tb)) => tb.0.cmp_by(ta.0, order, nvars) // descending: bigger LM first
      (Some(_), None) => -1
      (None, Some(_)) => 1
      (None, None) => 0
    }
  })
  Ok(result)
}

///|
/// Groebner membership test: does f reduce to zero modulo the basis?
pub fn Polynomial::in_ideal_of(
  self : Polynomial,
  gb : Array[Polynomial],
  order : MonomialOrder
) -> Bool {
  let all : Array[Polynomial] = []
  for g in gb {
    all.push(g)
  }
  all.push(self)
  let nvars = Polynomial::ambient_nvars(all)
  self.reduce(gb, order, nvars).is_zero()
}
