# The Sift: Mod-Building Prompt

`SIFT_MOD_PROMPT.md` is a long-running build prompt for Claude. It produces a polished Minecraft: Java Edition mod that adds **The Sift**, the dimension Mojang announced at Minecraft LIVE in September 2026. The Sift debuts in Minecraft Dungeons II and comes to Java and Bedrock in 2027.

## How to use it

1. Create an **empty git repository** for the mod.
2. Open **Claude Code** in it. The prompt expects file access and a shell, and it needs to run Gradle and reach Maven and Fabric servers. JDK 25 is required for Minecraft 26.3; Claude will install or configure it in Phase 0 if your environment allows.
3. If you want, edit the **Project Config** block at the top of `SIFT_MOD_PROMPT.md` (mod id, autonomy mode, license).
4. Paste everything below the first horizontal rule of `SIFT_MOD_PROMPT.md` as your first message.

## Continuing across sessions

The project will span many sessions. Claude keeps all of its state in the mod repo's `docs/` folder, so any new session can pick up exactly where the last one stopped. To resume, send:

```
Continue building The Sift. Follow docs/00_MISSION.md exactly: run the session start protocol (§5.2), then continue the current work package in docs/STATUS.md.
```

## Answering gates

With `AUTONOMY: checkpoints`, Claude stops at three gates:

| Gate | When | What you'll get |
|---|---|---|
| A | After the vision phase | The vision, design pillars, entry path, and core systems |
| B | After the content bible | Every mob, block, biome, and boss, tiered, plus the roadmap |
| C | After the vertical slice | A playable jar and `docs/PLAYTEST.md` |

To answer a gate, reply with `go` to accept its recommendations, or give feedback to change them. Set `AUTONOMY: full-auto` if you never want it to stop.

## How the prompt balances "perfect" with "finished"

- **Unlimited care inside a task:** research, then generating many options, then converging, a full spec, and adversarial review with a fresh reviewer.
- **Every task is bounded:** a Definition of Done, an iteration budget, and an exit ramp.
- **Circuit breakers stop loops:**
  - a cap on critique rounds;
  - "same error three times means change approach";
  - a fix budget;
  - a diminishing-returns check;
  - a parking lot for new ideas.
- **Light context:** one work package at a time, memory kept in files, rolling-wave planning, and reading only the inputs a task lists.
- **Evidence-based completion:** nothing is checked off without a test, build output, or preview to point to.
