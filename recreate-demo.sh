#!/usr/bin/env bash
# ============================================================================
# Muninn Flagship Proof Loop — demo state recreator
#
# Creates a THROWAWAY repo that reproducibly triggers Muninn's pnpm-vs-npm
# policy_collision catch on a real PR, using the LIVE prod worker and the
# public muninn-client action. Run it, watch CI post the signed Context
# Receipt on the PR in ~30s.
#
# This script does NOT touch any existing public repo. It creates a brand-new
# repo under the account/org you name, PRIVATE by default.
#
# SECRETS: this script never contains a key. You supply the customer signing
# material out-of-band via env vars (see REQUIRED CONFIG). If you omit them,
# the repo is still created and the PR still opens, but the action will use an
# ephemeral unregistered key and the server will (correctly) decline to score
# — so provide the three values for the full "watch it catch it" demo.
# ============================================================================
set -euo pipefail

# ---------- REQUIRED CONFIG (edit or pass as env) ----------------------------
# Where to create the throwaway repo. Use a scratch owner, not a product org.
OWNER="${MUNINN_DEMO_OWNER:-<your-github-username-or-org>}"
REPO="${MUNINN_DEMO_REPO:-muninn-flagship-demo-$(date +%m%d%H%M)}"
VISIBILITY="${MUNINN_DEMO_VISIBILITY:---private}"   # --private (default) or --public

# Live Muninn scoring server (prod worker). Override only for staging.
SERVER_URL="${MUNINN_SERVER_URL:-https://muninn-edge.bronson-aber.workers.dev}"

# Pinned muninn-client action ref (full 40-char SHA). v0.1.1 as proven on PR #2.
CLIENT_SHA="${MUNINN_CLIENT_SHA:-29d5e153e6cd9296fa5adcebd985f2a3ea15bf63}"

# Customer signing material — placeholders. Set these in your shell before
# running for a scored receipt. Do NOT paste real keys into this file.
#   MUNINN_SERVER_PUBKEY   -> repo VARIABLE (server's public key PEM)
#   MUNINN_CLIENT_KEY_ID   -> repo VARIABLE (e.g. cust_xxxx:v1)
#   MUNINN_CLIENT_PRIVATE_KEY_PEM_FILE -> path to your local client private-key PEM
SRV_PUBKEY="${MUNINN_SERVER_PUBKEY:-}"
CLIENT_KEY_ID="${MUNINN_CLIENT_KEY_ID:-}"
PRIV_KEY_FILE="${MUNINN_CLIENT_PRIVATE_KEY_PEM_FILE:-}"
# ----------------------------------------------------------------------------

echo ">> Muninn flagship demo :: owner=$OWNER repo=$REPO visibility=$VISIBILITY"
command -v gh >/dev/null || { echo "!! gh CLI required"; exit 1; }
command -v git >/dev/null || { echo "!! git required"; exit 1; }
[ "$OWNER" = "<your-github-username-or-org>" ] && { echo "!! set MUNINN_DEMO_OWNER first"; exit 1; }

# 0) Quick health check of the live scoring server (fail fast, honestly).
echo ">> checking scoring server is live: $SERVER_URL"
if ! curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$SERVER_URL" | grep -qE '^[2-4]'; then
  echo "!! server did not respond; aborting so we don't stage a broken demo"; exit 1
fi

WORK="$(mktemp -d)/$REPO"
mkdir -p "$WORK"/{src,.github/workflows}
cd "$WORK"

# 1) The established repo policy: pnpm, never npm (two context surfaces).
cat > CLAUDE.md <<'EOF'
# Project instructions for AI coding agents

This project standardizes on pnpm for all dependency management.

- Always use `pnpm` to install dependencies. Never use `npm`.
- Run `pnpm install` and commit the resulting `pnpm-lock.yaml`.
- Do not add or update `package-lock.json`; this repo does not use npm.
EOF

cat > AGENTS.md <<'EOF'
# Instructions for AI coding agents

1. Always use `pnpm` to install dependencies. Never use `npm install` or
   `yarn install` in this project. Run `pnpm install` and commit the
   resulting `pnpm-lock.yaml`.
2. Keep source files under `src/`.
3. Keep changes small and focused; one concern per commit.
EOF

cat > package.json <<'EOF'
{
  "name": "muninn-flagship-demo",
  "version": "1.0.0",
  "description": "Throwaway repo demonstrating a Muninn pnpm-vs-npm context collision catch.",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "test": "node -e \"require('./src/index.js'); console.log('ok')\""
  },
  "license": "UNLICENSED",
  "dependencies": { "left-pad": "1.3.0" }
}
EOF

cat > src/index.js <<'EOF'
const leftPad = require("left-pad");
function greet(name) { return `Hello, ${leftPad(name, 12)}!`; }
if (require.main === module) console.log(greet("Muninn"));
module.exports = { greet };
EOF

cat > README.md <<'EOF'
# muninn-flagship-demo

Throwaway repo that reproduces Muninn's pnpm-vs-npm context collision catch.
Repo policy (CLAUDE.md / AGENTS.md) standardizes on pnpm. The demo PR adds
npm's `package-lock.json` — a diff that passes CI while contradicting the
repo's own stated package manager. Muninn's Context Receipt names it.
EOF

# 2) A normal CI check that PASSES (the "it passes CI" beat), plus Muninn.
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on: pull_request
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: node src/index.js && npm test --silent || true
EOF

cat > .github/workflows/muninn.yml <<EOF
name: Muninn Context Receipt
on: pull_request
permissions:
  pull-requests: write
  contents: read
jobs:
  context-receipt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: bronsonaber/muninn-client@${CLIENT_SHA}  # pinned: v0.1.1
        with:
          server-url: '${SERVER_URL}'
          server-pubkey: \${{ vars.MUNINN_SERVER_PUBKEY }}
          client-key-id: \${{ vars.MUNINN_CLIENT_KEY_ID }}
          client-private-key: \${{ secrets.MUNINN_CLIENT_PRIVATE_KEY_PEM }}
EOF

# 3) Seed main (clean baseline: pnpm policy, no npm lockfile yet).
git init -q -b main
git add -A
git -c user.name='Muninn Demo' -c user.email='demo@example.com' commit -qm "seed: pnpm-standardized repo + Muninn workflow"

# 4) Create the throwaway GitHub repo and push main.
echo ">> creating GitHub repo $OWNER/$REPO ($VISIBILITY)"
gh repo create "$OWNER/$REPO" $VISIBILITY --source=. --remote=origin --push

# 5) Wire signing material (vars + secret) if supplied; else warn.
if [ -n "$SRV_PUBKEY" ] && [ -n "$CLIENT_KEY_ID" ] && [ -n "$PRIV_KEY_FILE" ] && [ -f "$PRIV_KEY_FILE" ]; then
  echo ">> setting repo variables + private-key secret"
  gh variable set MUNINN_SERVER_PUBKEY --repo "$OWNER/$REPO" --body "$SRV_PUBKEY"
  gh variable set MUNINN_CLIENT_KEY_ID --repo "$OWNER/$REPO" --body "$CLIENT_KEY_ID"
  gh secret   set MUNINN_CLIENT_PRIVATE_KEY_PEM --repo "$OWNER/$REPO" < "$PRIV_KEY_FILE"
else
  echo "!! signing material not fully supplied — PR will open but receipt will NOT be scored."
  echo "!! set MUNINN_SERVER_PUBKEY, MUNINN_CLIENT_KEY_ID, MUNINN_CLIENT_PRIVATE_KEY_PEM_FILE and re-run,"
  echo "!! or add them under repo Settings -> Secrets and variables -> Actions, then push the PR branch."
fi

# 6) The bad diff: agent-authored PR adds npm's lockfile (contradicts pnpm policy).
git switch -c demo/pnpm-npm-collision
cat > package-lock.json <<'EOF'
{
  "name": "muninn-flagship-demo",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "muninn-flagship-demo",
      "version": "1.0.0",
      "license": "UNLICENSED",
      "dependencies": { "left-pad": "1.3.0" }
    },
    "node_modules/left-pad": {
      "version": "1.3.0",
      "resolved": "https://registry.npmjs.org/left-pad/-/left-pad-1.3.0.tgz",
      "integrity": "sha512-XI5MPzVNApjAyhQzphX8BkmKsKUxD4LdyK24iZeQGinBN9yTQT3bFlCBy/aVx2HrNcqQGsdot8ghrjyrvMCoEA==",
      "license": "WTFPL"
    }
  }
}
EOF
git add package-lock.json
git -c user.name='AI Coding Agent' -c user.email='agent@example.com' \
  commit -qm "chore: add package-lock.json (npm) for reproducible installs"
git push -u origin demo/pnpm-npm-collision

gh pr create --repo "$OWNER/$REPO" \
  --base main --head demo/pnpm-npm-collision \
  --title "Add package-lock.json for reproducible installs (agent-authored)" \
  --body $'This PR, opened by an AI coding agent, adds a committed **package-lock.json** (npm\'s lockfile) so installs are reproducible.\n\nNote: the repo\'s CLAUDE.md and AGENTS.md standardize on **pnpm** ("Always use pnpm. Never use npm."). This lockfile therefore contradicts the repo\'s stated package manager. CI (test job) passes regardless.'

PR_URL="$(gh pr view demo/pnpm-npm-collision --repo "$OWNER/$REPO" --json url -q .url)"
echo ">> PR opened: $PR_URL"
echo ">> watch the checks; the Muninn Context Receipt comment posts in ~20-30s."
echo ">> gh run watch --repo $OWNER/$REPO \$(gh run list --repo $OWNER/$REPO -L1 --json databaseId -q '.[0].databaseId')"
echo ">> DONE. To tear down: gh repo delete $OWNER/$REPO --yes"
