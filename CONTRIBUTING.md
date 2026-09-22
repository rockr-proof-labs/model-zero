# Contributing to Model Zero

Thank you for reading this before proposing a change.

## How work is organised

1. **Briefs.** Every piece of work is done against a written brief with a definition of done.
2. **Strikes before proofs.** If a proof needs a definition to change, do not change it. Write a short *strike note*: what is wrong, why, the proposed replacement, and — where you can — a kernel-checked counterexample on the unchanged file. The chief architect (David Clancy) rules in writing. Only then is the definition changed, with the ruling cited in the file's header.
3. **Never edit the hypotheses.** H1–H4 are the trusted base and are published as such.
4. **Core only.** The file must build with Lean 4.21.0 and nothing else unless a ruling says otherwise.

## Pull requests

Every pull request includes:

- a **provenance note**: what was tried, what worked, what changed and on whose ruling, and whether AI assistance was used;
- the **toolchain version** used;
- the **`#print axioms` output for every theorem** in the file;
- a **Developer Certificate of Origin** sign-off (`Signed-off-by: Name <email>`) on each commit — see https://developercertificate.org.

Continuous integration runs `lean` on the file and fails on any error or any new `sorry`. A maintainer reads the definition changes against the rulings ledger before merging; the kernel judges the proofs, the maintainer judges the definitions.

## Licence

By contributing you agree that your contribution is licensed under the Apache License 2.0 and that you have the right to submit it, as certified by your DCO sign-off. Contributors are credited in `NOTICE`.

*Nothing has been awarded to this programme by any funder; nothing is payable by anyone unless it is.*
