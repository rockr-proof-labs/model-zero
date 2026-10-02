# Open problem: soundness and liveness of an attested-authorisation checker under replay, revocation races and clock skew

*Problem Book, RP1 — ROCKR Proof Labs Ltd · ROCKR Preuves. Draft v1.1, 23 September 2026 (v1 posted to the VeTSS Zulip, 3 September 2026). Written to be attacked at the definitions; every successful strike is credited.*

*v1.1 changes: §4 and §6 updated for Model Zero v0.2.1 (18 of 18 proved, published). Predicate, threat model, properties and questions unchanged from v1.*

-----

## 1. The object

A small component at a settlement boundary. Value is held in escrow for a person and an event; the checker decides whether it may be released. It has four inputs and one bit of output.

**Inputs**

- a *presence attestation* π = ⟨p, e, t, Σ⟩: principal p was present at authenticated event e at attester-time t, signed by a set Σ of attesters;
- the *identity credential* of p: an on-chain attestation A(p) issued at genesis-seeded accreditation, with status **live | revoked | expired**;
- the *committed chain state* S_h at height h, containing the revocation register R_h, the authorised attester set Att(e) with threshold k, the block time τ_h, and the release history;
- a *freshness policy* (Δ, ε): how far behind or ahead of block time an attester-time may lie.

**Output:** **release** (escrow for (p, e) settles to p's account) or **hold** (nothing moves).

**Decision predicate.** C(π, S_h) = release **iff**

1. Σ is a valid k-of-n signature set over ⟨p, e, t⟩ from Att(e) as recorded in S_h;
2. A(p) is **live** in R_h;
3. τ_h − Δ ≤ t ≤ τ_h + ε;
4. no release for (p, e) is recorded in S_h (single use);
5. the credited account is p's and no other.

Nothing else is consulted. In particular the checker never reads personal data: p is an on-chain identifier, and the identity verification behind A(p) happened elsewhere, under its own hypotheses.

## 2. The threat model

A network adversary with full control of the wire between attesters, the chain and the checker; control of any number of client devices; and control of fewer than k attesters for any event. The adversary may replay any message it has seen, delay or reorder any message, and submit arbitrary well-formed transactions. It does **not** control consensus (CometBFT with instant finality is assumed safe), the proof-checking kernel, or the signature scheme.

Out of scope here (they are separate packages with their own problems): whether the accredited attester really checked a human (RP4), what the gate protocol looks like on the device (RP3), erasure of A(p) with asset preservation (RP5).

## 3. The properties

- **P1 Soundness.** For every reachable S_h and every π: C(π, S_h) = release ⇒ conditions 1–5 hold. Corollary: no forged, replayed, expired, mismatched or revoked evidence ever releases value.
- **P2 Liveness.** If a valid π (conditions 1–3 hold at some height h₀ and A(p) remains live) is presented at h₀, then release occurs at some height h ≤ h₀ + B for a stated bound B, regardless of adversarial reordering.
- **P3 Revocation-atomicity.** The decision at height h is a function of R_h alone: a revocation committed at h′ > h cannot influence it, and a revocation committed at h′ ≤ h must. No read/act interval exists.
- **P4 Non-transferability.** Every release credits exactly p. No sequence of moves maps a release for (p, e) to an account q ≠ p.

## 4. What is proved, and what is not

- A Lean 4 model of the surrounding settlement system is published: Model Zero v0.2.1 (23 September 2026), Apache 2.0, https://github.com/rockr-proof-labs/model-zero/releases/tag/v0.2.1 — about 1,600 lines, Lean 4.21.0 core only, 29 move constructors, genesis and reachability. It states four whole-system theorems — attested transfer, issuance only against authenticated events, erasure with asset preservation, conservation with halt semantics — and their supporting lemmas. All eighteen statements are proved without sorry; axioms propext and Quot.sound (Lean's built-in) only, no Classical.choice, no custom axioms. The repository re-runs the kernel check and prints the axiom report on every change.
- Four hypotheses sit on the left of the turnstile and are never proved: signature validity; a single ordered log from consensus; honest attestation by accredited attesters (above threshold); authentication of the physical event. The checker inherits all four.
- The checker as a *distinct component* is the next artefact: its Lean statement is drafted against the predicate above; its interface is to be frozen in December 2026 so that implementation-level work can proceed against it. **Nothing is yet proved of any code.** The model-level proofs are short — case analysis on the move, then read the guard. The difficulty is in the definitions, which is why this page exists.

## 5. What I would like attacked — the open questions

**Q1 — Freshness under clock skew.** Attesters have their own clocks; the chain has block time. If attester clocks disagree with each other by up to δ and with τ_h by up to δ′, what (Δ, ε) makes P1 and P2 *simultaneously* satisfiable? Is there a replay across two events for the same p with near-coincident t that condition 4 fails to exclude, and should condition 4 be keyed on ⟨p, e⟩ or on ⟨p, e, t⟩?

**Q2 — Revocation races.** A revocation of A(p) and a valid π for p arrive in the same block. Under instant finality, what is the ordering rule that makes P3 well-defined — transaction order within the block, or "revocation always wins within a height"? Does the mempool give the adversary a lever here, and is P3 as stated the right property or should it be an invariant on block *construction* rather than on the checker?

**Q3 — Attester-set drift.** Att(e) may change between t (when π was signed) and h (when it is checked): rotation, slashing, admission. Which set is authoritative for condition 1 — the set at t, at h, or the intersection? Each choice breaks something (P1 under a compromised-then-removed attester; P2 under legitimate rotation). Is there a formulation that keeps both?

**Q4 — The liveness bound.** With an adversary who controls delivery but not consensus, what B is provable, and what does P2 mean if the attesters themselves are slow — is liveness a property of the checker, of the attesters, or of the pair?

**Q5 — Composition with the supply invariant.** A release is a move on the ledger. Does P1 compose with the conservation theorem (no move creates or destroys value; halt before miscount) without new hypotheses — or does escrow introduce a state the conservation theorem does not yet see (escrow expiry, refund path, partial release)?

**Q6 — Definition strikes.** Is the state model missing a channel? The obvious candidates: escrow expiry and refund; a person with two live credentials; an event whose Att(e) has fewer than k honest members at genesis; the credited account being a contract rather than a wallet. A strike here is worth more than a proof.

## 6. Why now, and what a reply gets you

The interface freezes in December so that a funded engineer, if a pending application lands, can build against it from day one. A strike on a definition now is a one-line change and a re-compile; the same strike in February stops a paid team. So the cheap window for definition attacks is the next ten weeks.

Every credited strike appears by name in the published artefact. The model and proof files are published under Apache 2.0 at the repository above; strikes and the resulting one-line changes are logged in the provenance record of each release. Prior art I already know and am not claiming to supersede: verified protocol work (Tamarin/ProVerif) for the key-establishment layer; the Parcoursup allocation proof (Why3/Coq, LaBRI) for entitlement without transfer or an external oracle; traceable e-cash (Trinity College Dublin) at the protocol layer. If you know a closer relative — especially anyone who has proved an authorisation state machine at a value-release boundary — I would like to read it.

Reply in thread, or to <david@rockrprooflabs.org>.
