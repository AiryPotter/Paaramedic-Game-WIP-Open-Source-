# Cherry-Pick Checklist: Claude Code's Suggested Code

**Game:** Paramedic Simulator (Godot 4.7, Xogot on iPad, GDScript only)
**Checked against:** game code at `9ae595b` on `xogot-project-upload`
**Written by:** Claude Code, 2026-11-27. **None of this code has been run.** Test each piece on the iPad.

## How to use

1. Tick `[x]` the items you want, top to bottom. Items higher in each list matter more.
2. Check "Needs" so you also pick what an item depends on.
3. Paste this to ChatGPT 6 Luna, with the ticked item files attached or pasted after it:

> Apply only the items I ticked below, one at a time, in this order. Each item has its own file with exact code and a test. After each item, stop and tell me what to test on the iPad before you continue. Do not change anything else. Add a short line to `documentation/DEVELOPMENT_LOG.md` for each item.

4. After testing, tell Claude Code to review the new push.

Status key: **Open** = not in the game yet. **Test first** = only apply if the test in the file fails. **Starter** = new code for a planned feature. **Applied** = already in the game (archive only).

---

## A. Fixes for the current game

| Pick | ID | Fix | Priority | Needs | File |
|---|---|---|---|---|---|
| [ ] | S1 | Restore the deck's collision (it is ignored now) | Critical | — | `fixes/S1_deck_collision.md` |
| [ ] | S2 | Touch-only pad sensor (maintainer decision) | High | S1 | `fixes/S2_touch_only_pad.md` |
| [ ] | S3 | Controlled patient TRANSFER, no tossing (maintainer decision) | High | S1 | `fixes/S3_controlled_transfer.md` + `new_files/training_patient.gd` |
| [ ] | S6 | QA checks that catch inactive collision shapes | Medium | — | `fixes/S6_qa_collision_checks.md` |
| [ ] | S5 | Put reach back to 5.5 m (maintainer decision) | Medium | S1 | `fixes/S4_S5_S7_S8_small_fixes.md` |
| [ ] | S7 | Don't stick items during a height change | Low | — | `fixes/S4_S5_S7_S8_small_fixes.md` |
| [ ] | S4 | Lower only the deck, not the frame | Visual | — | `fixes/S4_S5_S7_S8_small_fixes.md` |
| [ ] | S8 | Turn off unused motion sensors; test gestures | Low | — | `fixes/S4_S5_S7_S8_small_fixes.md` |
| [ ] | R1-06 | Don't release items inside obstacles | High | — | `fixes/R1-06_safe_release.md` |
| [ ] | R1-05 | Walk to the stretcher instead of being yanked; let go if blocked | High | — | `fixes/R1-05_R1-10_R1-12_operator_follow.md` |
| [ ] | R1-12 | Gravity while operating the stretcher | Medium | — | `fixes/R1-05_R1-10_R1-12_operator_follow.md` |
| [ ] | R1-10 | Stick must re-center after grabbing or releasing | Medium | — | `fixes/R1-05_R1-10_R1-12_operator_follow.md` |
| [ ] | R1-07 | Buttons that work while the joystick is held | **Test first** | — | `fixes/R1-07_multitouch_buttons.md` |
| [ ] | N4 | Coasting follows the caster angle | Medium | — | `fixes/N4_N7_N10_stretcher_cleanup.md` |
| [ ] | N7 | Stop rewriting wheel colliders every tick | Low | — | `fixes/N4_N7_N10_stretcher_cleanup.md` |
| [ ] | N10 | Leftover state; don't shove the player on release | Low | — | `fixes/N4_N7_N10_stretcher_cleanup.md` |
| [ ] | R1-14 | UI scales with the iPad screen, safe-area margins | Medium | — | `fixes/R1-14_ui_scaling.md` |
| [ ] | R1-15 | Invisible walls and fall reset | Medium | — | `fixes/R1-15_R1-16_bounds_and_cleanup.md` + `new_files/world_bounds.gd` |
| [ ] | R1-16a | Choose the physics engine explicitly | Low | — | `fixes/R1-15_R1-16_bounds_and_cleanup.md` |
| [ ] | R1-16b | Name the collision layers | Low | — | same |
| [ ] | R1-16c | Typed calls instead of `.call("...")` | Low | — | same |
| [ ] | R1-16d | Remove dead `look_control_moves()` (ask first) | Low | — | same |
| [ ] | R1-16e | Caster legs and spinning wheels | Visual | — | same |
| [ ] | R1-16f | Fix the "rigid-body force" wording in the log | Low | — | same |
| [ ] | R2 | Ease items flat when they stick (check first) | Nit | — | `fixes/R2_ease_stick_snap.md` |

---

## B. Starters for planned features

New scripts for later milestones. They are a starting point to build on, not finished features.

| Pick | ID | Starter | Milestone | Needs | File |
|---|---|---|---|---|---|
| [ ] | F1 | `EventBus` autoload: shared signals | 10 | — | `starters/event_bus.gd` |
| [ ] | F2 | `GameState` autoload: timer, event log, saved results | 10, 17 | F1 | `starters/game_state.gd` |
| [ ] | F3 | `ScenarioData` resource: one call per `.tres` file | 10 | — | `starters/scenario_data.gd` |
| [ ] | F4 | Tracked stair chair, one paramedic | 11 | F1, F2 | `starters/stair_chair.gd` |
| [ ] | F5 | Ambulance joystick driving, siren, lights, parking brake, unsafe-transport checks | After demo | F1 | `starters/ambulance_controller.gd` |
| [ ] | F6 | Traffic that pulls aside for the siren | After demo | F5 | `starters/traffic_car.gd` |
| [ ] | F7 | Ambulance load zone: line up, PARK, LOAD, SECURE | 16 | F1, F5 | `starters/ambulance_load_zone.gd` |
| [ ] | F8 | Crash detector: hard impacts become crash events | After demo | F1 | `starters/crash_detector.gd` |

Setup for F1 and F2: Project Settings > Globals (Autoload). Add `event_bus.gd` as `EventBus`, then `game_state.gd` as `GameState` (that order). Each starter's top comment lists its scene setup.

Placeholders to replace: point values (`-5` for unsafe transport), backup ETAs, comfort and speed limits. Clinical content stays empty until the maintainer's protocols arrive and are reviewed.

---

## C. Already applied (archive, do not re-apply)

See `applied/ALREADY_APPLIED.md`: A1 to A10 are in the game. C1 (slow down in tight turns) is not needed at the current steering angle.

| ID | What | Status |
|---|---|---|
| A1 | One steering formula (review 1, item 3) | Applied |
| A2 | Locked-axis drive and side steering (review 1, item 4) | Applied |
| A3 | Wheel rules while coasting (review 1, item 11) | Applied |
| A4 | Stale touch index release (review 2, N6) | Applied |
| A5 | Facing from the chosen handle (review 2, N5) | Applied |
| A6 | KOLE cracks on hard impact (review 2, N11) | Applied |
| A7 | Stuck items predict the stretcher's pose (review 3, R1) | Applied |
| A8 | Sticky pad (feature plan) | Applied |
| A9 | Pad cushions KOLE (feature plan) | Applied |
| A10 | Both free: swing and slide (feature plan) | Applied |
| C1 | Slow down in tight turns (feature plan) | Not needed yet |

Fixes from review 1 that were applied without a code sketch: wheel colliders under the body (item 1), low friction (2), dead zone (8), touch takeover (13), PUSH and coast (11, review 2 N3), bumps and swing (review 2 N1, N2), camera transitions (review 1 item 9, review 2 N8), turn rate from real speed (N9), KOLE rename, 2.20 m stretcher.
