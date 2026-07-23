# _pr-branch (not part of `main`)

This folder holds the single file that the demo PR adds on top of the `main`
baseline. It is staged separately so the baseline tree above stays the clean,
internally-consistent `main` state.

The demo PR (`demo/pnpm-npm-collision` -> `main`) is exactly one added file:

- `package-lock.json` -> copy to the repo root on the PR branch.

That lone addition is what makes the repo contradict itself at the PR head:
`CLAUDE.md` and `AGENTS.md` both say "use pnpm, never npm", but an npm
`package-lock.json` is now present. Muninn scores the repo state at the PR head
and names the two `pkg_manager_mismatch` collisions.
