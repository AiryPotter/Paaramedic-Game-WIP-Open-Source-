# Milestone Plan: Playable Training Demo

**For:** ChatGPT 6 Luna
**Written by:** Claude Code
**Date:** 2026-11-25
**Starts after:** Milestone 8 in `documentation/DEVELOPMENT_LOG.md` (game code at `d9dd5ae`)
**Read with:** `2026-11-25-open-source-borrowing.md`, `2026-11-25-code-review-3.md`

## Ground rules

- Suggestions only. No project code was changed.
- Get the maintainer's approval before starting each milestone, and before adding any outside code.
- Plain GDScript only. Assume Xogot cannot run C# or GDExtension add-ons until tested. See `2026-11-25-open-source-borrowing.md` for license rules and the copy checklist.
- Every add-on below was checked on 2026-11-25. It is MIT-licensed GDScript unless noted. None have been tested in Xogot.
- **All medical content follows the maintainer's service protocols,** which the maintainer will provide. A qualified paramedic or instructor reviews it. Until the protocols arrive, do not invent clinical values: use placeholders marked `# PROTOCOL TODO`.

## Goal

**One complete call that a student can play from start to finish on iPad, single player, with scoring.**

The call: dispatch, arrive, make the scene safe, assess and treat, call backup if needed, move the patient past obstacles on the stretcher, load the ambulance, and give a handover at the hospital. Then show a score and feedback.

## Maintainer decisions (2026-11-25)

| Topic | Decision |
|---|---|
| End point | Playable training demo |
| Device | iPad only |
| Players | Single player |
| Priorities | Stretcher obstacles, backup calls, patient assessment, scenarios and scoring, ambulance and loading, characters and dialogue |
| Backup to call | Advanced Care Paramedic (ACP), Critical Care Paramedic (CCP), doctor for time of death, police for violent scenes |
| Doctor | Pronounces death **by radio or phone** (online medical control), not on scene |
| Backup behavior | Backup **acts on its own** after arriving |
| Stretcher width | **Keep 1.0 m.** Build doors and halls larger than real life to fit. |
| After loading | **Hospital handover:** fade to the hospital, wheel the patient in, give a verbal report |
| Stairs | **Stair chair:** move the patient down stairs in a stair chair, then transfer to the stretcher |
| Unneeded backup | **Debrief note only.** No points lost. |
| How students play | **On the maintainer's iPad in Xogot.** No Mac or TestFlight for the first demo. |
| Handover format | **MIST** (Mechanism or Medical complaint, Injuries or Illness, Signs, Treatment) |
| Medical content | **Maintainer's service protocols,** reviewed by a qualified paramedic or instructor |

## Common game features and what to borrow

| Feature | Use | Build ourselves? |
|---|---|---|
| Touch movement | [Virtual Joystick](https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot) | No |
| Camera transitions (review 2 N8) | [Phantom Camera](https://github.com/ramokz/phantom-camera) (about 3,700 stars) | No |
| Menus, pause, settings, loading screen | [Maaack's Godot Game Template](https://github.com/Maaack/Godot-Game-Template) | No |
| Game flow, patient condition, NPC behavior (state machines) | [Godot State Charts](https://github.com/derkork/godot-statecharts) (about 1,600 stars) | No |
| NPC decisions (optional, if state charts get crowded) | [Beehave](https://github.com/bitbrain/beehave) behavior trees (about 3,300 stars). Do **not** use LimboAI: it is C++. | No |
| NPC walking and pathfinding | Built-in `NavigationRegion3D` and `NavigationAgent3D`. Example: `3d/navigation` in [Godot demos](https://github.com/godotengine/godot-demo-projects) | Small glue only |
| Dialogue and history taking | [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) (about 4,000 stars). Skip its optional C# part. | No |
| Objectives and checklist | [Quest System](https://github.com/shomykohai/quest-system) (about 480 stars), or a small custom list | Maybe |
| Level blockout (rooms, halls, stairs) | Built-in CSG nodes. [Cyclops Level Builder](https://github.com/blackears/cyclopsLevelBuilder) is an editor plugin; test whether it works in Xogot. | No |
| Clutter and furniture placement | [Scatter](https://github.com/HungryProton/scatter) (about 3,000 stars) | No |
| Ambulance model | [Kenney Car Kit](https://kenney.nl/assets/car-kit) (CC0, includes an ambulance) | No |
| Furniture, props, UI art | [Kenney assets](https://kenney.nl/assets) (CC0) | No |
| People and animations | [Quaternius Universal Animation Library](https://quaternius.com/packs/universalanimationlibrary.html) (CC0, has push, sit, crawl, death and more on one humanoid rig) | No |
| Stair chair | Custom: a carried item with a sitting patient, using the Quaternius sit animation | **Yes** |
| Patient ragdoll (optional) | `3d/ragdoll_physics` in Godot demos | Small glue only |
| Patient vitals and condition | Custom. Reference: [Infirmary Integrated](https://github.com/tanjera/infirmary-integrated) (Apache-2.0, C#, read only) | **Yes** |
| Monitor screen (ECG line, numbers) | Custom `Line2D` drawing. Use Infirmary Integrated as a reference for rhythm shapes. | **Yes** |
| Backup calls and arrivals | Custom, built on state charts and navigation | **Yes** |
| Scoring and feedback report | Custom | **Yes** |
| Saving settings and results | Built-in `ConfigFile` and `FileAccess` (JSON). No add-on needed. | Small |
| Debug console on iPad | [PankuConsole](https://github.com/Ark2000/PankuConsole) | No |
| Automated tests (optional) | [GUT](https://github.com/bitwes/Gut) (MIT) or [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (MIT). Check that they run in Xogot. | No |
| Sound | Kenney audio packs (CC0). Freesound only for CC0 sounds. | No |

**Must be built for this game:** patient model, assessment, treatments, backup logic, scoring and handover. These are the parts that make it a paramedic trainer, and nothing open source fits them. Everything else should be borrowed.

## Milestones

Each milestone ends with an iPad test in Xogot and a development log entry. Keep one borrowed add-on per commit.

### Milestone 9: Fix the core

Make what exists reliable before adding features.

- Replace the touch joystick with Virtual Joystick (review 2 N6).
- Stop stuck items trailing the stretcher (review 3 R1).
- Stop the wheel rules from erasing bumps (review 2 N1), and use actual speed for turning (N9).
- Fix camera transitions with Phantom Camera (review 2 N8).
- Add PankuConsole for on-device debugging. Remove or hide it for the demo build.

**Done when:** a 5-minute session on iPad has no stuck controls, and the stretcher behaves as in the earlier test checklists.

### Milestone 10: Game structure

- Add Maaack's template: main menu, pause, settings, loading screen, credits (with third-party notices).
- Add a `GameState` autoload (a global script that loads at startup) holding the current call, elapsed time and an event log. Scoring reads the event log later.
- Add an `EventBus` autoload with signals such as `treatment_given`, `backup_requested`, `patient_moved`.
- Add Godot State Charts. Model the call flow as states: Dispatch, Arrival, Scene Safety, Assessment, Treatment, Extrication, Loading, Transport, Handover, Debrief.
- Define a scenario as a Godot `Resource` file: location scene, patient case, hazards, which backup is needed, scoring rules.

**Done when:** a placeholder call can go from menu through every state to an empty debrief screen.

### Milestone 11: Stretcher obstacle course

**Decision: the stretcher stays 1.0 m wide.** Build the world to fit it:

- Doorways at least 1.2 m wide, halls at least 1.5 m, and corners with room to turn a 2.2 m stretcher.
- Make the obstacles come from tight corners, furniture, clutter, rugs or thresholds, and steps, not narrow doors.
- **Stairs (maintainer decision): stair chair.** The stretcher cannot go on stairs. The student leaves it at the bottom, brings a stair chair to the patient, moves the patient onto it, and carries it down with the partner (a short animation, with the player choosing when to start each flight). At the bottom, the patient is moved onto the stretcher.
  - The stair chair is a new carried item with a seated patient. Moving the patient onto it, and later onto the stretcher, uses the same transfer action as Milestone 12.
  - Score: chair used on stairs (never the stretcher), and patient secured before moving.

Build:
- One two-level house scene (upstairs bedroom, stairs, living room, hallway, front door, front steps with a ramp or flat path, driveway). Block it out with CSG, then dress it with Kenney furniture and Scatter.
- Doors that open with INTERACT. Doors need a collider that the stretcher can bump.
- Optional moveable obstacles (a chair or table that can be pushed aside, using `HoldableObject` or a heavy `RigidBody3D`).
- Score stretcher handling: count hard hits on walls and furniture, and track time to exit.
- Bake a navigation mesh so NPCs can walk the same space.

**Done when:** the patient can be brought down the stairs in the stair chair, and the stretcher can be steered from the living room to the driveway. It should be hard without being frustrating.

### Milestone 12: People

- Patient, bystander and partner characters on the Quaternius rig. Animations needed: idle, walk, sit, lie down, lying on the stretcher, aggressive pose, being restrained.
- The patient on the stretcher moves with it, like stuck items (no physics), and counts as stretcher weight.
- NPCs walk with `NavigationAgent3D` and are driven by State Charts.
- Partner medic: follows the player and helps lift. Keep the partner's role small in the demo.

**Done when:** a patient can be moved from the floor or couch onto the stretcher, and NPCs walk around obstacles.

### Milestone 13: Dialogue and history taking

- Add Dialogue Manager.
- History questions from the maintainer's protocols (for example SAMPLE and OPQRST). Answers come from the scenario's patient case, so one dialogue file serves many patients.
- Bystanders give scene information. A violent bystander escalates if the student ignores scene safety.
- Log each question asked to the event log for scoring.

**Done when:** the student can take a full history and every answer comes from the scenario file.

### Milestone 14: Patient assessment and vitals

The core of the trainer. Build it ourselves, keeping it simple.

- `PatientCase` resource: starting vitals (heart rate, blood pressure, breathing rate, SpO2, glucose, temperature, GCS), findings for each body area, and rhythm.
- **Condition timeline:** vitals change over time and in response to treatments. Use State Charts for stages (for example stable, getting worse, critical, arrest).
- **Assessment UI:** a body diagram or menu for primary survey (airway, breathing, circulation) and secondary survey. Each check takes game time and reveals findings.
- **Treatments within the student's scope:** for example oxygen, positioning, CPR and defibrillation with the KOLE. Each is logged.
- **KOLE monitor:** draw the ECG line with `Line2D` and show numbers. Start with a few rhythms (normal, fast, ventricular fibrillation, asystole).
- Clinician review of all values and rules before student testing.

**Done when:** a cardiac arrest case can be assessed, shocked and resolved (or not) according to protocol.

### Milestone 15: Backup and radio

**Decisions:** backup acts on its own once it arrives. The doctor pronounces death by radio or phone.

- **Radio menu:** request ACP, CCP, police, or call online medical control.
- **Arrival:** each request has an ETA from the scenario. The unit appears at the curb and walks in with `NavigationAgent3D`.
- **Police:** on arrival they secure the scene automatically (calm or restrain the violent person). Until then, the scene stays unsafe. Score whether the student waited, retreated or called police early enough.
- **ACP and CCP:** on arrival they automatically do the advanced interventions the scenario lists (for example airway or medications), and the patient's condition responds. The student keeps leading. Score whether backup was requested, and how early.
- **Online medical control (doctor):** the student reports findings through a short menu, such as rhythm, time down and CPR duration. If the scenario's termination criteria are met, the doctor gives a time of death and the call moves to debrief. If not, the doctor tells the student to continue.
- Log every request, arrival and action.

**Done when:** each backup type can be called, arrives after its ETA, and does its job without input, and the doctor call can end resuscitation.

**Maintainer decision: unneeded backup costs no points.** The debrief notes that it was not needed and why. Missing backup that was needed still loses points.

### Milestone 16: Ambulance, loading and hospital handover

**Decision: hospital handover after loading. No driving in the demo.**

- Kenney Car Kit ambulance parked in the driveway, with rear doors that open.
- Loading: bring the stretcher to the rear, press LOAD, and play a short animation of it sliding in. Check alignment and speed before allowing it.
- Fade to a simple hospital bay. Wheel the patient to the bed.
- **Verbal handover in MIST format** (maintainer decision), with a Dialogue Manager menu. The student picks report items for each part: Mechanism or Medical complaint, Injuries or Illness, Signs (vitals and trends), Treatment given. Score completeness, accuracy against the event log, and order.
- Driving can be a later milestone. The `3d/truck_town` demo and `VehicleBody3D` are a starting point.

**Done when:** the patient can be loaded and handed over, and the report is scored.

### Milestone 17: Scenario, scoring and debrief

- Write the first full scenario with the maintainer (for example a cardiac arrest in a cluttered house, with an aggressive family member).
- Scoring rubric from the event log: scene safety, assessment steps, treatments and timing, backup requests, stretcher handling, handover.
- Debrief screen: score per section, timeline of what the student did, and what was missed with a short reason.
- Save results to a local JSON file (`user://results/`). Students share the maintainer's iPad, so ask for a student name or ID before each call, and add a results history screen for the instructor.

**Done when:** a student can play the call and get a fair, explained score.

### Milestone 18: Polish and demo build

- Sounds: siren, radio, monitor beeps, door, stretcher wheels. Kenney packs and CC0 only.
- UI theme from Kenney's UI pack. Large buttons for iPad.
- Short tutorial: move, pick up, stretcher, radio, assessment.
- Accessibility: subtitles for all speech, adjustable text size.
- Performance: test frame rate on the oldest iPad the class uses.
- `THIRD_PARTY_NOTICES.md` complete and shown in credits.
- Playtest with 2 or 3 students, fix the top issues.
- **Maintainer decision: students play on the maintainer's iPad in Xogot.** Make the game start cleanly from Xogot's run button to the main menu, and hide debug tools. A TestFlight build on students' own iPads (needs a Mac with Xcode and an Apple Developer account) can come after the demo.

**Done when:** students can play the full call on iPad without help.

## Order and dependencies

```
9 Fix core -> 10 Structure -> 11 Obstacles -> 12 People -> 13 Dialogue
                                                   \-> 14 Assessment -> 15 Backup
11 + 12 -> 16 Ambulance and handover
13 + 14 + 15 + 16 -> 17 Scenario and scoring -> 18 Polish
```

Milestones 11 and 14 can run side by side once 10 is done. Do not start 15 before 14, because backup changes the patient's condition.

## Questions for the maintainer (all answered)

1. Stairs: stair chair (Milestone 11).
2. Unneeded backup: debrief note only, no points lost (Milestone 15).
3. Demo: played on the maintainer's iPad in Xogot (Milestone 18).
4. Handover in MIST format. Content follows the maintainer's service protocols, reviewed by a qualified paramedic or instructor. **Still needed: the maintainer sends the protocol documents before Milestone 14.**
