# Model Zero

A Lean 4 model of an identity-first settlement system, stating and proving four whole-system theorems: attested transfer; issuance only against authenticated real-world activity; erasure with asset preservation; conservation with halt semantics.

## Status

| | |
|---|---|
| **Version** | v0.2.1 |
| **Proved** | 18 of 18 statements — no `sorry` |
| **Toolchain** | Lean 4.21.0 (`leanprover/lean4:v4.21.0`), core only, no imports |
| **Axioms** | `propext`, `Quot.sound` (Lean's built-in) — no `Classical.choice`, no custom axioms |
| **Trusted base** | Four hypotheses H1–H4, declared in the file and used by no theorem: signature validity; a single ordered log from consensus; honest attestation above the quorum threshold; authentication of the physical event |
| **Proof level** | Model level only. Nothing is proved of any running code. |
| **Checker (RP1)** | `checker/why3/checker.mlw` — the attested-authorisation checker stated in Why3 (1.8.2 / Alt-Ergo 2.6.4; CI: Why3 1.6.0 / Z3). 13 of 14 obligations discharged by SMT; `wf_reachable` open, pending one structural induction; P2 (liveness) kept in prose pending delivery hypothesis H5 (#2). Smoke test 16 of 16. SMT-discharged, not kernel-checked: a weaker guarantee than the Lean proofs, stated plainly. Merged 14 October 2026 (PR #6). |

## What is in the file

`ModelZero.lean` defines the chain's state, the twenty-nine moves the chain may make (and no others), the genesis state, the reachable states, and the four hypotheses; then states and proves the four theorems and their supporting lemmas. Section 11a holds core-only list lemmas; section 11b the combined invariant from which the conservation and ledger theorems follow. The header of the file records every version's changes and the ruling behind each.

## Build and check

```
elan toolchain install leanprover/lean4:v4.21.0
lean ModelZero.lean          # expect exit 0 and no 'sorry' warnings
```

Append `#print axioms ROCKR.<theorem>` for any theorem to see its dependencies. The continuous-integration workflow in `.github/workflows/lean.yml` runs exactly this on every pull request.

## The checker

[`checker/why3/`](checker/why3/) holds the Why3 statement of the RP1 attested-authorisation checker: `checker.mlw` (four inputs, the five conditions of C(π, S_h), an abstract step relation, the properties), `checker_test.mlw` (the predicate on concrete data), `p2_probe.mlw` (the record that P2 as first stated was vacuous), the correspondence note tracing every symbol to the Problem Book or to Model Zero, and the Q1–Q6 assessment. The `why3` workflow re-runs it on every change. One obligation the implementation inherits: signatures arrive as a list and must be de-duplicated before comparison with k.

## Companion documents

The Problem Book page for RP1, the attested-authorisation checker, is in this repository at [`docs/problem-book/`](docs/problem-book/) — current version v1.2 (2 October 2026), with v1.1 preserved. The chief architect's rulings ledger is at [`docs/rulings/`](docs/rulings/). The English read-back (the model explained sentence by sentence) and the change notes are at [rockrprooflabs.org](https://rockrprooflabs.org). The economic design the model formalises is the ROCKRCOIN whitepaper (v8.2), also linked there.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). In short: contributions are made against a written brief; proposed changes to definitions are submitted as written strikes and ruled before any proof is attempted; pull requests carry a provenance note, the toolchain version, the `#print axioms` output for every theorem, and a Developer Certificate of Origin sign-off on each commit.

## Citing

> Clancy, D., Palani, H. *Model Zero: a machine-checked model of identity-bound settlement*, v0.2.1, with the RP1 checker stated in Why3, ROCKR Proof Labs Ltd, 2026. https://github.com/rockr-proof-labs/model-zero

## Licence

Apache License 2.0 — see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

*Nothing has been awarded to this programme by any funder; nothing is payable by anyone unless it is.*
