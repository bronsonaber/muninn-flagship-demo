# Muninn Flagship Demo — watch Muninn catch poisoned context before merge

**Green CI told you the code runs. Muninn told you it runs against the wrong instructions.**

This is a small, reproducible repo that demonstrates one thing: an AI-authored
pull request that **passes CI** while quietly **contradicting the repo's own
instructions to AI agents** — and Muninn catching it with a signed **Context
Receipt** before a human merges.

---

## The story (30 seconds)

1. **Here's your context.** This repo has standardized on **pnpm**. Its
   `CLAUDE.md` and `AGENTS.md` say, in plain English: *"Always use pnpm. Never
   use npm."* That is the repo's standing instruction to every AI agent that
   touches it.

2. **Here's the diff that passes CI.** An AI coding agent opens a PR that adds a
   single file — npm's `package-lock.json` — titled *"for reproducible
   installs."* It looks like routine hygiene. CI goes **green**. A busy reviewer
   clicks approve.

3. **Here's Muninn catching the contradiction.** Muninn posts a signed Context
   Receipt on the PR:

   > Your context tells the agent to use one package manager while the repo's
   > lockfile implies another (2 such collisions this run). The diff can pass CI
   > and still install the wrong dependencies.

   It names each colliding surface, shows the `pkg_manager_mismatch` reason, and
   signs the finding (verified client-side before it is posted). Muninn does not
   block the merge or pick a winner — it hands the reviewer the one fact CI missed.

The real, signed, client-verified receipt from a live run is in
[`receipt-example.md`](./receipt-example.md).

---

## What's in here

| Path | What it is |
| --- | --- |
| `README.md` | This story + how to run it. |
| `CLAUDE.md`, `AGENTS.md` | The repo's pnpm policy — the context Muninn scores against. |
| `package.json`, `src/index.js` | A trivial Node package (one dep, passing test). |
| `.github/workflows/ci.yml` | Ordinary CI that goes green. |
| `.github/workflows/muninn.yml` | The Muninn Context Receipt action, pinned to the v0.1.1 SHA. |
| `recreate-demo.sh` | One script that stands the whole demo up on a throwaway repo and opens the collision PR. |
| `receipt-example.md` | The actual signed receipt from a live run. |
| `docs/flagship-proof-loop.md` | Full runbook, scenario spec, and launch narrative. |
| `_pr-branch/package-lock.json` | The single file the demo PR adds (kept out of `main` so the baseline stays consistent). |

The files at the repo root are the clean `main` baseline: a pnpm-standardized
repo with **no npm lockfile**. The collision is introduced by the demo PR, which
adds the one `package-lock.json` in `_pr-branch/`.

---

## Run it yourself

Prereqs: `gh` (authenticated), `git`, `curl`; a scratch GitHub owner (not a
product org); and the three customer signing values from the Muninn `/register`
flow (see `bronsonaber/muninn-client` `PROVISIONING.md`).

```bash
export MUNINN_DEMO_OWNER="<scratch-owner>"
export MUNINN_SERVER_PUBKEY="<server pubkey PEM>"
export MUNINN_CLIENT_KEY_ID="cust_xxxx:v1"
export MUNINN_CLIENT_PRIVATE_KEY_PEM_FILE="/secure/path/muninn_client_key.pem"

./recreate-demo.sh
```

The script health-checks the live scoring server, builds the `main` baseline,
creates a **private** throwaway repo, wires the signing material, and opens the
`demo/pnpm-npm-collision` PR. Within ~20-30s the Muninn check posts the signed
receipt on the PR.

If you omit the signing material, the repo still builds and the PR still opens,
but the server declines to score (ephemeral unregistered key). That is an honest,
documented no-op — never a faked pass.

Full runbook, verify steps, and teardown: [`docs/flagship-proof-loop.md`](./docs/flagship-proof-loop.md).

---

## How the receipt is trustworthy

- **Server-scored and signed.** The receipt is scored by the Muninn edge worker
  and cryptographically signed; the client **verifies the signature before**
  posting the comment.
- **Pointers, not paths.** Findings are shown as stable pointers (`path#hash`),
  never raw filesystem paths, filenames, or secret literals.
- **It refuses to overreach.** Muninn reports that the two package-manager
  directives disagree — it does **not** decide which one is correct. A human
  makes that call.

*Muninn does not approve code. It shows the context risk your reviewer should decide.*
