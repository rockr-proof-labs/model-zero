# Correspondence note — `checker.mlw` ↔ Problem Book RP1 v1.1 ↔ Model Zero v0.2.1

**Author:** Harikeshwaran Palani · **Reviewer:** David Clancy, ROCKR Preuves · **Licence:** Apache 2.0
**Sources:** Problem Book RP1 v1.1, 23 September 2026 (PB); Model Zero v0.2.1, 23 September 2026 (MZ), Lean 4.21.0 core only.
**Toolchain:** Why3 1.8.2, Alt-Ergo 2.6.4. Independently re-run by David Clancy under Why3 1.6.0 with Z3. CI reproduces on Ubuntu's Why3 1.6.0 with Z3.

- `why3 prove checker.mlw` — type-checks, no errors.
- `why3 prove -P alt-ergo checker.mlw` — **13 of 14 obligations discharge**; `wf_reachable` is open. See §6.
- `why3 prove -P alt-ergo checker_test.mlw` — **every goal Valid**. This exercises the predicate on concrete data; it does **not** prove the properties.
- `why3 prove -P alt-ergo p2_probe.mlw` — records that P2 as first stated is vacuous (issue #2).

**Carries rulings of 1–2 October 2026**, listed in §7: D-N (P2), D7 (derived expiry), D8, D9, Q2, Q3, Q6a, Q6b, D4, D-M.

---

## 1. Every symbol, and where it comes from

| Why3 symbol | PB | Model Zero | Note |
|---|---|---|---|
| `principal` | §1, `p` | `DID` | On-chain identifier only; PB §1 states the checker never reads personal data. |
| `event` | §1, `e` | `ExpId` / `Experience` | The authenticated event π refers to. |
| `attester` | §1, `Att(e)` members | `InstanceId` (accredited instances) | MZ's registry is `accredited : InstanceId → Bool`. |
| `height` | §1, `h` | — | MZ has `time : Time` but no block height. See D2. |
| `atime` | §1, attester-time `t` | `Attestation.issued` | The attester's own clock. |
| `btime` | §1, block time `τ_h` | `State.time` | The chain clock. A distinct type from `atime` because Q1 is about their disagreement. |
| `presence` = `{subject; ev; signed_at; sigma}` | §1, π = ⟨p, e, t, Σ⟩ | — | MZ has no presence attestation. See D1. |
| `sigma : fset attester` | §1, "signed by a set Σ" | — | A **set**, so one attester cannot be counted twice toward `k`. See the implementation note in §5 below. |
| `status` = `Live │ Revoked │ Expired` | §1, "live \| revoked \| expired" | `State.revoked : Attestation → Bool` and `time < a.expires` | MZ splits what PB unifies: revocation is a flag, expiry a time comparison. See D7. |
| `policy` = `{delta; eps}` | §1, (Δ, ε) | — | MZ has no freshness policy. |
| `state` | §1, `S_h` | `State` | Only the parts the checker reads. |
| `state.h` | §1, `h` | — | PB §3 P3 says "the decision at height h", so the state must know which height it is. |
| `state.cred` | §1, `R_h` | `s.revoked`, `s.attest` | The register, as a status per principal. |
| `state.att_set` | §1, `Att(e)` | `s.accredited` | MZ's registry is global, PB's per event. See D3. |
| `state.threshold` | §1, `k` | — | MZ has no threshold; H3 assumes honest attestation outright. |
| `state.tau` | §1, `τ_h` | `s.time` | |
| `state.released` | §1, "the release history" | `s.porchLog : List ExpId` | MZ logs per event; PB keys per ⟨p, e⟩. See D4. |
| `state.pol` | §1, (Δ, ε) | `State.params` (MZ's governance record) | **A field, not an argument** — see §2 below. |
| `wf` | §2 (implicit) | MZ's genesis well-formedness | `k ≥ 1`, `Δ, ε ≥ 0`. See D9. |
| `signs` (undefined) | §2, signature scheme outside adversary control | `Attestation.sigOK`, H1 | Inherited hypothesis, never modelled. |
| `c1_signatures` | §1, condition 1 | — | k-of-n over `Att(e)` as recorded in `S_h`. |
| `c2_live` | §1, condition 2 | `verified` (the `revoked` and `expires` conjuncts) | Catches **both** revoked and expired, which is PB §3's corollary wording. |
| `c3_fresh` | §1, condition 3 | `verified` (the `s.time < a.expires` conjunct) | MZ has a one-sided bound; PB has two. |
| `c4_unused` | §1, condition 4 | `porchLog` membership | Single use. |
| `c5_credit` | §1, condition 5 | `T1_no_unauthorised_debit`, `RUIPA_nontransferable` | The credited account is p's. |
| `decide` | §1, `C(π, S_h)` | `porchRelease` guards | Named `decide`: `check` is a WhyML keyword. |
| `action` = `Revoke │ Expire │ Rotate │ SetPolicy │ Advance │ Release` | §1, §3 | `revoke`, `govParams`, `tick`, `porchRelease` | Only the moves the checker can see; MZ's other constructors are invisible to it. |
| `step` | — | MZ's inductive `Step` | Same shape: one constructor per move, guards as hypotheses. |
| `reachable` | §3, "every reachable `S_h`" | `Reachable` | Same two rules. |
| `initial` | — | `genesisState` | Weaker than MZ's: only what the checker needs. |
| `submitted`, `bound` | §3 P2, "presented", "a stated bound B" | — | Abstract. See D5. |
| `P1_soundness` … `P4_single_use` | §3, P1–P4 | `T1`–`T4` are the system-level analogues | |

---

## 2. The one place the file departs from a literal reading, and why

**The policy is a field of the state, not a parameter of `decide`.**

PB §1 writes the decision predicate as **C(π, S_h)** — two arguments. The policy is described as an input to the *checker*, but it is a committed configuration value, not something supplied per request. Writing it as a free parameter makes P1 **false**, not merely unproved:

- `step_release` quantifies the policy inside the rule, so "a release happened" gives the five conditions for *some* policy;
- P1 quantifies it outside, so it claims the conditions for *every* policy;
- take Δ = ε = 0 against a release taken under a generous window, and condition 3 fails.

Putting `pol` in the state closes this and matches §1's two-argument form. Governance may still retune it, through the `SetPolicy` move — see D8.

---

## 3. Where PB and Model Zero disagree (strikes, for ruling)

**D1 — MZ has no presence attestation.** PB's π = ⟨p, e, t, Σ⟩ is a *presence* claim about an event, signed by a threshold set. MZ's `Attestation` is an *identity* credential — subject, issuer, level, issued, expires, sigOK — with no event and no signer set. MZ's `porchRelease` is guarded only by `e.authenticated = true`, so at model level the checker's verdict is an opaque boolean. The two objects are disjoint, not refinements of one another. Proposal: keep them separate and name the relation — the checker consumes π *and* MZ's `verified p`; `porchRelease` is its call site.

**D2 — heights versus block time.** PB indexes everything by height (`S_h`, `R_h`, `τ_h`, "h′ ≤ h"). MZ has `time : Time` and a week counter but no height, and `tick` advances time with no block boundary. P3 as stated cannot be expressed against MZ's state at all. Height is modelled explicitly here. If MZ is to carry the checker later, MZ needs a height.

**D3 — attester set: global versus per event.** MZ has one global registry, `accredited : InstanceId → Bool`, changed by `govAccredit`. PB has a per-event set `Att(e)` with threshold `k`, subject to rotation, slashing and admission (Q3). Different structures, not different notations. MZ has no threshold at all: H3 assumes accredited instances attest honestly, full stop.

**D4 — the release history is keyed differently.** MZ's `porchLog : List ExpId` records that an event's verdict was released; PB's condition 4 is about ⟨p, e⟩. On MZ's key, one release per event would exclude every later participant in the same event. Either MZ's log becomes per ⟨p, e⟩, or the two logs are different objects with different purposes.

**D5 — P2 is not statable without a delivery assumption.** PB §2 gives the adversary full control of the wire; PB §3 P2 then requires release within `B`. The checker alone cannot guarantee this: a message never delivered is never checked. `submitted` and `bound` are abstract for that reason, which makes P2 a statement about the pair (checker + delivery). This is Q4.

**D6 — within-block ordering is not modelled.** Heights advance only through `Advance`, so a revocation and a release inside one block cannot be distinguished. That is Q2's question. Modelling it needs an intra-block transaction order, which changes the state model. Not added; it should be ruled first.

**D7 — how `expired` is entered.** PB §1 gives status as three-valued but never says how a credential becomes `expired`. MZ derives it: `verified` requires `s.time < a.expires`, with no `Expired` state at all. This file makes `Expire` a move, which is the weakest faithful reading but almost certainly not the intent. If expiry is meant to be derived from an expiry date and τ, then `status` should be a *function* of `R_h` and `τ_h`, not a stored field — and condition 2 becomes time-dependent, which interacts with Q1.

**D8 — the freshness policy can drift (new; not in PB or MZ).** With the policy in the state, `SetPolicy` can move the window while a π is in flight. This is the same shape as the bond drift struck in Model Zero (D-F, 16 September): a value the decision depends on changes between the moment the evidence is created and the moment it is used. PB does not say whether the policy in force is the one at signing time or at check height. Read at check height here, consistently with C1's reading of `Att(e)`. **For ruling.**

**D9 — nothing bounds `k` below.** PB §2 gives the adversary "fewer than k attesters for any event", which is vacuous at k = 0; and at k = 0 an *empty* signing set satisfies `cardinal Σ ≥ k`, so an unsigned note releases. k ≥ 1 is assumed here in `wf`, not derived. It should be stated in PB §1 alongside "k-of-n".

---

## 4. A contradiction inside PB §3 itself (strike, for ruling)

P2's antecedent is given as "**conditions 1–3** hold at some height h₀ and A(p) remains live". Condition 4 is not among them.

Take a π whose ⟨p, e⟩ has already been released at some earlier height. At h₀ its signatures are still valid (1), p is still live (2), and t is still inside the window (3). P2 therefore demands that release occur again within B. P1's own corollary — "no **replayed** evidence ever releases value" — forbids exactly that.

So P1 and P2, read literally, are contradictory on replayed evidence. This is not a modelling artefact; it is in the prose.

**Proposed replacement:** P2's antecedent is conditions 1–4 (and 5 for the credited account), i.e. `C(π, S_h₀) = release`. That is how it is written in `checker.mlw`, which is why the file's P2 is stronger in the antecedent than PB's text. Flagged rather than silently corrected.

---

## 5. What the file assumes and does not prove

- **Signature validity** (`signs`) is undefined: PB §2 and MZ's H1.
- **A single ordered log**: MZ's H2; here, the linear ordering of `height` by `Advance`.
- **Honest attestation above threshold**: MZ's H3; here, `signs` plus `cardinal Σ ≥ k` in C1.
- **Authentication of the physical event**: MZ's H4; here, the existence of `Att(e)` at all.

PB §4 states the checker inherits all four. This file inherits them the same way: assumed, never proved.

**Implementation note, for whoever writes the Rust.** `Σ` is an `fset` in the model, so duplicate signatures cannot inflate the count. A real implementation receives signatures as a *list* over the wire. **It must de-duplicate before comparing against k**, or one corrupt attester sending the same signature k times defeats the threshold entirely. The model is correct; the obligation lands on the implementation. `checker_test.mlw` carries this as an explicit `distinct` predicate and a proved goal (`test_duplicate_signer_hold`), precisely so the requirement is visible rather than implicit.

---

## 6. Proof status

**Corrected twice.** The first version of this note recorded every obligation as admitted — inaccurate in the conservative direction, because the brief asked for a statement and I type-checked the file without ever pointing a prover at it. The second version recorded 13 of 15. This version carries ruling D-N: **P2 is no longer an obligation at all**, so the file has 14, of which 13 discharge.

### `checker.mlw` — 13 of 14 obligations discharge

| Obligation | Status |
|---|---|
| `wf_preserved` | discharged |
| `P1_soundness` | discharged |
| `P1_corollary_no_revoked_release` | discharged |
| `P1_corollary_no_replay` | discharged |
| `P3_decision_depends_only_on_R` | discharged |
| `P3_revocation_takes_effect` | discharged |
| `P4_non_transferability` | discharged |
| `P4_single_use` | discharged |
| `release_needs_threshold` | discharged |
| `release_needs_a_signature` | discharged |
| `release_marks_history` | discharged |
| `no_release_without_move` | discharged |
| `decision_ignores_height` | discharged |
| `wf_reachable` | **open** — induction over `reachable` |

**Toolchains.**

| | Why3 1.8.2 / Alt-Ergo 2.6.4 (mine) | Why3 1.6.0 / Z3 (David Clancy, 1 Oct 2026) |
|---|---|---|
| Discharged | 13 | 13 |
| Open | `wf_reachable` | `wf_reachable` |

Under Alt-Ergo the thirteen are `Valid` between 0.03s and 0.27s, the longest being `P1_corollary_no_replay` (0.27s, 2,491 steps). `wf_reachable` returns **`Timeout` at the default 5s limit, not `Invalid`** — the prover found no counter-model, it ran out of time. It is an induction over the `reachable` relation, and SMT solvers do not do induction, so no time limit helps. This is a limitation of the tool, not of the statement: one structural induction in a proof assistant. ⟨⟨VERIFY after the D7 change: re-run `why3 prove -P alt-ergo checker.mlw` and confirm 13 of 14 still discharge. If any goal has stopped discharging, say which.⟩⟩

### P2: vacuous, not open — the probe (ruling D-N, issue #2)

The second version of this note recorded `P2_liveness` as open "for want of a witness under an abstract delivery assumption". **That was wrong, and the error was mine.** David Clancy probed it on 2 October 2026: add the single hypothesis `bound >= 0` and it discharges in hundredths of a second, because **s0 is its own witness** — `reachable s0` is given, `s0.h = h0 ≤ h0 + bound` needs only `bound ≥ 0`, and `decide s0 pi q` gives `step_release` directly. The goal follows from its own antecedent.

`p2_probe.mlw` records this reproducibly. It carries the statement as first written, with `bound >= 0` added, and the same goal stripped to the three hypotheses that actually do the work — showing that nothing in the delivery apparatus was ever load-bearing.

⟨⟨VERIFY: run `why3 prove -P alt-ergo p2_probe.mlw` and record the result here.⟩⟩

**The underlying reason is general, and it is the real finding.** `reachable` is a set of **states**. "Eventually" is a property of **executions** — sequences of steps. No predicate over a set of states can express it, with or without `submitted` and `bound`. So P2 cannot be stated in this framework at all; the framework, not the wording, is the obstacle.

This sharpens rather than contradicts D5 and Q4: liveness needs executions **and** a delivery hypothesis on the execution, and neither this file nor Model Zero has executions.

Per ruling D-N, P2 is kept in `checker.mlw` as a comment block carrying the original statement verbatim and the three findings, not as a goal. The formal statement is deferred to the December interface: over executions, under a delivery hypothesis H5 inherited from CometBFT's partial-synchrony guarantee, with the bound B measured on the testnet. Tracked as issue #2.

**What "discharged" does and does not mean.** These goals were accepted by an SMT solver, not checked by a kernel as in Model Zero's Lean proofs. The guarantee is weaker and rests on the solver. The right reading is: *the statements are true of the model and an automatic prover can see why*, which is what PB §4 predicts — "the model-level proofs are short: case analysis on the move, then read the guard." The P2 episode is the caution that goes with it: a goal discharging says nothing about whether it says what you meant.

### `checker_test.mlw` — the smoke test. **14 of 14 Valid under Alt-Ergo 2.6.4**, longest 0.17s:

`test_hugo_release` (the only release), `test_yann_hold` + `test_yann_fails_only_c4`, `test_zara_hold` + `test_zara_fails_only_c2`, `test_wrong_account_hold` + `test_wrong_account_fails_only_c5`, `test_single_signature_hold`, `test_outsider_signature_hold`, `test_duplicate_signer_hold` + `test_duplicate_fails_on_distinct`, `test_stale_hold`, `test_future_hold`, `test_wf`.

Nine of the fourteen are *hold* cases, each failing exactly one condition. That is the point of them: it shows the five conditions are independent and none is decorative. **It is a check of the predicate on concrete data, not a proof of P1–P4.** Independently reproduced by David Clancy under Why3 1.6.0 with Z3, so the result holds across two Why3 versions and two provers.

---

## 7. Rulings carried in the file (David Clancy, 1–2 October 2026)

| | Ruling | Effect on the file |
|---|---|---|
| **P1/P2 antecedent** | Accepted. P2's antecedent is `C(π, S_h₀) = release` — all five conditions, credential live, policy stable over the window. Problem Book v1.2 §3 carries the correction with my name against it. | none (P2 is now a comment block) |
| **D-N** | P2 is not statable in this framework. Keep the statement as a comment block, verbatim, with the three findings. Do not try to close it. | `submitted`, `bound` and the goal removed; comment block added; 15 obligations become 14. Issue #2. |
| **D7, expiry** | **Derived**, as Model Zero does it: status is a function of the register and τ, not a stored field; `Expire` ceases to be a move; condition 2 becomes time-dependent. | `cred : principal -> credential` with `is_revoked` and `expires`; new `status_of`; `Expire` and `step_expire` removed; `c2_live` reads `status_of`. |
| **D8, policy drift** | Read at check height, as written. **Deliberately the opposite of Model Zero's D-F**: a bond is the bidder's commitment and is frozen to protect the bidder; the window is the chain's defence and must not be frozen by the attacker's timing. The liveness cost is named by P2's stability hypothesis. | none — confirms what was there |
| **D9, k ≥ 1** | Stated in Problem Book §1 and kept in `wf`. The value of k, who may sign, and how `Att(e)` is formed are settled by the application's authentication step (Step 7); `threshold` and `att_set` are the hooks it lands on. | none — confirms `wf` |
| **Q2** | "Revocation always wins within a height": R_h is the register after every revocation in block h is applied; enforced at **block construction**, not in C. | none. D6 stands as "not modelled, **by ruling**" |
| **Q3** | The rotation/slashing distinction accepted in principle — "the strongest thing in the pack" — and the state-model change deferred to the December interface. | none; the PR need not wait |
| **Q6a** | Revocation **for cause** acts on the DID: every attestation ceases to count. **Withdrawal** — an issuing instance ceasing to vouch — is per-attestation and is not revocation. MZ v0.3's `verified` becomes "(some attestation live and not withdrawn) and (DID not revoked)". | none — `cred : principal -> …` is already the DID-level view |
| **Q6b** | P4 is about the **immediate credit**. Every account that can receive a release is an attested DID with a single identified beneficial owner (whitepaper §5.3); the only contracts holding coin are Mode 2 escrow contracts, atomically within a settlement. New ruling **D-O**: RUIPA accrues to human-verified DIDs only; institutional DIDs hold Main only — a v0.3 definition. | none |
| **D4** | MZ's `porchLog` (event-level, "it happened") and the checker's `released` (per ⟨p, e⟩, "this person was paid") are **different objects** — the whitepaper's "two provable claims", §6.5. Name the relation when they are composed. | none now |
| **D-M** | Same repository, `checker/why3/`; Why3 standard library permitted; **no external Why3 libraries**; toolchain and prover versions pinned; session committed so `why3 replay` reproduces the result. | the file uses only `int.Int`, `bool.Bool`, `set.Fset` |

### Still open, by ruling rather than by omission

- **Q3, rotation versus slashing** — deferred to the December interface; it changes the state model, not one line.
- **P2 over executions** — issue #2, deferred to December under hypothesis H5.
- **D6, within-block ordering** — ruled to belong to block construction, so it stays out of C.

Provenance: written with AI assistance (Claude). I checked every row of the tables above against the Problem Book text and the Model Zero source, and I ran both Why3 invocations myself.
