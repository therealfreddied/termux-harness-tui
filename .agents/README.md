# `.agents/` — memory bank schema

Lightweight project memory for opencode sessions (`/boot` reads this).

| File | Purpose |
|---|---|
| `README.md` | this file — schema + rules |
| `memory.md` | persistent knowledge: what was DONE, decisions, environment gotchas. Append-only; never delete history. |
| `state.md` | live status: current goal, progress, blockers, NEXT actions. Rewrite freely each session. |

Maintenance rules:
- At session end: update `state.md`, append new facts/decisions to `memory.md`.
- `memory.md` entries are dated. Newest at top.
- Authoritative sources of truth stay in `notes/` (PLAN, WORKLOG,
  VPS-BUILD-HANDOFF); `.agents/` summarizes and points at them.
- This project lives on `/storage/emulated/0` (sdcard/FUSE): no file locks,
  no exec bits — do not rely on chmod +x; run scripts via `bash <file>`.
