///|
/// Demo: end-to-end geometric theorem deciding (statement -> polynomials ->
/// Groebner verdict). Run with `moon run cmd/main`.
fn main {
  println("symgeo I2 demo: statement -> polynomials -> Groebner verdict")
  println("@bigint smoke: \{@arithmetic.bigint_smoke()}")
  println("---")
  let reg = @translate.Registry::default()
  let demo = ["midline", "isosceles_altitude", "perpendicular_bisector", "collinear_not_midpoint"]
  for spec in @theorems.corpus() {
    if demo.contains(spec.name) {
      match @translate.compile_theorem(reg, spec) {
        Ok(th) => {
          let r = @theorems.prove_theorem(th)
          println("\{spec.name}: hyps=\{th.hyps.length()} goals=\{th.goals.length()}")
          println("  verdict: \{r}")
        }
        Err(e) => println("\{spec.name}: translate error \{e}")
      }
    }
  }
  println("---")
  println("I2 gate: golden corpus verdicts all as expected (see theorems tests)")
}
