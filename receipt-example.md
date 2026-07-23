<!-- muninn:context-receipt:v1 -->

## Muninn Context Receipt (server-scored)

This is a context audit, not a code review. It is not a code-quality or security approval of the change.

### Decision needed before merge
Your context tells the agent to use one package manager while the repo's lockfile implies another (2 such collisions this run).

### Why it matters
The diff can pass CI and still install the wrong dependencies.

### Evidence
- context surface `path#194744c3d21031ca` conflicts with lockfile `path#5d2ae2d80560b2ae` (reason: `pkg_manager_mismatch`)
- context surface `path#944ee11b8cfa67c5` conflicts with lockfile `path#5d2ae2d80560b2ae` (reason: `pkg_manager_mismatch`)

### What was scored
- files scored: 5
- risk breakdown: clear=1, flagged=0, high_risk=4
- admission lane hints: Active=0, Canonical=0, Probation=0, Quarantine=0, Reject=5, Retired=0
- 2 policy collision(s) detected (context directive vs. lockfile)
- resource footprint: 1956 bytes, ~492 est. tokens

### High-risk pointers (need review)
- `path#194744c3d21031ca` (lane hint: `Reject`)
- `path#944ee11b8cfa67c5` (lane hint: `Reject`)
- `path#194744c3d21031ca` (lane hint: `Reject`)
- `path#944ee11b8cfa67c5` (lane hint: `Reject`)

### Flagged pointers (structural hygiene, not safety)
None this run.

### Policy collisions (package manager mismatch)
- context surface `path#194744c3d21031ca` conflicts with lockfile `path#5d2ae2d80560b2ae` (reason: `pkg_manager_mismatch`)
- context surface `path#944ee11b8cfa67c5` conflicts with lockfile `path#5d2ae2d80560b2ae` (reason: `pkg_manager_mismatch`)

### What Muninn refused to conclude
- **risk = high_risk**: secret/injection-shaped signal matched by SHAPE only, on the redacted bundle the server received. The server cannot tell a live credential or a real injection from a quoted example, so it draws no conclusion either way and never proposes an automated fix. A human must verify the match in context before acting.
- **policy_collision**: a structural fact (a directive pattern matched in a context surface against which lockfile is actually present), not a semantic read of intent. Muninn does not conclude which package manager the project should standardize on, only that the two disagree today; a human must decide which side is correct.
- **lane hints** reflect Muninn's real admission engine run over only the signals a redacted bundle can honestly carry (no provenance data crosses the wire); a `reject` hint here is that engine's own fail-safe default given today's bundle schema, not an assertion that the underlying memory is bad.

_Server-scored and signed: request `087615ce-ea95-4690-be5f-e9aa035f8c13`, key `cust_d328b1243f55f7f70a11ceda1222909a:v1`, at `2026-07-22T02:19:35.899Z`. This signature was verified by the client before this comment was posted. Findings are shown as stable pointers (`path#hash`), never raw filesystem paths, filenames, memory ids, or secret literals. Run `muninn doctor --first-look --unredacted` on your own machine for full local detail (never share that report)._

Muninn does not approve code. It shows the context risk your reviewer should decide.

