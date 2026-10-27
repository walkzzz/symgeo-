///|
/// Golden corpus (I2 gate): 10 theorems over the default registry.
/// 9 expected Proved, 1 expected Inconclusive (false conclusion).
pub fn corpus() -> Array[@translate.TheoremSpec] {
  [
    // 1. Midline theorem: M, N midpoints of AB, AC => MN // BC.
    {
      name: "midline",
      hyps: [("midpoint", ["M", "A", "B"]), ("midpoint", ["N", "A", "C"])],
      goals: [("parallel", ["M", "N", "B", "C"])],
    },
    // 2. Affine parallelogram ABCD (C-B = D-A) + M mid AC => M mid BD.
    {
      name: "parallelogram_diagonal_bisect",
      hyps: [("equal_vector", ["A", "B", "D", "C"]), ("midpoint", ["M", "A", "C"])],
      goals: [("midpoint", ["M", "B", "D"])],
    },
    // 3. Isosceles triangle CA = CB, M midpoint of AB => CM perp AB.
    {
      name: "isosceles_altitude",
      hyps: [("equal_distance", ["C", "A", "C", "B"]), ("midpoint", ["M", "A", "B"])],
      goals: [("perpendicular", ["C", "M", "A", "B"])],
    },
    // 4. Parallelogram with equal diagonals => adjacent sides perpendicular
    //    (an affine rectangle has a right angle).
    {
      name: "equal_diagonals_right_angle",
      hyps: [("equal_vector", ["A", "B", "D", "C"]), ("equal_distance", ["A", "C", "B", "D"])],
      goals: [("perpendicular", ["A", "B", "B", "C"])],
    },
    // 5. Collinearity is invariant under reversal.
    {
      name: "collinear_symmetry",
      hyps: [("collinear", ["A", "B", "C"])],
      goals: [("collinear", ["C", "B", "A"])],
    },
    // 6. Degenerate collinearity: collinear(A, B, A) is identically zero.
    {
      name: "collinear_degenerate",
      hyps: [],
      goals: [("collinear", ["A", "B", "A"])],
    },
    // 7. A midpoint lies on the segment line.
    {
      name: "midpoint_collinear",
      hyps: [("midpoint", ["M", "A", "B"])],
      goals: [("collinear", ["M", "A", "B"])],
    },
    // 8. Perpendicular-bisector theorem: C, D equidistant from A, B =>
    //    line CD perp AB.
    {
      name: "perpendicular_bisector",
      hyps: [("equal_distance", ["A", "C", "B", "C"]), ("equal_distance", ["A", "D", "B", "D"])],
      goals: [("perpendicular", ["C", "D", "A", "B"])],
    },
    // 9. Opposite sides of a parallelogram are congruent.
    {
      name: "parallelogram_opposite_sides",
      hyps: [("equal_vector", ["A", "B", "D", "C"])],
      goals: [("equal_distance", ["A", "B", "D", "C"])],
    },
    // 10. FALSE conclusion: collinearity alone does not make A the midpoint
    //     of BC. Expect Inconclusive (not in the radical).
    {
      name: "collinear_not_midpoint",
      hyps: [("collinear", ["A", "B", "C"])],
      goals: [("midpoint", ["A", "B", "C"])],
    },
  ]
}

///|
/// Prove every goal polynomial of a compiled theorem.
/// Returns Proved only if all goals are proved.
pub fn prove_theorem(
  th : @translate.CompiledTheorem,
  max_steps? : Int = 50000
) -> @prover.ProofResult {
  for g in th.goals {
    match @groebner.prove(th.hyps, g, max_steps=max_steps) {
      @prover.Proved(_) => continue
      r => return r
    }
  }
  @prover.Proved("all \{th.goals.length()} goal(s) proved")
}
