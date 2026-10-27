///|
/// Helpers
fn x(i : Int) -> Polynomial {
  Polynomial::variable(i)
}

///|
test "reduce: basic remainder" {
  // f = x0^2 ; gs = [x0 - 1] -> remainder 1
  let f = x(0).mul(x(0))
  let g = x(0).sub(Polynomial::constant(@arithmetic.Rational::from_int(1)))
  let r = f.reduce([g], Lex, 1)
  assert_eq(r, Polynomial::one())
}

///|
test "reduce: zero remainder when divisible" {
  // f = x0^2 - x1^2 ; gs = [x0 - x1] -> 0
  let f = x(0).mul(x(0)).sub(x(1).mul(x(1)))
  let g = x(0).sub(x(1))
  let r = f.reduce([g], Lex, 2)
  assert_true(r.is_zero())
}

///|
test "spoly: x^2-y and y^2-x" {
  let f = x(0).mul(x(0)).sub(x(1))
  let g = x(1).mul(x(1)).sub(x(0))
  // Under Grevlex (degree-first): LM(f)=x0^2, LM(g)=x1^2.
  // S = (l/LT(f))f - (l/LT(g))g = x1^2(x0^2-x1) - x0^2(x1^2-x0) = x0^3 - x1^3.
  // NOTE: under pure Lex, LM(x1^2-x0) is x0 (not x1^2) because lex ignores degree.
  let s = f.spoly(g, Grevlex, 2)
  let expect = x(0).pow(3).sub(x(1).pow(3))
  assert_eq(s, expect)
}

///|
test "groebner: linear system exact basis" {
  // <x0 + x1, x1 + 2> -> GB = {x1 + 2, x0 - x1}
  let p1 = x(0).add(x(1))
  let p2 = x(1).add(Polynomial::constant(@arithmetic.Rational::from_int(2)))
  match Polynomial::groebner([p1, p2], Lex) {
    Ok(gb) => {
      assert_eq(gb.length(), 2)
      // all original generators reduce to zero
      for g in [p1, p2] {
        assert_true(g.in_ideal_of(gb, Lex))
      }
      // output sorted by LM descending under lex (x0 dominates x1)
      let lm0 = gb[0].leading_term(Lex, 2).unwrap().0
      let lm1 = gb[1].leading_term(Lex, 2).unwrap().0
      assert_eq(lm0.to_string(), "x0")
      assert_eq(lm1.to_string(), "x1")
    }
    Err(e) => abort("unexpected: \{e}")
  }
}

///|
test "groebner: buchberger criterion on nonlinear system" {
  // <x0^2 - x1, x1^2 - x0>: all generators and S-pairs reduce to 0
  let p1 = x(0).mul(x(0)).sub(x(1))
  let p2 = x(1).mul(x(1)).sub(x(0))
  match Polynomial::groebner([p1, p2], Lex) {
    Ok(gb) => {
      for g in [p1, p2] {
        assert_true(g.in_ideal_of(gb, Lex))
      }
      // pairwise S-polynomials reduce to zero: the definition of a GB
      for i in 0..<gb.length() {
        for j in 0..<gb.length() {
          if i != j {
            let s = gb[i].spoly(gb[j], Lex, 2)
            assert_true(s.reduce(gb, Lex, 2).is_zero())
          }
        }
      }
    }
    Err(e) => abort("unexpected: \{e}")
  }
}

///|
test "groebner: membership via reduction (Rabinowitsch smoke)" {
  // <x0 - x1, x1 - 2> proves x0 - 2 = 0 by plain reduction
  let h1 = x(0).sub(x(1))
  let h2 = x(1).sub(Polynomial::constant(@arithmetic.Rational::from_int(2)))
  match Polynomial::groebner([h1, h2], Lex) {
    Ok(gb) => {
      let goal = x(0).sub(Polynomial::constant(@arithmetic.Rational::from_int(2)))
      assert_true(goal.in_ideal_of(gb, Lex))
      // unrelated goal does not reduce to zero
      let bad = x(0).sub(x(1).add(Polynomial::one()))
      assert_true(!bad.in_ideal_of(gb, Lex))
    }
    Err(e) => abort("unexpected: \{e}")
  }
}

///|
test "groebner: zero input and determinism" {
  let p = x(0).sub(x(1))
  match Polynomial::groebner([p, Polynomial::zero()], Grevlex) {
    Ok(gb) => assert_eq(gb.length(), 1)
    Err(e) => abort("unexpected: \{e}")
  }
  match Polynomial::groebner([p, Polynomial::zero()], Grevlex) {
    Ok(gb2) => {
      match Polynomial::groebner([p], Grevlex) {
        Ok(gb3) => assert_eq(gb2, gb3)
        Err(_) => abort("unreachable")
      }
    }
    Err(_) => abort("unreachable")
  }
}

///|
test "groebner: step limit guard returns" {
  // forcing StepLimit via a tight budget on a system that needs several steps
  let p1 = x(0).mul(x(0)).sub(x(1))
  let p2 = x(1).mul(x(1)).sub(x(0))
  match Polynomial::groebner([p1, p2], Lex, max_steps=0) {
    Err(StepLimit) => assert_true(true)
    Ok(_) => abort("expected StepLimit")
  }
}
