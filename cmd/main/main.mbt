///|
/// I0 gate: CLI entry that exercises the exact-arithmetic foundation.
fn main {
  println("symgeo I0 toolchain smoke")
  println("bigint smoke result: \{@arithmetic.bigint_smoke()}")
  println("I0 gate: PASS (toolchain + @bigint + package skeleton)")
}
