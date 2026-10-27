# symgeo

Precise symbolic geometry library in MoonBit.

**Pipeline**: geometric statements -> polynomial systems -> automated deciding (Wu + Groebner dual engines).

## Layout (dependency direction: only downwards)

```
cmd/main        CLI (executable)          -> arithmetic, prover
prover/wu       Wu engine (I3)            -> poly, translate
prover/groebner Groebner engine (I2)      -> poly
translate       predicate -> polynomials (I2) -> poly
poly            polynomial core (I1)      -> arithmetic
arithmetic      exact Rational (I1)       -> core/bigint
```

## Iteration roadmap

- I0 toolchain smoke (this commit)
- I1 exact kernel: Rational + sparse Polynomial + Ring/MonomialOrder interfaces
- I2 Groebner deciding: Buchberger + predicate registry + golden corpus
- I3 Wu engine + dual-engine cross validation + verifiable certificates
- I4 geometry layer + CLI v0.1
- I5 ecosystem extensions (on-demand triggers)

See plan documents in the workspace for details.
