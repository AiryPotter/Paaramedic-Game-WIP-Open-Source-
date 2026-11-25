# Paramedic Simulator — Game Design

## Vision

A touch-first, first-person training game about making calm, safe decisions during a fictional emergency response. The player should feel responsible for the whole encounter: approach, communicate, assess, choose equipment, move the patient, and reflect on the result. The tone is grounded and supportive rather than graphic or punitive.

## Core play loop

1. **Dispatch:** Receive a short, fictional call brief and identify the immediate objective.
2. **Approach:** Navigate a small scene and notice hazards before committing to an action.
3. **Assess:** Interact with the patient, listen to their concern, and gather observations and simulated vitals.
4. **Prepare:** Select and use appropriate equipment; keep equipment secured and in good condition.
5. **Move:** Coordinate patient transfer and stretcher handling through a compact obstacle course.
6. **Transport:** Reach the extraction point while maintaining control of the stretcher and equipment.
7. **Debrief:** Review communication, assessment completeness, safe handling, time, and the patient's simulated trend.

## Design pillars

- **Readable touch controls:** Large, contextual controls; no keyboard dependency; minimal simultaneous button demands.
- **Patient-first interaction:** The patient is a person to communicate with, not just an objective marker.
- **Consequences with coaching:** Unsafe handling and missed steps should create understandable feedback and a chance to learn, not an arbitrary fail state.
- **Physical handling matters:** Bags, the KOLE defibrillator, and the stretcher retain their existing physical behavior and remain usable across scenarios.
- **Fictional, clinician-reviewed medical content:** Any clinical sequence or patient response must be checked by a qualified clinician before the game is presented as training. Simulated values are explicitly not real-world guidance.
- **Small, testable milestones:** Each milestone should preserve the working touch-only loop and be verified on the target iPad when possible.

## Scenario progression

### Milestone 9 — First patient encounter

Add one non-graphic training patient, contextual assessment interaction, a compact status panel, and a clearly labeled fictional set of initial observations. This establishes the patient-facing loop without pretending to teach treatment.

### Milestone 10 — Deliberate stretcher handling

Add an intentional PUSH action, preserve bumps under caster constraints, and make the control context clear. Tune a full push and stopping distance on the target iPad before adding more physics features.

### Milestone 11 — Equipment and patient-state actions

Add deliberate equipment actions and a small scenario state machine. Use clear action feedback, make equipment condition legible, and keep interventions generic until a clinician-reviewed scenario has been selected.

### Milestone 12 — Patient transfer and stretcher transport

Add a controlled patient-to-stretcher transfer, secured patient state, a visible extraction zone, and transport feedback. Patient mass and balance should be tuned in isolated physics tests before joining the main scenario.

### Milestone 13 — Call flow and debrief

Add a short dispatch/briefing, pause/restart flow, objective tracking, and a debrief that explains the score. Avoid a punitive timer; prioritize safe sequence and clear feedback.

### Milestone 14 — Content and polish

Add more clinician-reviewed scenarios, accessible text/audio options, environmental audio, and settings. Any borrowed code or assets must retain their licenses and notices.

## Current scope and assumptions

- The first playable scenario is a calm training case with one patient and fixed simulated observations.
- The current scene is a practice bay, not a real-world ambulance or hospital.
- No diagnosis, treatment recommendation, or claim of certification is made by the first patient-assessment milestone.
- Stretcher turning with both caster pairs free and major physics tuning remain deferred until the existing handling has been tested on the iPad.
