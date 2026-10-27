///|
test "corpus: expected verdicts" {
  let reg = @translate.Registry::default()
  for th_spec in corpus() {
    let th = match @translate.compile_theorem(reg, th_spec) {
      Ok(t) => t
      Err(e) => abort("compile failed for \{th_spec.name}: \{e}")
    }
    let r = prove_theorem(th)
    let ok = match r {
      @prover.Proved(_) => true
      @prover.Inconclusive(_) => th_spec.name == "collinear_not_midpoint"
      _ => false
    }
    assert_true(ok)
  }
}

///|
test "corpus: specific spot checks" {
  let reg = @translate.Registry::default()
  // 6. degenerate goal reduces identically -> Proved without engine
  for th_spec in corpus() {
    if th_spec.name == "collinear_degenerate" {
      let th = match @translate.compile_theorem(reg, th_spec) {
        Ok(t) => t
        Err(_) => abort("unreachable")
      }
      assert_true(th.goals[0].is_zero())
    }
    // 10. false conclusion must NOT be proved
    if th_spec.name == "collinear_not_midpoint" {
      let th = match @translate.compile_theorem(reg, th_spec) {
        Ok(t) => t
        Err(_) => abort("unreachable")
      }
      let r = prove_theorem(th)
      assert_true(r is @prover.Inconclusive(_))
    }
  }
}

///|
test "translate: unknown predicate and arity errors" {
  let reg = @translate.Registry::default()
  let vm = @translate.VarMap::new()
  match reg.translate(vm, "no_such_predicate", ["A", "B"]) {
    Err(@translate.UnknownPredicate(_)) => assert_true(true)
    _ => abort("expected UnknownPredicate")
  }
  match reg.translate(vm, "collinear", ["A", "B"]) {
    Err(@translate.WrongArity(_, 3, 2)) => assert_true(true)
    _ => abort("expected WrongArity")
  }
  // registry is open for extension (red line #4)
  let reg2 = @translate.Registry::default()
  reg2.register("always_zero", fn(_vm, _args) { Ok([@poly.Polynomial::zero()]) })
  match reg2.translate(@translate.VarMap::new(), "always_zero", []) {
    Ok(ps) => assert_true(ps[0].is_zero())
    Err(_) => abort("custom predicate must register")
  }
}
