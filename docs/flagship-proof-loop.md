# Muninn Flagship Proof Loop

The canned, reproducible demo that shows Muninn catching a bad diff on a real PR:
a reviewer watches CI go green while Muninn's signed Context Receipt names a
pnpm-vs-npm `policy_collision` (the repo's context says one package manager, the
committed lockfile says another). This is the story for the website, Product
Hunt, and sales.

Status: the mechanic is live and proven. A live end-to-end demo PR ran on the
prod worker and posted the real signed receipt naming 2 collisions (captured
verbatim in `receipt-example.md`). Everything below reuses that same prod worker
(`https://muninn-edge.bronson-aber.workers.dev`) and the public pinned action
`bronsonaber/muninn-client@29d5e153…` (v0.1.1). Nothing here requires new server
code.

---

## 1. Demo scenario spec (the exact state)

**Premise:** a repo that has standardized on pnpm. An AI coding agent opens a PR
that adds npm's `package-lock.json`. The change is harmless-looking and passes
CI, but it contradicts the repo's own AI-facing policy. Muninn catches the
contradiction; a human reviewer decides.

### `main` (established baseline)
| File | Content (essence) |
| --- | --- |
| `CLAUDE.md` | "This project standardizes on pnpm… Always use `pnpm`. Never use `npm`. Do not add or update `package-lock.json`." |
| `AGENTS.md` | "Always use `pnpm`… Never use `npm install`… commit `pnpm-lock.yaml`." |
| `package.json` | trivial Node package, one dep (`left-pad`), passing `test` script |
| `src/index.js` | trivial greet() module |
| `.github/workflows/ci.yml` | ordinary CI: checkout + run test (goes **green**) |
| `.github/workflows/muninn.yml` | Muninn Context Receipt action, pinned to the v0.1.1 SHA |

Two context surfaces (`CLAUDE.md`, `AGENTS.md`) both assert pnpm. No npm lockfile
on `main` yet — the baseline is internally consistent.

### The PR (`demo/pnpm-npm-collision` → `main`)
The bad diff is a **single added file**: `package-lock.json` (npm's lockfile,
`lockfileVersion: 3`). Title: "Add package-lock.json for reproducible installs
(agent-authored)". That is the whole change. It reads as routine housekeeping.

### Why it fires
At the PR head the repo now contains both pnpm directives and an npm lockfile.
Muninn scores the repo's context surfaces against the lockfile actually present
and finds each pnpm directive contradicts it → two `pkg_manager_mismatch`
`policy_collision`s. The normal CI `test` job is green the whole time; Muninn's
check is a separate, non-blocking signal.

> Note on the proven run: the live end-to-end PR demonstrated the identical
> mechanic with the sides reversed — `main` already had the npm lockfile +
> `AGENTS.md` (pnpm), and the PR *added* the `CLAUDE.md` pnpm directive. Same
> 2-collision receipt. The spec above is the cleaner flagship framing (the PR
> introduces the offending lockfile), and it produces the same result because
> Muninn scores the repo state at the PR head, not just the diff.

### Expected receipt (verbatim shape, from the proven run)
```
## Muninn Context Receipt (server-scored)
This is a context audit, not a code review...

### Decision needed before merge
Your context tells the agent to use one package manager while the repo's
lockfile implies another (2 such collisions this run).

### Why it matters
The diff can pass CI and still install the wrong dependencies.

### Evidence
- context surface `path#…` conflicts with lockfile `path#…` (reason: `pkg_manager_mismatch`)
- context surface `path#…` conflicts with lockfile `path#…` (reason: `pkg_manager_mismatch`)

### What was scored
- files scored: 5
- 2 policy collision(s) detected (context directive vs. lockfile)
...

_Server-scored and signed: request `…`, key `cust_…:v1`, at `…Z`.
This signature was verified by the client before this comment was posted...._

Muninn does not approve code. It shows the context risk your reviewer should decide.
```
The full real receipt is saved alongside this file as `receipt-example.md`.

---

## 2. Runbook (reproduce in a few minutes)

**Location of assets:**
- Runbook + narrative: this file (`docs/flagship-proof-loop.md`)
- Recreate script: `recreate-demo.sh` (repo root)
- Real receipt sample: `receipt-example.md` (repo root)

**Prereqs:** `gh` (authenticated), `git`, `curl`; a scratch GitHub owner (not a
product org); the three customer signing values from the Muninn `/register` flow.

### One-time provisioning (per customer key)
Do this once; reuse the key across demo re-runs. You need three values from your
Muninn registration (see the `bronsonaber/muninn-client` `PROVISIONING.md`):
1. Generate a client keypair with the muninn-client CLI; keep the private-key PEM local.
2. Register the public key with Muninn to receive the server public key and your
   client key id (`cust_…:v1`).
3. You now hold: `MUNINN_SERVER_PUBKEY` (server pubkey), `MUNINN_CLIENT_KEY_ID`
   (`cust_…:v1`), and the private-key PEM file. Keep the PEM off disk after the demo.

### Run it (recreate state + open PR)
```bash
export MUNINN_DEMO_OWNER="<scratch-owner>"
export MUNINN_SERVER_PUBKEY="<server pubkey PEM>"
export MUNINN_CLIENT_KEY_ID="cust_xxxx:v1"
export MUNINN_CLIENT_PRIVATE_KEY_PEM_FILE="/secure/path/muninn_client_key.pem"

./recreate-demo.sh
```
The script: health-checks the live server; builds the `main` baseline; creates a
**private** throwaway repo; wires the two repo variables + the private-key
secret; opens the `demo/pnpm-npm-collision` PR that adds `package-lock.json`.
Within ~20-30s the Muninn check posts the signed receipt comment on the PR.

### Verify (don't trust — check the real thing)
```bash
gh run watch --repo <owner>/<repo> $(gh run list --repo <owner>/<repo> -L1 --json databaseId -q '.[0].databaseId')
gh pr view demo/pnpm-npm-collision --repo <owner>/<repo> --json comments \
  -q '.comments[].body' | grep -A2 "Decision needed before merge"
```
Success = a comment containing "2 such collisions this run" and a `Server-scored
and signed` footer whose signature the client verified before posting.

### Tear down
```bash
gh repo delete <owner>/<repo> --yes
```

### Guardrails baked in
- Repo is created **private** by default (`--private`); flip to `--public` only
  for a launch-day repo you intend to show.
- No key material lives in the script or repo files — secrets come from env/CI only.
- Action is pinned to the full v0.1.1 SHA (never `@main`/tag); the client's own
  `check_pinned_ref()` fails the job on a mutable ref.
- If signing material is omitted the PR still opens but the server declines to
  score (ephemeral unregistered key) — a documented, honest no-op, not a fake pass.

---

## 3. What the viewer sees (website / Product Hunt narrative)

Three beats, ~30 seconds:

**Beat 1 — Here's your context.**
The repo's `CLAUDE.md` / `AGENTS.md` say, in plain English, "Always use pnpm.
Never use npm." This is the repo's own standing instruction to every AI agent
that touches it.

**Beat 2 — Here's the diff that passes CI.**
An AI-authored PR adds one file: `package-lock.json`, titled "for reproducible
installs." It looks like routine hygiene. The CI check goes green. A busy
reviewer clicks approve.

**Beat 3 — Here's Muninn catching the contradiction.**
Muninn posts a signed Context Receipt on the PR:
> "Your context tells the agent to use one package manager while the repo's
> lockfile implies another (2 such collisions this run). The diff can pass CI and
> still install the wrong dependencies."
It names each colliding surface, shows the `pkg_manager_mismatch` reason, and
signs the finding (verified client-side before posting). Muninn doesn't block
the merge or pick a winner — it hands the reviewer the one fact CI missed.

**The line that travels:** *Green CI told you the code runs. Muninn told you it
runs against the wrong instructions.*

### Where to capture the recording / GIF
Record the PR page top-to-bottom in one scroll:
1. **Files changed** tab — the lone `package-lock.json` addition (frame the "looks harmless").
2. **Checks** row — CI `test` green (the "it passes" beat). Let the Muninn check resolve on camera.
3. **Conversation** tab — the Context Receipt comment appearing; zoom the
   "Decision needed before merge" block and the signed footer.
Best GIF crop: beats 2→3 (green check + receipt landing) is the money shot, ~8-12s.
Capture at 1280px+ width, light theme for contrast. Keep the customer `key_id`
and request UUID visible — the signature is part of the credibility, and both
are non-sensitive pointers, never raw paths or secrets.

---

## 4. Toward a one-click demo (later)

Today's flow is "few minutes, one script." To make it a one-click, on-demand
demo:

1. **Template repo.** Convert a canonical `muninn-flagship-template` repo (the
   `main` baseline above) into a GitHub **template**. "Use this template" gives
   a viewer their own copy with the pnpm policy + workflows already in place —
   no `git init`, no file authoring.
2. **GitHub App install (replaces per-repo key wiring).** The current friction
   is the three per-repo secrets/variables. A Muninn GitHub App that carries the
   signing identity at the app/installation level means a viewer installs the
   app once and every repo is scored — no keygen, no `/register`, no secret
   paste. This is the single biggest lever from "few minutes" to "one click."
3. **Prebuilt PR / button.** Ship the template with the `demo/pnpm-npm-collision`
   branch already pushed and a one-line "open the demo PR" action (a workflow
   dispatch or a `gh` alias), so the collision PR is one click after "use template."
4. **Hosted sandbox (optional, highest polish).** A "Try it" button on the
   marketing site that spins a viewer's throwaway repo via the App and opens the
   PR for them, so they watch the receipt land without leaving the page. This is
   post-launch; the template + App (items 1-2) already deliver a near-one-click
   demo for sales and PH.

Sequencing: template repo (hours) → GitHub App install (the real work) →
prebuilt PR button → hosted sandbox. Items 1-3 are enough for the flagship
launch; item 4 is a later delighter.
