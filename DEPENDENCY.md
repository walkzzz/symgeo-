# Dependency direction check (I0 gate item)

Rule: packages may only import packages **below** them in this list.

```
cmd/main       (executable)
prover/wu      (I3)
prover/groebner (I2)
translate      (I2)
poly           (I1)
arithmetic     (I1, imports core/bigint)
```

I0 note: only `cmd/main -> arithmetic -> core/bigint` edges exist; the direction
constraint holds by construction. Later iterations must extend this check
(e.g. via a CI grep or moon build order) before merging.
