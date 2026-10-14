# Q1–Q6: which are definitional, which are provable, which are open

**Harikeshwaran Palani · Task 2, ROCKR Preuves · companion to `checker.mlw` and the correspondence note**
Written against Problem Book RP1 v1.1 §5 and Model Zero v0.2.1. **Rulings of 1–2 October 2026 are now in; this version marks how each was ruled.**

## How each was ruled

| | My recommendation | Ruling |
|---|---|---|
| Q1 | Definitional; C4 not C3 carries replay; keep C4 on ⟨p, e⟩; make the policy's time-of-force explicit | D8: policy read at **check height** — deliberately the opposite of Model Zero's D-F. A bond is the bidder's commitment, frozen to protect the bidder; the window is the chain's defence and must not be frozen by the attacker's timing. |
| Q2 | "Revocation always wins within a height" | **Accepted.** R_h is the register after every revocation in block h is applied, enforced at **block construction**, not in C. The file does not change; D6 stands as "not modelled, *by ruling*". |
| Q3 | Separate rotation from slashing | **Accepted in principle** — "the strongest thing in the pack" — and the state-model change **deferred to the December interface**. The file does not change and the PR need not wait. |
| Q4 | Liveness belongs to the pair, not the checker | **Accepted and sharpened** — see the corrected section below. My statement of P2 was not merely unprovable; it was vacuous. Ruling D-N. |
| Q5 | Composes with no new hypotheses for whole releases; partial release is new state | no ruling yet |
| Q6a | A person with two live credentials is a real disagreement | **Ruled:** revocation *for cause* acts on the DID; **withdrawal** — an instance ceasing to vouch — is per-attestation and is not revocation. MZ v0.3's `verified` becomes "(some attestation live and not withdrawn) and (DID not revoked)". `cred : principal -> …` is already the DID-level view, so the file does not change. |
| Q6b | P4 is about the immediate credit, or contracts must be excluded | **Ruled:** the immediate credit. Every receiving account is an attested DID with one identified beneficial owner (whitepaper §5.3); the only contracts holding coin are Mode 2 escrow contracts, atomically within a settlement. New ruling **D-O**: RUIPA accrues to human-verified DIDs only — a v0.3 definition. |
| D7 (mine) | Expiry is undefined in PB; MZ derives it | **Ruled derived**, as Model Zero does it. Applied to the file: `status_of` reads the register against τ; `Expire` ceases to be a move; condition 2 is now time-dependent. |
| D9 (mine) | Nothing bounds k below | **Accepted**; stated in Problem Book §1 and kept in `wf`. |
| P1/P2 contradiction | PB §3's own text is inconsistent | **Accepted.** Problem Book v1.2 §3 carries the correction, crediting the strike. |

## Summary (as first written)

| | Question | My view |
|---|---|---|
| Q1 | Freshness under clock skew | **Definitional**, then a short proof. The window does not carry the replay argument; condition 4 does. A third parameter is missing: *which* policy is in force. |
| Q2 | Revocation races | **Definitional.** P3 is not well-defined until an ordering rule is fixed. Once fixed, provable. |
| Q3 | Attester-set drift | **Definitional, and the most valuable of the six.** Both P1 and P2 survive if removal-for-cause is separated from rotation. |
| Q4 | The liveness bound | **Genuinely open**, and in my view mis-attributed: liveness is a property of the pair, not of the checker. |
| Q5 | Composition with conservation | **Mostly provable** with no new hypotheses — except partial release, which the conservation theorem cannot see. |
| Q6 | Definition strikes | Four: a person with two live credentials; the credited account being a contract; no lower bound on k; and how `expired` is entered. Plus a contradiction between P1 and P2 as written. |

---

## Q1 — Freshness under clock skew

**The (Δ, ε) part is arithmetic on the assumptions, not a theorem.** Take δ as the disagreement between attester clocks and δ′ as their disagreement with τ_h. For P2, an honest π must not be rejected: a genuine signature at attester-time t may appear anywhere within δ′ of block time, and inclusion takes some delay B_incl. So liveness needs roughly **ε ≥ δ′** and **Δ ≥ δ′ + B_incl** (in block-time units). Nothing in P1 pushes back: condition 3 is *part of* the decision, so widening the window cannot make C release something the conditions forbid. The two are simultaneously satisfiable for any sufficiently wide window, and the choice of (Δ, ε) is policy, not a soundness constraint.

**That matters because §3's corollary misattributes replay.** "No replayed evidence ever releases value" sits under soundness next to freshness, which suggests freshness is what stops replay. It is not. A replayed π is by construction one that already released, so it is **condition 4** that excludes it — a replay one second later is perfectly fresh. Freshness bounds only how stale a *first* use may be. `checker.mlw` therefore states the replay corollary against the release history (`P1_corollary_no_replay`), not against the window. I would say so explicitly in §3, because it decides where proof effort should go.

**On the second half — keep condition 4 keyed on ⟨p, e⟩.** Keying on ⟨p, e, t⟩ weakens single use: two attestations of the same person at the same event with different t would each release. The residual worry §5 raises — one p at two events with near-coincident t — is not a checker question. Σ signs ⟨p, e, t⟩, so a π for e cannot be presented for e′ unless the attesters signed both, which is H4's territory (was the physical event authenticated), not C's.

**A third parameter is missing from the question: which policy is in force.** (Δ, ε) is governance-set, so it can move between signing and checking — the same shape as the bond drift struck in Model Zero (D-F). `checker.mlw` models this as `SetPolicy` and reads the policy at check height, consistently with C1's reading of `Att(e)`. But PB does not say. If a tightening can invalidate a π already in flight, P2 needs a policy-stability hypothesis, which `checker.mlw` carries. **Worth ruling alongside Q3, since it is the same question about a different field.**

**Proposed strike:** make δ and δ′ explicit parameters of the policy and state ε ≥ δ′ ∧ Δ ≥ δ′ + B as a lemma, so the relationship is checkable rather than implied.

---

## Q2 — Revocation races

P3 says the decision at height h is a function of R_h alone. That is well-defined only once "R_h" is pinned to a moment: the register as the block opens, or as it closes. With transaction ordering inside the block, the adversary who controls delivery gets a lever — he can try to have a release sequenced before a revocation he has seen — and P3 becomes a property of sequencing rather than of the checker.

**I would rule "revocation always wins within a height".** It is the safety-favouring choice; it removes the mempool lever entirely; it makes P3 provable as stated; and it costs only liveness in a narrow case — a release legitimately submitted in the same block as an unrelated-in-time revocation is simply retried. It also makes R_h unambiguous: the register after all revocations in the block are applied.

That moves part of the burden to block construction, as §5 anticipates. I think that is correct. The checker should be a pure function of a committed state; anything about ordering belongs to the state's construction, not to C. Stated the other way — as an invariant on block construction — it is also a property the implementation team can test, which a property of C alone is not.

`checker.mlw` does not model within-block ordering at all (D6): heights advance only through `Advance`, so several moves share a height and are indistinguishable. That is deliberate — the question should be ruled before the model commits to an answer.

---

## Q3 — Attester-set drift

Each of the three readings fails somewhere, as §5 says. **The set at signing time t** admits a compromised-then-removed attester: his signature stays good for ever. **The set at check height h** kills legitimate rotation: a π signed yesterday by yesterday's honest set fails today. **The intersection** is the worst of both, since it can fall below k after any benign rotation.

The reason none works is that "removal" is being treated as one thing. It is two:

- **Rotation** — scheduled change, retirement, admission. A forward-looking, benign change; signatures made before it were honest and should stay good.
- **Slashing** — removal for cause. A statement that the attester was *already* dishonest; his signatures should stop counting retroactively.

**Proposal: condition 1 requires k-of-n from `Att(e)` at signing time t, minus attesters slashed for cause by height h.** Then P1 survives the compromised-then-removed case (slashing is retroactive) and P2 survives rotation (rotation is not).

The cost is real and should be stated: the state must record *why* an attester left, and `Att(e)` becomes history-dependent rather than a single current set. In `checker.mlw` that means `att_set` is no longer `event -> fset attester` but something indexed by time, plus a slashed-set. This is the question I would most like ruled, because unlike Q1 and Q2 it changes the **state model**, not one line of the predicate — and PB §6 says the cheap window for that is the next ten weeks.

---

## Q4 — The liveness bound

> **Corrected 2 October 2026.** What follows was right in its conclusion and wrong about my own file. I wrote that P2 "stays open for want of a witness". It does not stay open: as I stated it, **it is vacuous**. Add `bound >= 0` and it discharges in 0.01s, because s0 is its own witness — `reachable s0` is given, `s0.h = h0 ≤ h0 + bound`, and `decide s0 pi q` gives `step_release` directly. The goal follows from its own antecedent. Worse, `p2_probe.mlw` shows it still discharging with `submitted` and the stability hypothesis stripped out, in *fewer* steps: the delivery apparatus I was proud of was never load-bearing.
>
> The general reason is the real finding, and it is stronger than what I argued below: **`reachable` is a set of states, and "eventually" is a property of executions.** No predicate over a set of states can express it, with or without `submitted` and `bound`. P2 cannot be stated in this framework at all — the framework, not the wording, is the obstacle.
>
> Ruling **D-N**: P2 is kept in `checker.mlw` as a comment block, verbatim, with the three findings; not as a goal. Deferred to the December interface, over executions, under delivery hypothesis **H5** inherited from CometBFT's partial-synchrony guarantee, with B measured on the testnet. Issue #2.
>
> The argument below stands, and the vacuity is evidence for it rather than against it. But I should have probed my own statement before defending it.

**I do not think P2 is a property of the checker, and I do not think a B exists for the checker alone.** The checker is a pure function of (π, S_h); it releases the instant it is asked with good evidence. Everything that consumes time is elsewhere:

- attesters signing (B_att);
- the message reaching the chain under an adversary who controls the wire (B_incl);
- inclusion and finality (CometBFT, assumed safe by §2).

The first two are assumptions, not theorems. With an adversary who can delay any message indefinitely — which §2 grants — **no B is provable at all**. With a fair-delivery assumption (every submitted transaction is included within B_incl), B = B_att + B_incl + finality is provable but uninteresting: it is arithmetic on the assumptions.

**I would restate P2 as conditional liveness:** *given* the delivery assumption, release occurs within B. That is what `submitted` and `bound` stand for in `checker.mlw`. Stated that way the property is honest, and the interesting question moves to where it belongs — what B_incl is defensible for the real network, which is a measurement, not a proof.

So: liveness is a property of the **pair**, as §5's own third option suggests.

---

## Q5 — Composition with the supply invariant

Model Zero's conservation theorem (T4) is `supply = sumBal + lockedMain`, proved over all 29 moves, and escrow is already visible to it as `locks`/`lockedMain`, with three exits: `releaseLock`, `settleGrowth` and `forfeit`. A checker-driven release that settles a whole lock is one of these, so **composition needs no new hypothesis; the release path is already inside the invariant.**

Two gaps, though:

1. **There is nothing yet to compose.** At model level the checker's verdict and the escrow release are not connected: `porchRelease` only appends to `porchLog` and moves no value (D1). Composition is future work, not a present obligation — but it is the work that makes the December freeze meaningful.
2. **Partial release does not exist in Model Zero.** Every lock settles or forfeits whole. A partial release would be a new constructor and would need the invariant restated, since a lock would then hold a residue. This is the one item in §5's list that is genuinely new state.

Escrow expiry and the refund path **do** exist (`releaseLock`), so those two of §5's three candidates are already covered.

**Verdict: provable, no new hypotheses, for whole releases; definitional work needed before partial release can even be stated.**

---

## Q6 — Definition strikes

Of the four candidates §5 offers, **two are real strikes**:

**A person with two live credentials.** Model Zero allows it: `attest` maps a DID to a *list*, and `verified` is an existential over that list, so a DID with one revoked and one live attestation is verified. PB's A(p) has a single status per principal. Under MZ's definition, revoking "the" credential of p does not necessarily make p unverified; under PB's, it does. This is a genuine disagreement about what revocation *means*, and it bites P3 directly: the decision is meant to be a function of R_h, but R_h has one entry per person while the model has one per attestation. Either R_h becomes per-credential, or revocation must be defined as revoking every live credential of p.

**The credited account being a contract.** Condition 5 says the credited account is p's and no other; P4 says no sequence of moves maps a release for (p, e) to q ≠ p. If p's account is a contract that forwards, both hold formally while the value ends up elsewhere. Either P4 is about the **immediate credit only**, which should be said, or contracts must be excluded at the release boundary. MZ has contract envelopes (`contractEnv`) and treats every DID uniformly, so the situation is reachable there.

The other two are less sharp. **Escrow expiry and refund** already exist in MZ (`releaseLock`, `forfeit`), though not connected to the checker. **An event with fewer than k honest attesters at genesis** is not excluded anywhere, but it sits under H3 and H4 rather than under C: the checker cannot detect it, and no formulation of C can.

**Two strikes of my own on the state model:**

**No lower bound on k** (D9). §2 grants the adversary "fewer than k attesters", which is vacuous at k = 0 — and at k = 0 an *empty* Σ satisfies `cardinal Σ ≥ k`, so an unsigned note releases. `checker.mlw` assumes k ≥ 1 in `wf`. It should be in §1 alongside "k-of-n".

**How `expired` is entered** (D7). §1 gives status as three-valued but never says how a credential becomes expired. MZ derives it from `s.time < a.expires` and has no `Expired` state at all. `checker.mlw` makes `Expire` a move, which is the weakest faithful reading and almost certainly not the intent. If expiry is derived from an expiry date and τ, then status is a *function* of R_h and τ_h rather than a stored field, condition 2 becomes time-dependent, and it interacts with Q1: a credential can expire between signing and checking.

**And three more from the correspondence note**, all in the PB↔MZ gap: MZ has no block height, so P3 cannot be stated against it (D2); the attester set is global rather than per event, with no threshold (D3); and the release log is keyed per event rather than per ⟨p, e⟩, which would exclude every later participant in the same event (D4).

---

## Beyond Q1–Q6: P1 and P2 as written are contradictory

> **Accepted, 2 October 2026.** Problem Book v1.2 §3 carries the correction and credits the strike. P2's premise is now `C(π, S_h₀) = release` — all five conditions, with the credential live and the policy unchanged through the window.

Not one of the six questions, but the sharpest thing I found.

**P2's antecedent is "conditions 1–3 hold at some height h₀ and A(p) remains live".** Condition 4 is not among them.

Take a π whose ⟨p, e⟩ was released at an earlier height. At h₀ its signatures are still valid (1), p is still live (2), and t is still inside the window (3). **P2 therefore demands a release within B. P1's corollary — "no replayed evidence ever releases value" — forbids exactly that.**

Read literally, the two properties contradict each other on replayed evidence. This is in the prose, not in the modelling.

**Proposed replacement:** P2's antecedent is `C(π, S_h₀) = release`, i.e. all five conditions, not 1–3. `checker.mlw` states it that way, which makes its P2 stronger in the antecedent than PB's text; the divergence is flagged rather than silently corrected.

---

Provenance: written with AI assistance (Claude). The classifications, proposals and the P1/P2 finding above are my own reading of the Problem Book against Model Zero, and I am responsible for them.
