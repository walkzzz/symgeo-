///|
/// Groebner-based decision engine (I2).
///
/// Strategy:
/// 1. If the goal reduces to zero modulo GB(hyps) -> Proved (ideal membership).
/// 2. Otherwise Rabinowitsch: introduce a fresh variable t and test whether
///    1 belongs to <hyps, t*goal - 1> (radical membership over Q, hence over
///    any extension field). 1 in the basis <=> some basis element is a
///    nonzero constant.
///
/// Guards: engine step limit maps to Timeout — the prover must return.
pub fn prove(
  hyps : Array[@poly.Polynomial],
  goal : @poly.Polynomial,
  order? : @poly.MonomialOrder = @poly.Grevlex,
  max_steps? : Int = 50000
) -> @prover.ProofResult {
  if goal.is_zero() {
    return @prover.Proved("goal is identically zero")
  }
  let all : Array[@poly.Polynomial] = []
  for h in hyps {
    all.push(h)
  }
  all.push(goal)
  let nvars = @poly.Polynomial::ambient_nvars(all)
  // Step 1: direct ideal membership
  let gb_hyps : Array[@poly.Polynomial] = []
  match @poly.Polynomial::groebner(hyps, order, max_steps=max_steps) {
    Ok(gb) => {
      for g in gb {
        gb_hyps.push(g)
      }
    }
    Err(_) => return @prover.Timeout
  }
  if goal.reduce(gb_hyps, order, nvars).is_zero() {
    return @prover.Proved("ideal membership via \{order} Groebner basis (\{gb_hyps.length()} elements)")
  }
  // Step 2: Rabinowitsch radical membership with fresh variable t
  let t = nvars
  let tgoal = @poly.Polynomial::variable(t).mul(goal).sub(@poly.Polynomial::one())
  let sys : Array[@poly.Polynomial] = []
  for h in hyps {
    sys.push(h)
  }
  sys.push(tgoal)
  match @poly.Polynomial::groebner(sys, order, max_steps=max_steps) {
    Ok(gb2) => {
      for p in gb2 {
        if p.is_constant() && !p.constant_value().is_zero() {
          return @prover.Proved("Rabinowitsch: 1 in <hyps, t*goal-1> (\{gb2.length()} basis elements)")
        }
      }
      @prover.Inconclusive("goal not in the radical of the hypothesis ideal")
    }
    Err(_) => @prover.Timeout
  }
}
