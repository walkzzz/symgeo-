///|
/// Translate-layer errors.
pub(all) enum TranslateError {
  /// Predicate name not present in the registry.
  UnknownPredicate(String)
  /// Predicate got the wrong number of point arguments.
  WrongArity(String, Int, Int)
  /// A goal must translate to exactly one polynomial.
  GoalNotSingle(String)
} derive(Eq, Debug)

///|
pub impl Show for TranslateError with output(self, logger) {
  match self {
    UnknownPredicate(name) => {
      logger.write_string("unknown predicate: ")
      logger.write_string(name)
    }
    WrongArity(name, want, got) => {
      logger.write_string("wrong arity for ")
      logger.write_string(name)
      logger.write_string(": want \{want}, got \{got}")
    }
    GoalNotSingle(name) => {
      logger.write_string("goal translates to multiple polynomials: ")
      logger.write_string(name)
    }
  }
}

///|
/// Deterministic variable table: geometric names -> ring variable indices.
/// Allocation order = first-use order; equality/hash fully deterministic.
pub struct VarMap {
  priv index : Map[String, Int]
  priv names : Array[String]
} derive(Eq, Debug)

///|
pub fn VarMap::new() -> VarMap {
  { index: {}, names: [] }
}

///|
/// Register-or-fetch a variable by name.
pub fn VarMap::var_of(self : VarMap, name : String) -> Int {
  match self.index.get(name) {
    Some(i) => i
    None => {
      let i = self.names.length()
      self.index[name] = i
      self.names.push(name)
      i
    }
  }
}

///|
pub fn VarMap::nvars(self : VarMap) -> Int {
  self.names.length()
}

///|
pub fn VarMap::name(self : VarMap, i : Int) -> String {
  self.names[i]
}

///|
pub fn VarMap::to_string(self : VarMap) -> String {
  let parts : Array[String] = []
  for i in 0..<self.names.length() {
    parts.push("x\{i}=\{self.names[i]}")
  }
  parts.join(", ")
}

///|
/// Register a named point "P" -> variables "P.x", "P.y"; returns (ix, iy).
pub fn point(vm : VarMap, p : String) -> (Int, Int) {
  (vm.var_of("\{p}.x"), vm.var_of("\{p}.y"))
}

///|
/// Coordinate of point p as a polynomial variable (axis 0 = x, 1 = y).
fn coord(vm : VarMap, p : String, axis : Int) -> @poly.Polynomial {
  let (px, py) = point(vm, p)
  @poly.Polynomial::variable(if axis == 0 { px } else { py })
}

///|
fn diff(vm : VarMap, a : String, b : String, axis : Int) -> @poly.Polynomial {
  coord(vm, a, axis).sub(coord(vm, b, axis))
}

///|
/// 2D cross product of vectors (b - a) and (c - a): twice the signed area.
fn cross3(vm : VarMap, a : String, b : String, c : String) -> @poly.Polynomial {
  diff(vm, b, a, 0).mul(diff(vm, c, a, 1))
    .sub(diff(vm, b, a, 1).mul(diff(vm, c, a, 0)))
}

///|
/// 2D cross of vectors (b - a) and (d - c).
fn cross4(vm : VarMap, a : String, b : String, c : String, d : String) -> @poly.Polynomial {
  diff(vm, b, a, 0).mul(diff(vm, d, c, 1))
    .sub(diff(vm, b, a, 1).mul(diff(vm, d, c, 0)))
}

///|
/// Dot product of vectors (b - a) and (d - c).
fn dot4(vm : VarMap, a : String, b : String, c : String, d : String) -> @poly.Polynomial {
  diff(vm, b, a, 0).mul(diff(vm, d, c, 0))
    .add(diff(vm, b, a, 1).mul(diff(vm, d, c, 1)))
}

///|
/// Squared distance |a - b|^2.
fn dist2(vm : VarMap, a : String, b : String) -> @poly.Polynomial {
  let dx = diff(vm, a, b, 0)
  let dy = diff(vm, a, b, 1)
  dx.mul(dx).add(dy.mul(dy))
}

///|
/// Determinant of a square matrix of polynomials (Laplace expansion).
fn det(rows : Array[Array[@poly.Polynomial]]) -> @poly.Polynomial {
  let n = rows.length()
  if n == 1 {
    return rows[0][0]
  }
  let acc = @poly.Polynomial::zero()
  for j in 0..<n {
    // minor: drop row 0, column j
    let minor : Array[Array[@poly.Polynomial]] = []
    for i in 1..<n {
      let r : Array[@poly.Polynomial] = []
      for k in 0..<n {
        if k != j {
          r.push(rows[i][k])
        }
      }
      minor.push(r)
    }
    let term = rows[0][j].mul(det(minor))
    let _ = if j % 2 == 0 { acc.add(term) } else { acc.add(term.neg()) }
  }
  acc
}

///|
/// Open predicate registry (extension red line #4): new predicates plug in
/// without touching the engine or the prover.
pub struct Registry {
  priv entries : Map[String, (VarMap, Array[String]) -> Result[Array[@poly.Polynomial], TranslateError]]
}

///|
pub fn Registry::new() -> Registry {
  { entries: {} }
}

///|
pub fn Registry::register(
  self : Registry,
  name : String,
  t : (VarMap, Array[String]) -> Result[Array[@poly.Polynomial], TranslateError]
) -> Unit {
  self.entries[name] = t
}

///|
pub fn Registry::has(self : Registry, name : String) -> Bool {
  self.entries.contains(name)
}

///|
pub fn Registry::translate(
  self : Registry,
  vm : VarMap,
  name : String,
  args : Array[String]
) -> Result[Array[@poly.Polynomial], TranslateError] {
  match self.entries.get(name) {
    Some(t) => t(vm, args)
    None => Err(UnknownPredicate(name))
  }
}

///|
fn want(args : Array[String], n : Int, name : String) -> Result[Unit, TranslateError] {
  if args.length() == n {
    Ok(())
  } else {
    Err(WrongArity(name, n, args.length()))
  }
}

///|
fn one(p : @poly.Polynomial) -> Result[Array[@poly.Polynomial], TranslateError] {
  Ok([p])
}

///|
/// The default MVP registry: 8 predicates.
pub fn Registry::default() -> Registry {
  let reg = Registry::new()
  reg.register("collinear", fn(vm, args) {
    match want(args, 3, "collinear") {
      Ok(_) => one(cross3(vm, args[0], args[1], args[2]))
      Err(e) => Err(e)
    }
  })
  reg.register("parallel", fn(vm, args) {
    match want(args, 4, "parallel") {
      Ok(_) => one(cross4(vm, args[0], args[1], args[2], args[3]))
      Err(e) => Err(e)
    }
  })
  reg.register("perpendicular", fn(vm, args) {
    match want(args, 4, "perpendicular") {
      Ok(_) => one(dot4(vm, args[0], args[1], args[2], args[3]))
      Err(e) => Err(e)
    }
  })
  reg.register("midpoint", fn(vm, args) {
    match want(args, 3, "midpoint") {
      Ok(_) => {
        let (mx, my) = point(vm, args[0])
        let (ax, ay) = point(vm, args[1])
        let (bx, by) = point(vm, args[2])
        let two = @arithmetic.Rational::from_int(2)
        Ok([
          @poly.Polynomial::variable(mx).scale(two).sub(@poly.Polynomial::variable(ax)).sub(@poly.Polynomial::variable(bx)),
          @poly.Polynomial::variable(my).scale(two).sub(@poly.Polynomial::variable(ay)).sub(@poly.Polynomial::variable(by)),
        ])
      }
      Err(e) => Err(e)
    }
  })
  reg.register("equal_distance", fn(vm, args) {
    match want(args, 4, "equal_distance") {
      Ok(_) => one(dist2(vm, args[0], args[1]).sub(dist2(vm, args[2], args[3])))
      Err(e) => Err(e)
    }
  })
  reg.register("cong", fn(vm, args) {
    match want(args, 4, "cong") {
      Ok(_) => one(dist2(vm, args[0], args[1]).sub(dist2(vm, args[2], args[3])))
      Err(e) => Err(e)
    }
  })
  reg.register("equal_vector", fn(vm, args) {
    match want(args, 4, "equal_vector") {
      Ok(_) => {
        // d - c == b - a, per axis
        Ok([
          diff(vm, args[3], args[2], 0).sub(diff(vm, args[1], args[0], 0)),
          diff(vm, args[3], args[2], 1).sub(diff(vm, args[1], args[0], 1)),
        ])
      }
      Err(e) => Err(e)
    }
  })
  reg.register("on_circle", fn(vm, args) {
    // on_circle(center, through, p): |p - c|^2 == |a - c|^2
    match want(args, 3, "on_circle") {
      Ok(_) => one(dist2(vm, args[2], args[0]).sub(dist2(vm, args[1], args[0])))
      Err(e) => Err(e)
    }
  })
  reg.register("concyclic", fn(vm, args) {
    match want(args, 4, "concyclic") {
      Ok(_) => {
        // determinant | x^2+y^2  x  y  1 | over the 4 points
        let rows : Array[Array[@poly.Polynomial]] = []
        for p in args {
          let x = coord(vm, p, 0)
          let y = coord(vm, p, 1)
          let s = x.mul(x).add(y.mul(y))
          rows.push([s, x, y, @poly.Polynomial::one()])
        }
        one(det(rows))
      }
      Err(e) => Err(e)
    }
  })
  reg
}

///|
/// A geometric theorem in predicate form (statement-level, engine-agnostic).
pub(all) struct TheoremSpec {
  pub name : String
  /// (predicate, point args) — each translates to >= 1 hypothesis equations.
  pub hyps : Array[(String, Array[String])]
  /// (predicate, point args) — each translates to exactly 1 goal equation.
  pub goals : Array[(String, Array[String])]
} derive(Eq, Debug)

///|
/// Compiled theorem: hypothesis polynomials, goal polynomials, variable table.
pub struct CompiledTheorem {
  pub name : String
  pub hyps : Array[@poly.Polynomial]
  pub goals : Array[@poly.Polynomial]
  pub vm : VarMap
}

///|
/// Translate a theorem spec via the registry. Variable allocation follows
/// first-use order over hyps then goals (deterministic).
pub fn compile_theorem(
  reg : Registry,
  th : TheoremSpec
) -> Result[CompiledTheorem, TranslateError] {
  let vm = VarMap::new()
  let hyps : Array[@poly.Polynomial] = []
  for entry in th.hyps {
    match reg.translate(vm, entry.0, entry.1) {
      Ok(ps) => for p in ps {
        hyps.push(p)
      }
      Err(e) => return Err(e)
    }
  }
  let goals : Array[@poly.Polynomial] = []
  for entry in th.goals {
    match reg.translate(vm, entry.0, entry.1) {
      Ok(ps) => for p in ps {
        goals.push(p)
      }
      Err(e) => return Err(e)
    }
  }
  Ok({ name: th.name, hyps, goals, vm })
}
