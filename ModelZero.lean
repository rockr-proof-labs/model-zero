/-!
# ROCKRCOIN — Model Zero
## The chain as a state machine, the four theorems stated, the assumptions declared

ROCKR Proof Labs Ltd · ROCKR Preuves · Model Zero v0.2 · 18 August 2026
Drafted by Claude under David Clancy's rulings of 16–18 August 2026 (Decisions 1–15, R16–R19,
and the read-back strikes of 18 August).
Status: compiles under Lean 4.21.0 (core only, no Mathlib). 29 constructors (27 in v0.1 + forfeit, publishShape).
  Proved on the model (no `sorry`), 15 statements: T1_coin, T1_cred,
    T1_no_unauthorised_debit (D14b — no move debits a wallet but its own payer),
    RUIPA_nontransferable (R16), T2_issuance, T3_erasure, T4_halt, class_integrity,
    porch_requires_verdict, erased_can_still_transfer, grade_is_not_a_gate,
    forfeit_pays_no_one, contract_immune_to_governance, publishShape_moves_nothing,
    far_bid_is_bonded (plus helper lemmas creditAll_ge, upd_ne).
  Stated with `sorry`, 3 statements (the ledger arithmetic): T2_evidence, T4_ledger,
    T4_conservation.
  Nothing here is proved of any code. This is Grade 1 of a model validated in English by David
  on 18 August 2026 (read-back v0.1.1, §§2–8) with the strikes of that review carried in.
  Treat every claim as a target until an external reader has attacked the statements.

What this file is: the left of the turnstile written down. Γ = the definitions
(State, verified, every constructor of Step, Reachable) plus the declared
hypotheses H1–H4. The right of the turnstile = the theorems T1–T4 and their
supporting lemmas, stated but not yet proved.

Reading guide for the non-specialist is in the companion document
"Model Zero — English Read-Back". Rulings that shaped this file:

- D2  verified := non-expired at block time ∧ not revoked ∧ accredited issuer ∧ sigOK.
      Assurance grade is recorded and read by NO guard (2(iv) = C, one bar).
- D3  erasure touches only the off-chain link; DID, attestation, coin remain usable.
- D4  post-launch issuance only at settlement of an authenticated live experience;
      genesis ledger for pre-launch attested work; TARS is a bounded correction
      requiring an original issuance record and exists only in trial configuration.
      Fees are transfers of existing coin; the Protocol Auction Fee retires coin.
- D5  T4 in safety form: no reachable state breaks a supply invariant; halted states
      admit no further step.
- D11 T1 assets = coin (Main) + signed credentials; RUIPA non-transferable by construction.
- D12 settlement ladder is outside Γ; `porchRelease` requires the checker's verdict.
- D13 classification rule inside the model; thresholds are parameters in State.
- D14 (b): NO governance freeze-and-return constructor exists. See `T1_no_unauthorised_debit`.
- D15 whitepaper 8.1 canonical; storyboard v5 as narrative feed.
- RUIPA: instance-level, live-experience-only, becomes coin only on authentication.
- R16 RUIPA is a per-DID, per-week schedule; max 3,000 per participant per experience; 6,000
      debit per authenticated seat; hard forward locks; nothing carries across weeks; shortfall
      only via the Standard-Stake Exception.
- R17 bid horizon uncapped; free window (parameter, 52 weeks); a Main bond beyond it; a forward
      seat settles only if the participant is verified and active that week, else releases.
- R18 10% walk-in rule: growth/ordinary, capacity ≥ minCap, 10% capped at seatCap, final window;
      four parameters; policy outside Γ, replayable here as a guard on the bid constructors.
- R19 founder/anchor: genesis one-off + contractual envelope percentage fixed at genesis and
      immune to governance; infrastructure envelope lines governance-set.
- Read-back strikes: `forfeit` constructor (mark; RUIPA lock forfeited; Main bond retired);
      `erase` also deactivates and clears the schedule; `landscape` + `publishShape` with k-floor
      (no theorem reads it); Main-funded weekly cap counted; `resolvable` kept as RP5's shadow.
- Vocabulary: issuance, never the retired word.
-/

namespace ROCKR

/-! ## 0. Identifiers, time, coin -/

abbrev DID        := Nat
abbrev InstanceId := Nat
abbrev ExpId      := Nat
abbrev CredId     := Nat
abbrev Time       := Nat
abbrev Coin       := Nat

/-- Assurance grade of an identity attestation. Recorded; read by no guard (D2(iv) = C). -/
inductive Assurance where
  | substantial
  | high
deriving DecidableEq, Repr

/-! ## 1. The identity attestation — the five-field record, plus abstract signature validity -/

/-- The on-chain identity attestation. No personal data. `sigOK` abstracts H1. -/
structure Attestation where
  subject : DID
  issuer  : InstanceId
  level   : Assurance
  issued  : Time
  expires : Time
  sigOK   : Bool
deriving DecidableEq, Repr

/-! ## 2. Experiences, registrations, bids, credentials, issuance evidence -/

/-- The three event classes of whitepaper 8.1 §7.1.2. -/
inductive EventClass where
  | seeding    -- excess-demand fixed-price
  | growth     -- auction-cleared (RUIPA's principal home)
  | ordinary   -- neither; existing coin settles everything
deriving DecidableEq, Repr

structure Registration where
  did           : DID
  exp           : ExpId
  atStatedPrice : Bool
deriving DecidableEq, Repr

/-- A growth-tier bid. `fromMain = true` is the Standard-Stake Exception. -/
structure Bid where
  did      : DID
  exp      : ExpId
  amount   : Coin
  fromMain : Bool      -- Standard-Stake Exception: funded from Main
  week     : Nat       -- target week whose allowance is locked (R16)
  bond     : Bool      -- far-horizon bond from Main alongside a RUIPA lock (R17)
  bondAmount : Coin    -- Strike 2 (D-F): bond value frozen at lock time; 0 when `bond = false`
deriving DecidableEq, Repr

/-- A signed credential (ticket). Theorem 1 asset (D11). -/
structure Cred where
  id        : CredId
  holder    : DID
  exp       : ExpId
  faceValue : Coin
deriving DecidableEq, Repr

structure Experience where
  id                : ExpId
  organiser         : DID
  places            : Nat
  week              : Nat           -- the week whose allowance a seat draws on
  startTime         : Time          -- doors; the walk-in window is measured back from here
  instrumentFixed   : Bool          -- pricing instrument chosen before demand collection
  fiatSettled       : Bool          -- organiser paid in fiat outside the chain
  cls               : Option EventClass
  authenticated     : Bool          -- the LEAP verdict (oracle, H4)
  authenticatedDIDs : List DID      -- presence records (holder binding, §5.6)
  forfeitedDIDs     : List DID      -- failed the Tier B check: entry, ticket and grant lost
  abandoned         : Bool          -- opened-but-abandoned auction leaves a permanent record
deriving DecidableEq, Repr

/-- Evidence object left by every issuance. TARS may only fire against one of these. -/
structure IssuanceRecord where
  exp       : ExpId
  recipient : DID
  amount    : Coin
deriving DecidableEq, Repr

/-! ## 3. Governance parameters — policy values that live in State, not in the theorems -/

structure Params where
  hurdleRatioNum      : Nat     -- excess-demand ratio (registrations : places), numerator
  hurdleRatioDen      : Nat
  hurdleFloor         : Nat     -- absolute registration floor
  weeklyAllowance     : Coin    -- RUIPA per active participant per week (18,000)
  standardStake       : Coin    -- standard participant amount (3,000)
  twinnedDebit        : Coin    -- seeding-class RUIPA debit on authentication (6,000)
  feeCap              : Coin    -- cap on any in-transaction settlement fee
  retirementRateBp    : Nat     -- Protocol Auction Fee, basis points; 0 at launch
  mainFundedWeeklyCap : Nat     -- cap on Standard-Stake entries per participant per week
  trialConfig         : Bool    -- TARS present only when true (Plan C)
  freeWindowWeeks     : Nat     -- R17: forward bids beyond this need a Main bond (52)
  walkInMinCapacity   : Nat     -- R18: rule applies at capacity ≥ this (50)
  walkInPercent       : Nat     -- R18: fraction reserved (10)
  walkInSeatCap       : Nat     -- R18: absolute cap on reserved seats (25)
  walkInWindow        : Time    -- R18: reserved seats open this long before doors (24h)
  kFloor              : Nat     -- landscape k-anonymity floor for published shapes
deriving Repr

/-! ## 4. The State -/

structure State where
  time          : Time
  week          : Nat
  params        : Params
  halted        : Bool
  -- identity
  accredited    : InstanceId → Bool        -- protocol registry of instance keys (governance-only changes)
  attest        : DID → List Attestation
  revoked       : Attestation → Bool
  resolvable    : DID → Bool               -- OFF-CHAIN linkage exists (modelled so T3 can be stated)
  active        : DID → Bool               -- registered with some instance (RUIPA is instance-level)
  marks         : List DID                 -- Tier B forfeiture marks (permanent)
  holders       : List DID                 -- every DID that has ever been attested
  -- value
  bal           : DID → Coin               -- Main account
  ruipaUsed     : DID → Nat → Coin         -- allowance already committed, per DID per week (R16);
                                           -- remaining = weeklyAllowance − used; past weeks are dead
  locks         : List Bid                 -- committed bids awaiting authentication
  creds         : List Cred
  supply        : Coin                     -- total Main coin in existence
  retired       : Coin                     -- coin destroyed by the Protocol Auction Fee
  issued        : List IssuanceRecord      -- evidence of every issuance since genesis
  genesisTotal  : Coin                     -- published, itemised, closed at launch (D4)
  contractSchedule : List (DID × Nat)     -- R19: founder/anchor envelope shares in basis points,
                                           -- fixed at genesis; `govParams` cannot touch it
  -- experiences
  registrations : List Registration
  experiences   : List Experience
  porchLog      : List ExpId               -- checker verdicts released to the porch (D12)
  landscape     : List (Nat × Nat)         -- aggregate availability shapes (cell, count); no theorem reads it

/-! ## 5. Helpers -/

def upd (f : DID → Coin) (d : DID) (v : Coin) : DID → Coin :=
  fun x => if x = d then v else f x

/-- Update one (DID, week) cell of the RUIPA schedule. -/
def updW (f : DID → Nat → Coin) (d : DID) (w : Nat) (v : Coin) : DID → Nat → Coin :=
  fun x y => if x = d ∧ y = w then v else f x y

/-- Clear a DID's whole schedule (erasure / deactivation). -/
def clearW (f : DID → Nat → Coin) (d : DID) : DID → Nat → Coin :=
  fun x y => if x = d then 0 else f x y

def updB (f : DID → Bool) (d : DID) (v : Bool) : DID → Bool :=
  fun x => if x = d then v else f x

def updI (f : InstanceId → Bool) (i : InstanceId) (v : Bool) : InstanceId → Bool :=
  fun x => if x = i then v else f x

def updRev (f : Attestation → Bool) (a : Attestation) : Attestation → Bool :=
  fun x => if x = a then true else f x

def findExp (s : State) (e : ExpId) : Option Experience :=
  s.experiences.find? (fun x => x.id == e)

def replaceExp (s : State) (e : Experience) : List Experience :=
  s.experiences.map (fun x => if x.id == e.id then e else x)

/-- Verified registrations at the stated price for experience `e`. One DID, one registration is
    enforced by the `register` guard; this counts them. -/
def statedPriceRegs (s : State) (e : ExpId) : Nat :=
  (s.registrations.filter (fun r => r.exp == e && r.atStatedPrice)).length

/-- The excess-demand hurdle: ratio AND absolute floor (D13). Rule inside the model; numbers in Params. -/
def hurdleMet (s : State) (e : Experience) : Prop :=
  statedPriceRegs s e.id * s.params.hurdleRatioDen ≥ e.places * s.params.hurdleRatioNum
  ∧ statedPriceRegs s e.id ≥ s.params.hurdleFloor

/-- Envelope: the service issuance that accompanies every authenticated settlement (D4). -/
abbrev Envelope := List (DID × Coin)

def envTotal (env : Envelope) : Coin := (env.map (·.2)).foldl (· + ·) 0

def creditAll (bal : DID → Coin) : Envelope → (DID → Coin)
  | []            => bal
  | (d, c) :: rest => creditAll (upd bal d (bal d + c)) rest

/-- Committed seats for an experience (locks in place). -/
def locksFor (s : State) (e : ExpId) : Nat :=
  (s.locks.filter (fun b => b.exp == e)).length

/-- Main-funded (Standard-Stake) entries by a DID in a week. -/
def mainFundedCount (s : State) (d : DID) (w : Nat) : Nat :=
  (s.locks.filter (fun b => b.did == d && b.week == w && b.fromMain)).length

/-- R18: seats reserved for the final window; zero below the capacity floor and for seeding. -/
def reservedSeats (s : State) (e : Experience) : Nat :=
  if e.places ≥ s.params.walkInMinCapacity ∧ (e.cls = some .growth ∨ e.cls = some .ordinary)
  then min (e.places * s.params.walkInPercent / 100) s.params.walkInSeatCap
  else 0

/-- R18: seats available to a bid placed now — full capacity inside the window, else capacity
    minus the reservation. Policy outside Γ, carried here so the model can replay it. -/
def seatsOpen (s : State) (e : Experience) : Nat :=
  if s.time + s.params.walkInWindow ≥ e.startTime then e.places
  else e.places - reservedSeats s e

/-- R17: is the target week beyond the free forward window? -/
def beyondFreeWindow (s : State) (w : Nat) : Prop :=
  w > s.week + s.params.freeWindowWeeks

/-- R19: the contractual envelope lines for a settlement of `value`. -/
def contractEnv (s : State) (value : Coin) : Envelope :=
  s.contractSchedule.map (fun p => (p.1, value * p.2 / 10000))

def sumBal (s : State) : Coin :=
  ((s.holders.eraseDups).map s.bal).foldl (· + ·) 0

/-- Main coin held in locks: Standard-Stake amounts plus far-horizon bonds. -/
def lockedMain (s : State) : Coin :=
  ((s.locks.map (fun b => (if b.fromMain then b.amount else 0) + b.bondAmount))).foldl (· + ·) 0

def issuedTotal (s : State) : Coin :=
  (s.issued.map (·.amount)).foldl (· + ·) 0

/-! ## 6. `verified` — the word made precise (D2) -/

/-- A DID is verified at block time `s.time` iff it carries a non-expired, non-revoked attestation
    from an accredited instance with a valid signature. Assurance level is NOT consulted (D2(iv) = C). -/
def verified (s : State) (d : DID) : Prop :=
  ∃ a ∈ s.attest d,
    s.time < a.expires
    ∧ s.revoked a = false
    ∧ s.accredited a.issuer = true
    ∧ a.sigOK = true

/-! ## 7. Actions — every move the chain can make, and no others -/

inductive Action where
  -- identity
  | attestIssue    (a : Attestation)
  | revoke         (a : Attestation)
  | renew          (a : Attestation)                        -- re-attestation of the same DID
  | erase          (d : DID)                                -- GDPR erasure: off-chain link; deactivates
  | activate       (d : DID) | deactivate (d : DID)         -- instance registration status
  | govAccredit    (i : InstanceId) (v : Bool)
  | govParams      (p : Params)
  -- time
  | tick           (dt : Nat)
  | weekRoll                                                -- new week: the ended week's allowance is dead
  -- value: transfers (existing coin moves; supply unchanged)
  | transfer       (src dst : DID) (amt fee : Coin) (feeTo : DID)
  | transferCred   (c : Cred) (dst : DID)
  | retire         (payer : DID) (amt : Coin)               -- Protocol Auction Fee: coin destroyed
  -- experiences and demand
  | openExp        (e : Experience)
  | abandonAuction (e : ExpId)
  | register       (r : Registration)
  | classifySeeding (e : ExpId)
  | lockRuipa      (b : Bid)
  | bidMain        (b : Bid)                                -- Standard-Stake Exception
  | releaseLock    (b : Bid)
  | authenticate   (e : ExpId) (present forfeited : List DID) -- the LEAP verdict enters (H4)
  | forfeit        (e : ExpId) (b : Bid)                    -- Tier B failure: mark; lock lost; bond retired
  | publishShape   (cell count : Nat)                       -- aggregate availability; no theorem reads it
  -- issuance: only here does supply grow (D4)
  | settleSeeding  (e : ExpId) (d : DID) (env : Envelope)
  | settleGrowth   (e : ExpId) (b : Bid) (supplier : DID) (env : Envelope)
  | settleOrdinary (e : ExpId) (payer payee : DID) (amt fee : Coin) (feeTo : DID) (env : Envelope)
  | tarsRecover    (rec : IssuanceRecord) (amt : Coin)      -- trial configuration only
  -- porch and halt
  | porchRelease   (e : ExpId)
  | halt

/-! ## 8. Step — the transition relation.
Every constructor except `halt` requires `¬ s.halted`. No constructor debits a DID that did not act.
There is NO governance freeze-and-return constructor (D14 = b). -/

inductive Step : State → Action → State → Prop where

  | attestIssue (s : State) (a : Attestation)
      (hh : s.halted = false)
      (hacc : s.accredited a.issuer = true)
      (hsig : a.sigOK = true) :
      Step s (.attestIssue a)
        { s with attest := fun d => if d = a.subject then a :: s.attest d else s.attest d,
                 holders := a.subject :: s.holders,
                 resolvable := updB s.resolvable a.subject true }

  | revoke (s : State) (a : Attestation)
      (hh : s.halted = false)
      (hacc : s.accredited a.issuer = true) :
      Step s (.revoke a) { s with revoked := updRev s.revoked a }

  | renew (s : State) (a : Attestation)
      (hh : s.halted = false)
      (hacc : s.accredited a.issuer = true)
      (hsig : a.sigOK = true)
      (hhold : a.subject ∈ s.holders) :     -- Strike 3a-i: a first attestation is `attestIssue` only
      Step s (.renew a)
        { s with attest := fun d => if d = a.subject then a :: s.attest d else s.attest d,
                 resolvable := updB s.resolvable a.subject true }

  /-- Erasure (D3 + read-back strike): the off-chain link dies and the DID leaves the erasing
      instance (active false, RUIPA schedule cleared). Bal, creds, attest, locks, verified: unchanged. -/
  | erase (s : State) (d : DID)
      (hh : s.halted = false) :
      Step s (.erase d) { s with resolvable := updB s.resolvable d false,
                                 active := updB s.active d false,
                                 ruipaUsed := clearW s.ruipaUsed d }

  | activate (s : State) (d : DID)
      (hh : s.halted = false) (hv : verified s d) :
      Step s (.activate d) { s with active := updB s.active d true }

  | deactivate (s : State) (d : DID)
      (hh : s.halted = false) :
      Step s (.deactivate d) { s with active := updB s.active d false, ruipaUsed := clearW s.ruipaUsed d }

  | govAccredit (s : State) (i : InstanceId) (v : Bool)
      (hh : s.halted = false) :
      Step s (.govAccredit i v) { s with accredited := updI s.accredited i v }

  | govParams (s : State) (p : Params)
      (hh : s.halted = false) :
      Step s (.govParams p) { s with params := p }

  | tick (s : State) (dt : Nat)
      (hh : s.halted = false) :
      Step s (.tick dt) { s with time := s.time + dt }

  /-- New week (R16): the week counter advances. Nothing is credited — remaining allowance for a
      week is `weeklyAllowance − used`, and a week that has passed can no longer be bid against
      (guard `b.week ≥ s.week` on the bid constructors), so unused allowance simply dies. It never
      becomes supply and never carries. -/
  | weekRoll (s : State)
      (hh : s.halted = false) :
      Step s .weekRoll { s with week := s.week + 1 }

  /-- Theorem 1's transfer rule: two verified keys, fee capped, fee recipient verified. -/
  | transfer (s : State) (src dst : DID) (amt fee : Coin) (feeTo : DID)
      (hh : s.halted = false)
      (hsrc : verified s src) (hdst : verified s dst) (hfee : verified s feeTo)
      (hcap : fee ≤ s.params.feeCap)
      (hbal : s.bal src ≥ amt + fee) :
      Step s (.transfer src dst amt fee feeTo)
        { s with bal := -- Strike 3b (Option B): each write reads the balance left by the previous one
                        let b1 := upd s.bal src (s.bal src - amt - fee)
                        let b2 := upd b1 dst (b1 dst + amt)
                        upd b2 feeTo (b2 feeTo + fee) }

  /-- Theorem 1 for credentials (D11): holder and recipient both verified. Face-value pricing is
      a policy of the credential's terms, outside Γ. -/
  | transferCred (s : State) (c : Cred) (dst : DID)
      (hh : s.halted = false)
      (hin : c ∈ s.creds)
      (hsrc : verified s c.holder) (hdst : verified s dst) :
      Step s (.transferCred c dst)
        { s with creds := s.creds.map (fun x => if x = c then { x with holder := dst } else x) }

  /-- Protocol Auction Fee: coin retired, paid to no one. Only when the rate is non-zero. -/
  | retire (s : State) (payer : DID) (amt : Coin)
      (hh : s.halted = false)
      (hrate : s.params.retirementRateBp > 0)
      (hv : verified s payer)
      (hbal : s.bal payer ≥ amt) :
      Step s (.retire payer amt)
        { s with bal := upd s.bal payer (s.bal payer - amt),
                 supply := s.supply - amt,
                 retired := s.retired + amt }

  | openExp (s : State) (e : Experience)
      (hh : s.halted = false)
      (hnew : findExp s e.id = none)
      (hfresh : e.cls = none ∨ e.cls = some .ordinary ∨ e.cls = some .growth)
      (hnotauth : e.authenticated = false)
      (hnotab : e.abandoned = false)
      (horg : verified s e.organiser) :
      Step s (.openExp e) { s with experiences := e :: s.experiences }

  /-- Abandonment is permanent: the record is written and never cleared. -/
  | abandonAuction (s : State) (e : Experience)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e) :
      Step s (.abandonAuction e.id)
        { s with experiences := replaceExp s { e with abandoned := true } }

  /-- Registration: verified DID, fixed-instrument event only, one registration per DID per event.
      A bid is never a registration (different type). -/
  | register (s : State) (r : Registration) (e : Experience)
      (hh : s.halted = false)
      (hin : findExp s r.exp = some e)
      (hfixed : e.instrumentFixed = true)
      (hv : verified s r.did)
      (hone : ∀ r' ∈ s.registrations, r'.did = r.did → r'.exp ≠ r.exp) :
      Step s (.register r) { s with registrations := r :: s.registrations }

  /-- Classification (D13): earned by clearing the published hurdle, before sale, from on-chain
      registrations alone. Cannot be switched once set. -/
  | classifySeeding (s : State) (e : Experience)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e)
      (hnone : e.cls = none)
      (hfixed : e.instrumentFixed = true)
      (hhurdle : hurdleMet s e) :
      Step s (.classifySeeding e.id)
        { s with experiences := replaceExp s { e with cls := some .seeding } }

  /-- A RUIPA bid on a growth-tier experience (R16/R17/R18): active, verified, at most the standard
      stake, drawn from the target week's allowance (which must be the experience's week and not
      in the past), within the seats open now, and — beyond the free window — carrying a Main
      bond of the standard stake. -/
  | lockRuipa (s : State) (b : Bid) (e : Experience)
      (hh : s.halted = false)
      (hin : findExp s b.exp = some e)
      (hgrowth : e.cls = some .growth)
      (hact : s.active b.did = true)
      (hv : verified s b.did)
      (hnotmain : b.fromMain = false)
      (hweek : b.week = e.week) (hfuture : b.week ≥ s.week)
      (hcap : b.amount ≤ s.params.standardStake)
      (hhave : s.ruipaUsed b.did b.week + b.amount ≤ s.params.weeklyAllowance)
      (hseats : locksFor s e.id < seatsOpen s e)
      (hbond : b.bond = true ↔ beyondFreeWindow s b.week)
      (hbamt : b.bondAmount = if b.bond then s.params.standardStake else 0)   -- Strike 2b: frozen now
      (hbondbal : s.bal b.did ≥ b.bondAmount)                                  -- D-G: no lien
      (hnotsup : e.organiser ≠ b.did) :                                        -- D-K: no own-event bid
      Step s (.lockRuipa b)
        { s with ruipaUsed := updW s.ruipaUsed b.did b.week (s.ruipaUsed b.did b.week + b.amount),
                 bal := upd s.bal b.did (s.bal b.did - b.bondAmount),
                 locks := b :: s.locks }

  /-- Standard-Stake Exception (whitepaper 8.1 §7.1.2): the target week's allowance exhausted,
      exactly the standard amount from Main; settles the supply side by transfer; no participant
      grant; counted against the Main-funded weekly cap; within the seats open now (R18). -/
  | bidMain (s : State) (b : Bid) (e : Experience)
      (hh : s.halted = false)
      (hin : findExp s b.exp = some e)
      (hgrowth : e.cls = some .growth)
      (hact : s.active b.did = true)
      (hv : verified s b.did)
      (hmain : b.fromMain = true) (hnobond : b.bond = false)
      (hweek : b.week = e.week) (hfuture : b.week ≥ s.week)
      (hexh : s.ruipaUsed b.did b.week + s.params.standardStake > s.params.weeklyAllowance)
      (hexact : b.amount = s.params.standardStake)
      (hcapw : mainFundedCount s b.did b.week < s.params.mainFundedWeeklyCap)
      (hseats : locksFor s e.id < seatsOpen s e)
      (hbal : s.bal b.did ≥ b.amount)
      (hnobamt : b.bondAmount = 0)                                             -- Strike 2b
      (hnotsup : e.organiser ≠ b.did) :                                        -- D-K: no own-event bid
      Step s (.bidMain b)
        { s with bal := upd s.bal b.did (s.bal b.did - b.amount),
                 locks := b :: s.locks }

  /-- A losing (or withdrawn) bid releases to where it came from. -/
  | releaseLock (s : State) (b : Bid)
      (hh : s.halted = false)
      (hin : b ∈ s.locks) :
      Step s (.releaseLock b)
        { s with locks := s.locks.erase b,
                 ruipaUsed := if b.fromMain then s.ruipaUsed
                              else updW s.ruipaUsed b.did b.week (s.ruipaUsed b.did b.week - b.amount),
                 bal := upd s.bal b.did (s.bal b.did + (if b.fromMain then b.amount else 0)
                                                     + b.bondAmount) }   -- Strike 2a

  /-- The LEAP verdict enters the chain. This is the oracle boundary (H4): the model records
      the verdict; it does not judge it. -/
  | authenticate (s : State) (e : Experience) (present forfeited : List DID)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e)
      (hnot : e.authenticated = false)
      (hcls : e.cls ≠ none)
      (hpres : ∀ d ∈ present, verified s d) :
      Step s (.authenticate e.id present forfeited)
        { s with experiences := replaceExp s { e with authenticated := true,
                                                      authenticatedDIDs := present,
                                                      forfeitedDIDs := forfeited } }

  /-- Tier B failure (read-back strike): permanent mark; a RUIPA lock is forfeited (the allowance
      stays used and dies with its week); a Main-funded amount and any bond are RETIRED — paid to
      no one, so no party gains from a failed check. -/
  | forfeit (s : State) (e : Experience) (b : Bid)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e)
      (hauth : e.authenticated = true)
      (hbe : b.exp = e.id)
      (hfail : b.did ∈ e.forfeitedDIDs)
      (hlock : b ∈ s.locks) :
      Step s (.forfeit e.id b)
        { s with locks := s.locks.erase b,
                 marks := b.did :: s.marks,
                 supply := s.supply - ((if b.fromMain then b.amount else 0) + b.bondAmount),
                 retired := s.retired + ((if b.fromMain then b.amount else 0) + b.bondAmount) }

  /-- Aggregate availability shape published by an instance under a k-anonymity floor. Moves no
      value; read by no theorem. -/
  | publishShape (s : State) (cell count : Nat)
      (hh : s.halted = false)
      (hk : count ≥ s.params.kFloor) :
      Step s (.publishShape cell count) { s with landscape := (cell, count) :: s.landscape }

  /-- Seeding-class settlement, per authenticated participant: twinned debit from RUIPA; the
      participant's half is issued to Main; the supply-side half expires (organiser paid in fiat);
      the service envelope issues. -/
  | settleSeeding (s : State) (e : Experience) (d : DID) (env : Envelope)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e)
      (hcls : e.cls = some .seeding)
      (hauth : e.authenticated = true)
      (hpres : d ∈ e.authenticatedDIDs)
      (hv : verified s d)
      (hact : s.active d = true)
      (hhave : s.ruipaUsed d e.week + s.params.twinnedDebit ≤ s.params.weeklyAllowance)
      (henv : ∀ p ∈ env, verified s p.1)
      (hcon : ∀ p ∈ contractEnv s s.params.standardStake, verified s p.1) :
      Step s (.settleSeeding e.id d env)
        { s with ruipaUsed := updW s.ruipaUsed d e.week (s.ruipaUsed d e.week + s.params.twinnedDebit),
                 bal    := creditAll (upd s.bal d (s.bal d + s.params.standardStake))
                             (env ++ contractEnv s s.params.standardStake),
                 supply := s.supply + s.params.standardStake
                           + envTotal (env ++ contractEnv s s.params.standardStake),
                 issued := { exp := e.id, recipient := d, amount := s.params.standardStake } ::
                           ((env ++ contractEnv s s.params.standardStake).map
                              (fun p => { exp := e.id, recipient := p.1, amount := p.2 })) ++ s.issued }

  /-- Growth-class settlement, per winning bid. RUIPA-funded: both sides issued (X=Y).
      Main-funded (Standard-Stake): supply side by transfer, no participant grant. Envelope issues either way. -/
  | settleGrowth (s : State) (e : Experience) (b : Bid) (supplier : DID) (env : Envelope)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e)
      (hcls : e.cls = some .growth)
      (hauth : e.authenticated = true)
      (hpres : b.did ∈ e.authenticatedDIDs)
      (hlock : b ∈ s.locks) (hbe : b.exp = e.id)
      (hv : verified s b.did) (hact : s.active b.did = true)   -- R17: verified AND active that week
      (hsup : verified s supplier)
      (henv : ∀ p ∈ env, verified s p.1)
      (hcon : ∀ p ∈ contractEnv s b.amount, verified s p.1) :
      Step s (.settleGrowth e.id b supplier env)
        { s with locks  := s.locks.erase b,
                 bal    := creditAll
                             (let bal1 := if b.fromMain
                                then upd s.bal supplier (s.bal supplier + b.amount)
                                else let b0 := upd s.bal b.did (s.bal b.did + b.amount)   -- Strike 3b
                                     upd b0 supplier (b0 supplier + b.amount)
                              -- a far-horizon bond returns to its owner on successful settlement (Strike 2)
                              upd bal1 b.did (bal1 b.did + b.bondAmount))
                             (env ++ contractEnv s b.amount),
                 supply := s.supply + (if b.fromMain then 0 else 2 * b.amount)
                           + envTotal (env ++ contractEnv s b.amount),
                 issued := (if b.fromMain then []
                            else [{ exp := e.id, recipient := b.did,   amount := b.amount },
                                  { exp := e.id, recipient := supplier, amount := b.amount }])
                           ++ ((env ++ contractEnv s b.amount).map
                                 (fun p => { exp := e.id, recipient := p.1, amount := p.2 })) ++ s.issued }

  /-- Ordinary-class settlement: existing coin moves (a Theorem 1 transfer with capped fee);
      no participant or supply-side issuance; the service envelope issues. -/
  | settleOrdinary (s : State) (e : Experience) (payer payee : DID) (amt fee : Coin) (feeTo : DID) (env : Envelope)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e)
      (hcls : e.cls = some .ordinary)
      (hauth : e.authenticated = true)
      (hv1 : verified s payer) (hv2 : verified s payee) (hv3 : verified s feeTo)
      (hcap : fee ≤ s.params.feeCap)
      (hbal : s.bal payer ≥ amt + fee)
      (henv : ∀ p ∈ env, verified s p.1)
      (hcon : ∀ p ∈ contractEnv s amt, verified s p.1) :
      Step s (.settleOrdinary e.id payer payee amt fee feeTo env)
        { s with bal    := creditAll (let b1 := upd s.bal payer (s.bal payer - amt - fee)   -- Strike 3b
                                      let b2 := upd b1 payee (b1 payee + amt)
                                      upd b2 feeTo (b2 feeTo + fee))
                                     (env ++ contractEnv s amt),
                 supply := s.supply + envTotal (env ++ contractEnv s amt),
                 issued := ((env ++ contractEnv s amt).map
                              (fun p => { exp := e.id, recipient := p.1, amount := p.2 })) ++ s.issued }

  /-- TARS (Plan C, trial configuration only): a bounded correction against an EXISTING issuance
      record. Not a new source of coin. Global caps are Params of the trial; left symbolic here. -/
  | tarsRecover (s : State) (rec : IssuanceRecord) (amt : Coin)
      (hh : s.halted = false)
      (htrial : s.params.trialConfig = true)
      (hrec : rec ∈ s.issued)
      (hcap : amt ≤ rec.amount)
      (hv : verified s rec.recipient) :
      Step s (.tarsRecover rec amt)
        { s with bal    := upd s.bal rec.recipient (s.bal rec.recipient + amt),
                 supply := s.supply + amt,
                 issued := { rec with amount := amt } :: s.issued }

  /-- The porch (D12): held fiat may be released only on the checker's verdict — i.e. only for an
      authenticated experience. The ladder (when) is policy outside Γ; whether is this guard. -/
  | porchRelease (s : State) (e : Experience)
      (hh : s.halted = false)
      (hin : findExp s e.id = some e)
      (hauth : e.authenticated = true) :
      Step s (.porchRelease e.id) { s with porchLog := e.id :: s.porchLog }

  /-- Halt: the chain stops. Any running state may halt; a halted state admits no further step. -/
  | halt (s : State)
      (hh : s.halted = false) :
      Step s .halt { s with halted := true }

/-! ## 9. Genesis and reachability -/

/-- Genesis (D4): the published, itemised allocation for pre-launch attested work, closed at launch.
    Every genesis DID carries an attestation. This is a STATE, not a move; the theorems are about moves. -/
structure Genesis where
  ledger  : List (DID × Coin)
  attests : List Attestation
  params  : Params
  accreditedList : List InstanceId
  contractSchedule : List (DID × Nat)                 -- R19: published pre-launch, immovable
  wf : ∀ p ∈ ledger, ∃ a ∈ attests, a.subject = p.1   -- every genesis DID is attested

def Genesis.total (g : Genesis) : Coin := (g.ledger.map (·.2)).foldl (· + ·) 0

def genesisState (g : Genesis) : State :=
  { time := 0, week := 0, params := g.params, halted := false,
    accredited := fun i => g.accreditedList.contains i,
    attest := fun d => g.attests.filter (fun a => a.subject == d),
    revoked := fun _ => false,
    resolvable := fun d => g.attests.any (fun a => a.subject == d),
    active := fun _ => false, marks := [],
    holders := g.attests.map (·.subject),
    bal := creditAll (fun _ => 0) g.ledger,
    ruipaUsed := fun _ _ => 0,
    locks := [], creds := [],
    supply := g.total, retired := 0, issued := [],
    genesisTotal := g.total, contractSchedule := g.contractSchedule,
    registrations := [], experiences := [], porchLog := [], landscape := [] }

/-- The states the chain can ever be in: genesis, closed under Step. -/
inductive Reachable (g : Genesis) : State → Prop where
  | genesis : Reachable g (genesisState g)
  | step {s a s'} : Reachable g s → Step s a s' → Reachable g s'

/-! ## 10. Declared hypotheses H1–H4 (D7) — the oracle boundary, written on the left of ⊢ -/

/-- Opaque real-world predicates the chain cannot see. -/
opaque realHuman : DID → Prop
opaque happened  : ExpId → Prop
opaque presentAt : DID → ExpId → Prop
opaque signedBy  : Attestation → InstanceId → Prop

/-- H1 — signature unforgeability: a valid signature came from the named issuer's key. -/
axiom H1_unforgeable : ∀ a : Attestation, a.sigOK = true → signedBy a a.issuer

/-- H2 — consensus safety: under fewer than one third faulty validators, CometBFT commits a single
    ordered log; hence there is one Reachable trace. Stated as an axiom about the framework, not
    proved here. -/
axiom H2_consensus_single_trace : True

/-- H3 — accredited-verifier honesty: an accredited instance only attests real humans. -/
axiom H3_verifier_honest : ∀ (s : State) (a : Attestation),
  s.accredited a.issuer = true → a.sigOK = true → realHuman a.subject

/-- H4 — gate-quorum honesty: an authenticated experience happened, and each authenticated DID
    was present. RP3's false-acceptance bound is the research that shrinks this assumption. -/
axiom H4_gate_honest : ∀ (s : State) (e : Experience),
  e ∈ s.experiences → e.authenticated = true →
    happened e.id ∧ ∀ d ∈ e.authenticatedDIDs, presentAt d e.id

/-! ## 11. The four theorems and lemmas — see header for which are proved and which are open -/

/-- Which DID, if any, is debited by an action (the actor whose key must have signed). -/
def payer : Action → Option DID
  | .transfer src _ _ _ _        => some src
  | .retire p _                  => some p
  | .bidMain b                   => some b.did
  | .lockRuipa b                 => some b.did      -- debits b.bondAmount (0 unless b.bond, R17)
  | .settleOrdinary _ p _ _ _ _ _ => some p
  | _                            => none

/-- **Theorem 1 (attested transfer), coin.** A settled transfer has a verified sender and receiver. -/
theorem T1_coin (g : Genesis) (s s' : State) (src dst : DID) (amt fee : Coin) (feeTo : DID)
    (hr : Reachable g s) (hs : Step s (.transfer src dst amt fee feeTo) s') :
    verified s src ∧ verified s dst := by
  cases hs with
  | transfer _ _ _ _ _ _ hsrc hdst _ _ _ => exact ⟨hsrc, hdst⟩

/-- **Theorem 1, credentials (D11).** -/
theorem T1_cred (g : Genesis) (s s' : State) (c : Cred) (dst : DID)
    (hr : Reachable g s) (hs : Step s (.transferCred c dst) s') :
    verified s c.holder ∧ verified s dst := by
  cases hs with
  | transferCred _ _ _ _ hsrc hdst => exact ⟨hsrc, hdst⟩

/-- Crediting an envelope never lowers any balance. -/
theorem creditAll_ge (env : Envelope) : ∀ (bal : DID → Coin) (d : DID), bal d ≤ creditAll bal env d := by
  induction env with
  | nil => intro bal d; exact Nat.le_refl _
  | cons p rest ih =>
    intro bal d
    obtain ⟨d', c⟩ := p
    show bal d ≤ creditAll (upd bal d' (bal d' + c)) rest d
    have h1 : bal d ≤ upd bal d' (bal d' + c) d := by
      simp only [upd]
      split
      · rename_i h; subst h; exact Nat.le_add_right _ _
      · exact Nat.le_refl _
    exact Nat.le_trans h1 (ih _ d)

/-- `upd` at another key changes nothing; at the same key gives the value. -/
theorem upd_ne {f : DID → Coin} {d x : DID} {v : Coin} (h : x ≠ d) : upd f d v x = f x := by
  simp [upd, h]

/-- A credit never lowers any balance (v0.2.1 helper for the sequential updates of Strike 3b). -/
theorem le_upd_self (f : DID → Coin) (x : DID) (c : Coin) (y : DID) : f y ≤ upd f x (f x + c) y := by
  unfold upd
  split
  · rename_i h; subst h; exact Nat.le_add_right _ _
  · exact Nat.le_refl _



/-- **Theorem 1, closure / no unauthorised debit (D14 = b).** A DID's Main balance never falls
    unless that DID is the payer of the action. There is no governance freeze-and-return. -/
theorem T1_no_unauthorised_debit (s s' : State) (a : Action) (d : DID)
    (hs : Step s a s') (hdec : s'.bal d < s.bal d) :
    payer a = some d := by
  -- v0.2.1: statement unchanged; proof re-done for the sequential updates (Strike 3b) and the
  -- recorded bond (Strike 2). Every non-payer balance is reached by credits only (`le_upd_self`).
  cases hs with
  | transfer src dst amt fee feeTo _ _ _ _ _ _ =>
    simp only [payer]
    by_cases h3 : d = src
    · exact congrArg some h3.symm
    · exfalso
      have h1 : s.bal d ≤ upd s.bal src (s.bal src - amt - fee) d := by rw [upd_ne h3]; exact Nat.le_refl _
      have h2 := le_upd_self (upd s.bal src (s.bal src - amt - fee)) dst amt d
      have h4 := le_upd_self (let b1 := upd s.bal src (s.bal src - amt - fee); upd b1 dst (b1 dst + amt)) feeTo fee d
      exact absurd (Nat.le_trans (Nat.le_trans h1 h2) h4) (Nat.not_le.mpr hdec)
  | retire p amt _ _ _ _ =>
    simp only [payer]
    by_cases h : d = p
    · exact congrArg some h.symm
    · exfalso; simp [upd, h] at hdec
  | bidMain b _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ =>
    simp only [payer]
    by_cases h : d = b.did
    · exact congrArg some h.symm
    · exfalso; simp [upd, h] at hdec
  | lockRuipa b _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ =>
    simp only [payer]
    by_cases h : d = b.did
    · exact congrArg some h.symm
    · exfalso; simp [upd, h] at hdec
  | settleOrdinary e payer' payee amt fee feeTo env _ _ _ _ _ _ _ _ _ _ _ =>
    simp only [payer]
    by_cases h : d = payer'
    · exact congrArg some h.symm
    · exfalso
      have h1 : s.bal d ≤ upd s.bal payer' (s.bal payer' - amt - fee) d := by rw [upd_ne h]; exact Nat.le_refl _
      have h2 := le_upd_self (upd s.bal payer' (s.bal payer' - amt - fee)) payee amt d
      have h4 := le_upd_self (let b1 := upd s.bal payer' (s.bal payer' - amt - fee); upd b1 payee (b1 payee + amt)) feeTo fee d
      have hge := creditAll_ge (env ++ contractEnv s amt)
        (let b1 := upd s.bal payer' (s.bal payer' - amt - fee)
         let b2 := upd b1 payee (b1 payee + amt)
         upd b2 feeTo (b2 feeTo + fee)) d
      exact absurd (Nat.le_trans (Nat.le_trans (Nat.le_trans h1 h2) h4) hge) (Nat.not_le.mpr hdec)
  | settleSeeding e d' env _ _ _ _ _ _ _ _ _ _ =>
    exfalso
    have hge := creditAll_ge (env ++ contractEnv s s.params.standardStake) (upd s.bal d' (s.bal d' + s.params.standardStake)) d
    have hbase := le_upd_self s.bal d' s.params.standardStake d
    exact absurd (Nat.le_trans hbase hge) (Nat.not_le.mpr hdec)
  | settleGrowth e b sup env _ _ _ _ _ _ _ _ _ _ _ _ =>
    exfalso
    have hb1 : s.bal d ≤ (if b.fromMain
          then upd s.bal sup (s.bal sup + b.amount)
          else let b0 := upd s.bal b.did (s.bal b.did + b.amount)
               upd b0 sup (b0 sup + b.amount)) d := by
      cases b.fromMain
      · exact Nat.le_trans (le_upd_self s.bal b.did b.amount d)
          (le_upd_self (upd s.bal b.did (s.bal b.did + b.amount)) sup b.amount d)
      · exact le_upd_self s.bal sup b.amount d
    have hb2 := le_upd_self (if b.fromMain
          then upd s.bal sup (s.bal sup + b.amount)
          else let b0 := upd s.bal b.did (s.bal b.did + b.amount)
               upd b0 sup (b0 sup + b.amount)) b.did b.bondAmount d
    have hge := creditAll_ge (env ++ contractEnv s b.amount)
        (let bal1 := if b.fromMain
            then upd s.bal sup (s.bal sup + b.amount)
            else let b0 := upd s.bal b.did (s.bal b.did + b.amount)
                 upd b0 sup (b0 sup + b.amount)
         upd bal1 b.did (bal1 b.did + b.bondAmount)) d
    exact absurd (Nat.le_trans (Nat.le_trans hb1 hb2) hge) (Nat.not_le.mpr hdec)
  | releaseLock b _ _ =>
    exfalso
    by_cases h : d = b.did
    · subst h; simp only [upd, if_true] at hdec
      exact absurd hdec (Nat.not_lt.mpr (Nat.le_trans (Nat.le_add_right _ _) (Nat.le_add_right _ _)))
    · simp [upd, h] at hdec
  | tarsRecover rec amt _ _ _ _ _ =>
    exfalso
    by_cases h : d = rec.recipient
    · subst h; simp only [upd, if_true] at hdec; exact absurd hdec (Nat.not_lt.mpr (Nat.le_add_right _ _))
    · simp [upd, h] at hdec
  | _ => exact absurd hdec (Nat.lt_irrefl _)

/-- **RUIPA is non-transferable by construction (R16).** A step that changes one DID's schedule
    changes no other DID's schedule: allowance moves only between a participant and the protocol
    (lock, release, consumption, erasure/deactivation), never between participants, and never
    across weeks (each cell is its own week). -/
theorem RUIPA_nontransferable (s s' : State) (a : Action) (x y : DID) (w w' : Nat)
    (hs : Step s a s') (hxy : x ≠ y)
    (hx : s'.ruipaUsed x w ≠ s.ruipaUsed x w) :
    s'.ruipaUsed y w' = s.ruipaUsed y w' := by
  cases hs with
  | erase d _ =>
    simp only [clearW] at hx ⊢
    by_cases hxd : x = d
    · subst hxd; simp [Ne.symm hxy]
    · simp [hxd] at hx
  | deactivate d _ =>
    simp only [clearW] at hx ⊢
    by_cases hxd : x = d
    · subst hxd; simp [Ne.symm hxy]
    · simp [hxd] at hx
  | lockRuipa b _ _ _ _ _ _ _ _ _ _ _ _ _ _ =>
    simp only [updW] at hx ⊢
    by_cases hxd : x = b.did
    · have hne : ¬ (y = b.did ∧ w' = b.week) := fun h => hxy (hxd.trans h.1.symm)
      rw [if_neg hne]
    · simp [hxd] at hx
  | settleSeeding e d env _ _ _ _ _ _ _ _ _ _ =>
    simp only [updW] at hx ⊢
    by_cases hxd : x = d
    · have hne : ¬ (y = d ∧ w' = e.week) := fun h => hxy (hxd.trans h.1.symm)
      rw [if_neg hne]
    · simp [hxd] at hx
  | releaseLock b _ _ =>
    by_cases hm : b.fromMain = true
    · simp [hm] at hx
    · have hm' : b.fromMain = false := by
        cases hb : b.fromMain <;> simp_all
      simp only [hm', Bool.false_eq_true, if_false] at hx ⊢
      simp only [updW] at hx ⊢
      by_cases hxd : x = b.did
      · have hne : ¬ (y = b.did ∧ w' = b.week) := fun h => hxy (hxd.trans h.1.symm)
        rw [if_neg hne]
      · simp [hxd] at hx
  | _ => exact absurd rfl hx

/-- Which actions may increase supply. -/
def issuanceAction : Action → Prop
  | .settleSeeding _ _ _        => True
  | .settleGrowth _ _ _ _       => True
  | .settleOrdinary _ _ _ _ _ _ _ => True
  | .tarsRecover _ _            => True
  | _                           => False

/-- The experience an action settles, if any. -/
def actionExp : Action → Option ExpId
  | .settleSeeding e _ _          => some e
  | .settleGrowth e _ _ _         => some e
  | .settleOrdinary e _ _ _ _ _ _ => some e
  | _                             => none

/-- **Theorem 2 (issuance only against authenticated live experience).** If supply grows, the
    action was a settlement of an experience that is authenticated in `s`, or (trial configuration
    only) a TARS correction against an existing issuance record. -/
theorem T2_issuance (g : Genesis) (s s' : State) (a : Action)
    (hr : Reachable g s) (hs : Step s a s') (hgrow : s'.supply > s.supply) :
    (∃ eid e, actionExp a = some eid ∧ findExp s eid = some e ∧ e.authenticated = true)
    ∨ (∃ rec amt, a = .tarsRecover rec amt ∧ rec ∈ s.issued ∧ s.params.trialConfig = true) := by
  cases hs with
  | settleSeeding e d env _ hin _ hauth _ _ _ _ _ _ => exact Or.inl ⟨e.id, e, rfl, hin, hauth⟩
  | settleGrowth e b sup env _ hin _ hauth _ _ _ _ _ _ _ _ => exact Or.inl ⟨e.id, e, rfl, hin, hauth⟩
  | settleOrdinary e p q amt fee ft env _ hin _ hauth _ _ _ _ _ _ _ => exact Or.inl ⟨e.id, e, rfl, hin, hauth⟩
  | tarsRecover rec amt _ htrial hrec _ _ => exact Or.inr ⟨rec, amt, rfl, hrec, htrial⟩
  | retire _ _ _ _ _ _ => exact absurd hgrow (by simp)
  | forfeit _ _ _ _ _ _ _ _ => exact absurd hgrow (by simp)
  | _ => exact absurd hgrow (by simp)

/-- **Theorem 2, sharp form (RP2).** Every unit of increase is matched by issuance records left in `s'`. -/
theorem T2_evidence (g : Genesis) (s s' : State) (a : Action)
    (hr : Reachable g s) (hs : Step s a s') :
    s'.supply + s'.retired + issuedTotal s = s.supply + s.retired + issuedTotal s' := by
  sorry

/-- **Theorem 3 (erasure with asset preservation).** Erasure leaves balances, credentials,
    attestations, locks, supply and verified status unchanged; it cuts the off-chain link and ends
    the DID's membership of the erasing instance (read-back strike: `active` false, schedule cleared). -/
theorem T3_erasure (s s' : State) (d : DID) (hs : Step s (.erase d) s') :
    s'.bal = s.bal ∧ s'.creds = s.creds ∧ s'.attest = s.attest ∧ s'.locks = s.locks
    ∧ s'.supply = s.supply
    ∧ (verified s' d ↔ verified s d)
    ∧ s'.resolvable d = false
    ∧ s'.active d = false := by
  cases hs with
  | erase _ _ =>
    refine ⟨rfl, rfl, rfl, rfl, rfl, Iff.rfl, ?_, ?_⟩ <;> simp [updB]

/-- **Theorem 4 (supply invariants with halt semantics), ledger identity.** In every reachable state,
    supply plus retired equals genesis plus the sum of all issuance records: no money from nowhere. -/
theorem T4_ledger (g : Genesis) (s : State) (hr : Reachable g s) :
    s.supply + s.retired = s.genesisTotal + issuedTotal s := by
  sorry

/-- **Theorem 4, balance conservation.** In every reachable state, supply equals the sum of all
    holders' Main balances plus Main-funded locks. -/
theorem T4_conservation (g : Genesis) (s : State) (hr : Reachable g s) :
    s.supply = sumBal s + lockedMain s := by
  sorry

/-- **Theorem 4, halt semantics.** A halted state admits no further step. Together with the two
    invariants above this is the safety form: no block ever commits with an invariant broken; the
    chain halts first. -/
theorem T4_halt (s s' : State) (a : Action) (hh : s.halted = true) (hs : Step s a s') : False := by
  cases hs <;> simp_all

/-! ## 12. Supporting lemmas from the rulings -/

/-- **Class integrity (D13, RP2).** Seeding classification implies the hurdle was met from on-chain
    registrations, the instrument was fixed beforehand, and the class had not been set. -/
theorem class_integrity (s s' : State) (eid : ExpId)
    (hs : Step s (.classifySeeding eid) s') :
    ∃ e, findExp s eid = some e ∧ hurdleMet s e ∧ e.instrumentFixed = true ∧ e.cls = none := by
  cases hs with
  | classifySeeding e _ hin hnone hfixed hhurdle => exact ⟨e, hin, hhurdle, hfixed, hnone⟩

/-- **Porch release requires the verdict (D12).** -/
theorem porch_requires_verdict (s s' : State) (eid : ExpId)
    (hs : Step s (.porchRelease eid) s') :
    ∃ e, findExp s eid = some e ∧ e.authenticated = true := by
  cases hs with
  | porchRelease e _ hin hauth => exact ⟨e, hin, hauth⟩

/-- **Erasure does not stop spending (D3).** After erasure, if the DID was verified it still is,
    and any transfer it could make it can still make. -/
theorem erased_can_still_transfer (s s' : State) (d dst : DID) (amt fee : Coin) (feeTo : DID)
    (he : Step s (.erase d) s')
    (hpre : ∃ t, Step s (.transfer d dst amt fee feeTo) t) :
    ∃ t', Step s' (.transfer d dst amt fee feeTo) t' := by
  cases he with
  | erase _ _ =>
    obtain ⟨t, ht⟩ := hpre
    cases ht with
    | transfer _ _ _ _ _ hh hsrc hdst hfee hcap hbal =>
      exact ⟨_, Step.transfer _ _ _ _ _ _ hh hsrc hdst hfee hcap hbal⟩

/-- **Forfeiture retires, never pays (read-back strike).** A forfeit move never increases any
    balance: no party gains from a failed Tier B check. -/
theorem forfeit_pays_no_one (s s' : State) (eid : ExpId) (b : Bid) (d : DID)
    (hs : Step s (.forfeit eid b) s') :
    s'.bal d = s.bal d := by
  cases hs with
  | forfeit _ _ _ _ _ _ _ _ => rfl

/-- **Contractual envelope is immune to governance (R19).** `govParams` leaves the schedule alone. -/
theorem contract_immune_to_governance (s s' : State) (p : Params)
    (hs : Step s (.govParams p) s') :
    s'.contractSchedule = s.contractSchedule := by
  cases hs with
  | govParams _ _ => rfl

/-- **Landscape moves no value.** -/
theorem publishShape_moves_nothing (s s' : State) (c n : Nat)
    (hs : Step s (.publishShape c n) s') :
    s'.bal = s.bal ∧ s'.supply = s.supply := by
  cases hs with
  | publishShape _ _ _ _ => exact ⟨rfl, rfl⟩

/-- **A far-horizon RUIPA bid carries a bond exactly when beyond the free window (R17).** -/
theorem far_bid_is_bonded (s s' : State) (b : Bid)
    (hs : Step s (.lockRuipa b) s') :
    (b.bond = true ↔ beyondFreeWindow s b.week) := by
  cases hs with
  | lockRuipa _ _ _ _ _ _ _ _ _ _ _ _ _ hbond _ => exact hbond

/-- **Assurance grade is read by no guard (D2(iv) = C).** Two attestations differing only in level
    yield the same `verified` verdict. -/
theorem grade_is_not_a_gate (s : State) (d : DID) (a : Attestation) (lv : Assurance)
    (hin : a ∈ s.attest d) :
    (s.time < a.expires ∧ s.revoked a = false ∧ s.accredited a.issuer = true ∧ a.sigOK = true)
    ↔ (s.time < ({ a with level := lv } : Attestation).expires
        ∧ s.revoked a = false ∧ s.accredited a.issuer = true ∧ a.sigOK = true) := by
  exact Iff.rfl

end ROCKR
