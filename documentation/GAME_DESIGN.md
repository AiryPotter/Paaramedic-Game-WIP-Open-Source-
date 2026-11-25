# Paramedic Simulator — Game Design

## Vision

A touch-first, single-player paramedic training demo for iPad. The player completes one fictional response from dispatch through hospital handover, learning to communicate, assess, coordinate help, handle equipment, and move a patient safely. The tone is calm and supportive; mistakes should produce clear feedback rather than an arbitrary fail state.

## Target demo

A complete, replayable call should include:

1. **Dispatch and arrival:** a short brief, a clear objective, and an explorable scene.
2. **Scene safety:** recognize hazards and decide whether it is safe to approach.
3. **Patient encounter:** communicate and gather findings through explicit interactions.
4. **Care and backup:** use only scenario steps that come from the maintainer's protocols and have been checked by a qualified clinician. Backup responders should have understandable roles and act after arrival.
5. **Extrication:** move the patient with the stretcher through a compact, readable obstacle course.
6. **Loading and handover:** load the stretcher into a parked ambulance, transition to a hospital bay, and give a structured verbal report. Driving is outside the first demo's scope.
7. **Debrief:** show an explained score, what went well, what was missed, and a concise event timeline.

## Design pillars

- **Readable touch controls:** large contextual buttons, no keyboard requirement, and no need for several simultaneous button presses.
- **Patient-first interaction:** the patient is a person to communicate with, not just a moving objective.
- **Consequences with coaching:** unsafe handling and missed steps should create understandable feedback and a chance to learn.
- **Physical handling matters:** bags, the KOLE defibrillator, and the stretcher should retain their existing physical feel across scenarios.
- **Clinically grounded content:** do not invent a protocol, diagnosis, vitals response, or treatment rule. Use content supplied by the maintainer and obtain qualified clinical review before presenting a scenario as training.
- **Small, testable increments:** preserve the working touch loop and test each physics or UI change on the target iPad when possible.

## Current prototype

The project already has touch movement/look, pickup and toss interactions, two paramedic bags, KOLE, and a 2.20 m stretcher with caster locks and a full-deck sticky pad. The current training patient is only a non-graphic interaction placeholder. It contains no symptoms, vital signs, diagnosis, or treatment rules. The PUSH button and recent physics/input reliability changes still need device testing.

## Roadmap

### Milestone 9 — Core reliability and first patient interaction

Current prototype work: recover stale touch IDs, keep stuck equipment aligned with the stretcher, preserve impacts under caster constraints, add a deliberate PUSH action, and establish a patient interaction placeholder. Validate these behaviors on iPad before relying on them in later scenarios.

### Milestone 10 — Game structure

Add a simple main menu, pause/restart flow, and settings. Introduce a small `GameState`/event log and a scenario resource that names the location, objectives, patient case, hazards, and scoring criteria. Keep the state machine and event flow custom and small until the demo needs more; do not add third-party code without explicit approval and license review.

### Milestone 11 — Stretcher obstacle course

Build one house blockout with a living room, hallway, exit, and driveway. Keep doors and corridors generous enough for the 1.0 m stretcher; create challenge with corners, clutter, rugs, thresholds, and furniture rather than unfairly narrow openings. Track hard stretcher impacts and time to exit. Whether the first demo includes stairs, a ramp, or a carry-down action is an open decision.

### Milestone 12 — People and transfer

Add a patient character, a small partner role, and any needed bystanders. Build a controlled floor-to-stretcher transfer and a secured patient state that follows the stretcher. Test patient mass and balance separately before combining them with the main scene. Add navigation only for NPC behavior that is needed in the demo.

### Milestone 13 — Dialogue and history

Add patient and bystander dialogue driven by each scenario resource. The maintainer supplies approved questions and answers; each asked question is recorded for debrief. Use a short, touch-friendly conversation UI rather than a large dialogue framework unless the content grows enough to justify one.

### Milestone 14 — Assessment and patient state

Build assessment interactions, a compact findings display, and a scenario-driven patient-state model. Source all values and responses from the maintainer's local protocols and obtain qualified clinical review before student testing. Do not make the prototype's placeholder interaction look like medical instruction.

### Milestone 15 — Backup and radio

Add an in-game radio request and clear arrival feedback. Candidate roles in the current planning notes are advanced/critical care, police for an unsafe scene, and online medical control by radio/phone. Exact availability, timing, actions, and scoring depend on scenario and maintainer approval. Backup should be understandable and not silently take control away from the student.

### Milestone 16 — Ambulance loading and handover

Add a parked ambulance, an alignment-checked LOAD action, and a short loading animation. Fade to a simple hospital bay and let the player wheel the patient to a bed. Add a touch-friendly verbal handover using the format selected by the maintainer. Driving is deferred beyond the first demo.

### Milestone 17 — Scenario, scoring, and debrief

Build one complete scenario from approved content. Score the event log for safety, assessment, appropriate actions and timing, backup requests, stretcher handling, and handover. Explain each score with a short reason, and save results locally only if the instructor workflow requires it.

### Milestone 18 — Polish and demo build

Add licensed/CC0 audio and visuals, a short control tutorial, subtitle and text-size options, and performance testing on the oldest target iPad. Complete third-party notices before adding borrowed assets or code. Playtest with a small number of students and address the biggest usability issues.

## Open decisions for later milestones

- Stairs in the demo: omit them, provide a ramp, or add a partner-assisted carry action?
- Does requesting backup that the scenario does not need affect the score?
- Which local protocols and handover format should drive the first full scenario, and who will clinically review them?
- How will students receive the demo: play on the maintainer's iPad or install it on other iPads?

These decisions do not block the current non-clinical prototype. Ask before implementing any of them or authoring real clinical content.
