# Paramedic Simulator — Game Design

## Vision

A touch-first, single-player paramedic training demo for iPad. The player completes one fictional response from dispatch through hospital handover, learning to communicate, assess, coordinate help, handle equipment, and move a patient safely. The tone is calm and supportive; mistakes should produce clear feedback rather than an arbitrary fail state.

## Target demo

A complete, replayable call should include:

1. **Dispatch and arrival:** a short brief, a clear objective, and an explorable scene.
2. **Scene safety:** recognize hazards and decide whether it is safe to approach.
3. **Patient encounter:** communicate and gather findings through explicit interactions.
4. **Care and backup:** use only scenario steps that come from the maintainer's service protocols and have been checked by a qualified paramedic or instructor. Backup acts on its own after arriving.
5. **Extrication:** move the patient with a stair chair on stairs, then the 1.0 m stretcher through a compact, readable obstacle course. Build doors and halls to fit the stretcher.
6. **Loading and handover:** load the stretcher into a parked ambulance, transition to a hospital bay, and give a structured **MIST** verbal report. Driving is outside the first demo's scope.
7. **Debrief:** show an explained score, what went well, what was missed, and a concise event timeline. Unneeded backup gets a debrief note but no point penalty.

## Design pillars

- **Readable touch controls:** large contextual buttons, no keyboard requirement, and no need for several simultaneous button presses.
- **Patient-first interaction:** the patient is a person to communicate with, not just a moving objective.
- **Consequences with coaching:** unsafe handling and missed steps should create understandable feedback and a chance to learn.
- **Physical handling matters:** bags, the KOLE defibrillator, and the stretcher should retain their existing physical feel across scenarios.
- **Clinically grounded content:** do not invent a protocol, diagnosis, vital-sign response, or treatment rule. Use the maintainer's service protocols and obtain qualified clinical review before presenting a scenario as training.
- **Small, testable increments:** preserve the working touch loop and test each physics or UI change on the target iPad when possible.

## Current prototype

The project already has touch movement/look, pickup and toss interactions, two paramedic bags, KOLE, and a 2.20 m stretcher with caster locks and a full-deck sticky pad. The current training patient is a non-graphic interaction and loading placeholder. It contains no symptoms, vital signs, diagnosis, or treatment rules. The stretcher can lower its deck, accept the patient when aligned, then raise for transport. The PUSH button and recent physics/input reliability changes still need device testing.

## Roadmap

### Milestone 9 — Core reliability and first patient interaction

Current prototype work: recover stale touch IDs, keep stuck equipment aligned with the stretcher, preserve impacts under caster constraints, add a deliberate PUSH action, and establish a patient interaction placeholder. Validate these behaviors on iPad before relying on them in later scenarios.

### Milestone 10 — Game structure

Add a simple main menu, pause/restart flow, and settings. Introduce a small `GameState`/event log and a scenario resource that names the location, objectives, patient case, hazards, and scoring criteria. Keep the state machine and event flow custom and small until the demo needs more; do not add third-party code without explicit approval and license review.

### Milestone 11 — Stretcher obstacle course

Build one two-level house blockout with an upstairs room, stairs, living room, hallway, exit, and driveway. The paramedic works alone (maintainer decision), so stairs use a tracked stair chair that one person guides down; then transfer to the stretcher at the bottom. Keep doors and corridors generous enough for the 1.0 m stretcher; create challenge with corners, clutter, rugs, thresholds, and furniture rather than unfairly narrow openings. Track hard stretcher impacts and time to exit.

### Milestone 12 — People and transfer

Add a patient character and any needed bystanders. There is no partner medic: the paramedic works alone on every call, and backup arrives only when called (maintainer decision). Build controlled floor-to-stair-chair and floor-to-stretcher transfers, plus a secured patient state that follows the carrying device. Test patient mass and balance separately before combining them with the main scene. Add navigation only for NPC behavior needed in the demo.

### Milestone 13 — Dialogue and history

Add patient and bystander dialogue driven by each scenario resource. The maintainer supplies approved questions and answers; each asked question is recorded for debrief. Use a short, touch-friendly conversation UI rather than a large dialogue framework unless the content grows enough to justify one.

### Milestone 14 — Assessment and patient state

Build assessment interactions, a compact findings display, and a scenario-driven patient-state model. Source all values and responses from the maintainer's service protocols and obtain qualified clinical review before student testing. The protocol documents are still needed. Do not make the prototype's placeholder interaction look like medical instruction.

### Milestone 15 — Backup and radio

Add an in-game radio request and clear arrival feedback. Scenario-defined backup can include ACP, CCP, police for violent scenes, and online medical control by radio/phone. Backup acts on its own after arrival; the doctor gives a time of death by phone/radio when the approved scenario requires it. Unneeded backup costs no points but is mentioned in the debrief. Exact timing, actions, and clinical logic come from approved scenario data.

### Milestone 16 — Ambulance loading and hospital handover

Add a parked ambulance, an alignment-checked LOAD action, and a short loading animation. Fade to a simple hospital bay and let the player wheel the patient to a bed. Use **MIST** for the touch-friendly verbal handover: Mechanism/Medical complaint, Injuries/Illness, Signs, Treatment. Score accuracy against the scenario and event log. Driving remains deferred.

### Milestone 17 — Scenario, scoring, and debrief

Build one complete scenario from approved content. Score the event log for scene safety, assessment, appropriate actions and timing, backup requests, stretcher handling, and handover. Explain each score with a short reason and save results locally. Since students share the maintainer's iPad, ask for a student name or ID before each call and provide a results history for the instructor.

### Milestone 18 — Polish and demo build

Add licensed/CC0 audio and visuals, a short control tutorial, subtitles and adjustable text size, and performance testing on the target iPad. Complete third-party notices before adding borrowed assets or code. Playtest with a small number of students. The first demo runs on the maintainer's iPad in Xogot; make it launch cleanly to a main menu and hide debug tools. TestFlight distribution can come later.

## Dependency order

Core reliability precedes game structure; the obstacle course and assessment can develop in parallel after structure. People and dialogue/assessment enable backup, handover, and scoring. Do not author real clinical content until the maintainer supplies service protocols and a qualified reviewer checks them.
