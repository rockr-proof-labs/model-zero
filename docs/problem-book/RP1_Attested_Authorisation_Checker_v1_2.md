# Open problem: soundness and liveness of an attested-authorisation checker under replay, revocation races and clock skew

*Problem Book, RP1 — ROCKR Proof Labs Ltd · ROCKR Preuves. Version 1.2, 2 October 2026 (v1 posted to the VeTSS Zulip, 3 September 2026; v1.1, 23 September). Written to be attacked at the definitions; every successful strike is credited.*

*v1.2 changes, all ruled 2 October 2026 on strikes by Harikeshwaran Palani (Task 2, the checker stated in Why3): §1 — k ≥ 1; expiry derived from the expiry date; the freshness policy committed in S_h and read at check height; revocation acts on the principal. §3 — P2's premise corrected (it contradicted P1 on replayed evidence); P2 marked as a property of checker and network together; P3 given its ordering rule; P4 scoped to the immediate credit. §4 — proof status: the checker's Why3 statement, 13 of 15 obligations discharged. §5 — Q2 and Q3 ruled; Q6 strikes credited. §7 — credits.*

-----

## 1. The object

A small component at a settlement boundary. Value is held in escrow for a person and an event; the checker decides whether it may be released. It has four inputs and one bit of output.

**Inputs**

- a *presence attestation* π = ⟨p, e, t, Σ⟩: principal p was present at authenticated event e at attester-time t, signed by a set Σ of attesters;
- the *identity credential* of p: an on-chain attestation A(p) issued at genesis-seeded accreditation, with status **live | revoked | expired** — where *expired* is not a stored state but is derived from the attestation's expiry date and the block time τ_h, and *revoked* is a finding recorded against the principal p, under which every attestation of p ceases to count (an issuer merely ceasing to vouch — withdrawal — is not revocation);
- the *committed chain state* S_h at height h, containing the revocation register R_h, the authorised attester set Att(e) with threshold k ≥ 1, the block time τ_h, the release history, and the *freshness policy* (Δ, ε): how far behind or ahead of block time an attester-time may lie. The policy is governance-set, committed in S_h, and read at the height of checking.

**Output:** **release** (escrow for (p, e) settles to p's account) or **hold** (nothing moves).

**Decision predicate.** C(π, S_h) = release **iff**

1. Σ is a valid k-of-n signature set over ⟨p, e, t⟩ from Att(e) as recorded in S_h, with k ≥ 1 and each attester counted once;
2. A(p) is **live** in R_h at τ_h;
3. τ_h − Δ ≤ t ≤ τ_h + ε, against the policy committed in S_h;
4. no release for (p, e) is recorded in S_h (single use);
5. the credited account is p's and no other.

Nothing else is consulted. In particular the checker never reads personal data: p is an on-chain identifier, and the identity verification behind A(p) happened elsewhere, under its own hypotheses. Condition 1 counts a *set* of attesters; an implementation that receives signatures as a list must de-duplicate before comparing against k, or a single corrupt attester defeats the threshold alone.

## 2. The threat model

A network adversary with full control of the wire between attesters, the chain and the checker; control of any number of client devices; and control of fewer than k attesters for any event. The adversary may replay any message it has seen, delay or reorder any message, and submit arbitrary well-formed transactions. It does **not** control consensus (CometBFT with instant finality is assumed safe), the proof-checking kernel, or the signature scheme.

Out of scope here (they are separate packages with their own problems): whether the accredited attester really checked a human (RP4), what the gate protocol looks like on the device (RP3), erasure of A(p) with asset preservation (RP5).

## 3. The properties

- **P1 Soundness.** For every reachable S_h and every π: C(π, S_h) = release ⇒ conditions 1–5 hold. Corollary: no forged, replayed, expired, mismatched or revoked evidence ever releases value. (Replay is excluded by condition 4, not by freshness: a replayed π one second later is perfectly fresh.)
- **P2 Liveness.** If C(π, S_h₀) = release at some height h₀, and A(p) remains live and the policy unchanged through the window, then release occurs at some height h ≤ h₀ + B for a stated bound B. *v1.1 gave the premise as "conditions 1–3 hold"; on that reading a replayed π satisfies P2's premise while P1's corollary forbids its conclusion, so P1 and P2 contradicted each other (strike: H. Palani).* P2 is not a property of the checker alone: with the adversary of §2, no bound B exists for any checker. It holds only under a delivery hypothesis (H5, §4) and is a property of the checker together with the network; its formal statement requires executions, not reachable states, and is deferred to the December interface. B is a measured quantity of the real network.
- **P3 Revocation-atomicity.** The decision at height h is a function of R_h alone: a revocation committed at h′ > h cannot influence it, and a revocation committed at h′ ≤ h must. No read/act interval exists. *Ruled:* within a height, revocation always wins — R_h is the register after every revocation in block h has been applied — so the rule is enforced at block construction, and the checker is a pure function of a committed state.
- **P4 Non-transferability.** Every release credits exactly p. No sequence of moves maps a release for (p, e) to an account q ≠ p. P4 is a statement about the immediate credit; every account that can receive a release is an attested identifier with a single identified beneficial owner, and onward transfers are governed by the universal verification rule, not by C.

## 4. What is proved, and what is not

- **Model Zero** v0.2.1 (23 September 2026), Apache 2.0, github.com/rockr-proof-labs/model-zero — a Lean 4 model of the surrounding settlement system, about 1,600 lines, Lean 4.21.0 core only, 29 move constructors, genesis and reachability. It states four whole-system theorems — attested transfer, issuance only against authenticated events, erasure with asset preservation, conservation with halt semantics — and their supporting lemmas. All eighteen statements are proved without sorry; axioms propext and Quot.sound only. The repository re-runs the kernel check on every change.
- **The checker**, stated in Why3 (October 2026, same repository, `checker/why3/`): the predicate C as five separate conditions, an abstract step relation over the moves the checker can see, and the properties as goals. Thirteen of fifteen obligations — P1 and its corollaries, both halves of P3, both halves of P4, well-formedness preservation, and five supporting lemmas — are discharged by an SMT solver (Alt-Ergo 2.6.4 under Why3 1.8.2; reproduced with Z3 under Why3 1.6.0), each in under a second. One, well-formedness of every reachable state, is a structural induction beyond an SMT solver. P2 is stated in prose: as a goal over reachable states it is vacuous, and liveness requires executions. "Discharged" here means accepted by an SMT solver, a weaker guarantee than the kernel-checked Lean proofs; the statements are true of the model and an automatic prover can see why, as predicted below.
- Four hypotheses sit on the left of the turnstile and are never proved: signature validity (H1); a single ordered log from consensus (H2); honest attestation by accredited attesters above threshold (H3); authentication of the physical event (H4). The checker inherits all four. A fifth, **H5 — bounded delivery**: a presence attestation submitted to an honest node is included in a block within D blocks, inherited from CometBFT's partial-synchrony liveness guarantee — is required by P2 alone and is recorded here as a candidate for the trusted base; its exact form is open (§5, Q4).
- The checker as a *distinct component* at the implementation level is the next artefact: its interface is to be frozen in December 2026 so that implementation-level work can proceed against it. **Nothing is yet proved of any code.** The model-level proofs are short — case analysis on the move, then read the guard — and the Why3 result confirms it. The difficulty is in the definitions, which is why this page exists.

## 5. What I would like attacked — the open questions

**Q1 — Freshness under clock skew.** Attesters have their own clocks; the chain has block time. If attester clocks disagree with each other by up to δ and with τ_h by up to δ′, what (Δ, ε) makes P1 and P2 *simultaneously* satisfiable? *Partial answer (Palani):* liveness needs roughly ε ≥ δ′ and Δ ≥ δ′ + B_incl; nothing in P1 pushes back, since condition 3 is part of the decision; so the window is policy, not a soundness constraint, and replay is condition 4's business. *Ruled:* condition 4 stays keyed on ⟨p, e⟩; the policy in force is the one committed at check height. *Open:* making δ and δ′ explicit parameters of the policy and stating the inequality as a lemma; expiry between signing and checking now that condition 2 is time-dependent.

**Q2 — Revocation races.** *Ruled:* revocation always wins within a height (§3, P3). The question moves to block construction, where it is an invariant the implementation can test. *Open:* the ante-handler specification that enforces it.

**Q3 — Attester-set drift.** Att(e) may change between t and h: rotation, slashing, admission. *Partial answer (Palani):* the three naive readings each break P1 or P2 because "removal" conflates two things. *Rotation* is forward-looking and benign — signatures made while in post stay good. *Slashing* is a finding that the attester was already dishonest — their signatures stop counting retroactively. Condition 1 should require k-of-n from Att(e) at signing time t, minus attesters slashed for cause by h. *Ruled in principle, 2 October 2026;* the state-model change (an attester set indexed by time plus a slashed set, with the reason for every removal recorded) is for the December interface. *Open:* who may slash, on what record, and the interaction with the application's authentication tiers.

**Q4 — The liveness bound.** *Answer (Palani, confirmed):* no B is provable for the checker alone under §2's adversary; P2 is conditional on delivery and is a property of the pair. *Open:* the form of H5 — bounded or eventual inclusion; what "submitted" means when the relay may be adversarial; blocks or seconds — and the statement of P2 over executions. B itself is measured, not proved.

**Q5 — Composition with the supply invariant.** *Partial answer (Palani):* a checker-driven whole release is one of Model Zero's three escrow exits, already inside the conservation invariant, so composition needs no new hypothesis. *Open:* the composition itself (the checker's verdict is not yet connected to any value movement in Model Zero), and partial release, which does not exist in Model Zero and would need the invariant restated.

**Q6 — Definition strikes.** Four landed and are ruled: expiry is derived (§1); k ≥ 1 (§1); a person with several credentials — revocation acts on the principal, withdrawal does not (§1); the credited account being a contract — P4 scoped to the immediate credit (§3). Two further strikes on the gap between this page and Model Zero are recorded for v0.3: Model Zero has no block height, and its attester registry is global rather than per event. *Still open:* escrow expiry and refund paths at the release boundary; an event whose Att(e) has fewer than k honest members (under H3/H4, not C).

## 6. Why now, and what a reply gets you

The interface freezes in December so that a funded engineer, if a pending application lands, can build against it from day one. A strike on a definition now is a one-line change and a re-compile; the same strike in February stops a paid team. So the cheap window for definition attacks is the next eight weeks.

Every credited strike appears by name in the published artefact. The model and the checker statement are published under Apache 2.0 at the repository above; strikes and the resulting changes are logged in the provenance record of each release. Prior art I already know and am not claiming to supersede: verified protocol work (Tamarin/ProVerif) for the key-establishment layer; the Parcoursup allocation proof (Why3/Coq, LaBRI) for entitlement without transfer or an external oracle; traceable e-cash (Trinity College Dublin) at the protocol layer. If you know a closer relative — especially anyone who has proved an authorisation state machine at a value-release boundary — I would like to read it.

Reply in thread, or to <david@rockrprooflabs.org>.

## 7. Credits

**Harikeshwaran Palani** (Task 2, September–October 2026): the Why3 statement of the checker; the P1/P2 contradiction in §3 of v1.1; the policy-as-state correction; strikes D7 (expiry), D8 (policy drift), D9 (k ≥ 1), the rotation/slashing distinction (Q3), the two-credential and contract-recipient strikes (Q6), and the de-duplication obligation on condition 1. Rulings by David Clancy, 2 October 2026.
