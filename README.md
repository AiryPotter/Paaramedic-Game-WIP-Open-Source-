# Paramedic Simulator (Work in Progress)

A paramedic video game designed to prepare students for the logistical challenges of being a paramedic: moving equipment, steering a stretcher through tight spaces, loading a patient and coordinating a call.

> **The game code is on the [`xogot-project-upload`](https://github.com/AiryPotter/Paramedic-Game-WIP-Open-Source-/tree/xogot-project-upload) branch.** The `main` branch currently holds only this README.

> **Not for clinical use.** This is an early prototype. It contains no medical findings, vital signs or treatment rules yet. Clinical content will come from approved service protocols and be reviewed by a qualified paramedic or instructor before students use it.

## Project at a glance

| | |
|---|---|
| Engine | Godot 4.7, Mobile renderer, GDScript only |
| Editor | Xogot (Godot for iPad) |
| Target device | iPad, touch controls only |
| Players | Single player |
| Current stage | Milestone 9: core reliability and first patient interaction |
| Goal | A playable training demo: one full call from dispatch to hospital handover, with scoring |

## What works so far

- First-person walking with a touch joystick and a LOOK pad.
- Picking up, carrying, dropping and tossing equipment: a primary bag, a secondary bag, and the **KOLE** defibrillator (a fictional brand). KOLE's screen cracks on hard impacts, but the stretcher pad cushions it.
- A 2.20 m stretcher that can be grabbed from either end or side, with:
  - front and rear caster swivel locks that change how it steers (free, forklift-style, or straight only),
  - a sticky pad that holds equipment where it lands,
  - a PUSH action that lets it coast,
  - LOWER and RAISE for loading.
- A neutral training mannequin that can be assessed and loaded onto the lowered stretcher (placeholder only).
- An on-device test runner (`tests/qa_runner.tscn`).

Most of this still needs testing on iPad. See the [development log](https://github.com/AiryPotter/Paramedic-Game-WIP-Open-Source-/blob/xogot-project-upload/documentation/DEVELOPMENT_LOG.md) for what has been confirmed.

## Controls

| Control | What it does |
|---|---|
| Left joystick | Walk, or drive the stretcher while holding it |
| Right LOOK pad | Look around. While holding the stretcher, it orbits the camera. |
| INTERACT | Pick up or drop items, grab or release the stretcher, assess the patient. The label changes with what you aim at. |
| TOSS | Toss the item you are holding |
| FRONT / REAR | Lock or free the front or rear casters (while holding the stretcher) |
| PUSH | Let go of the stretcher and push it so it coasts |
| LOWER / RAISE | Lower the stretcher for loading, or raise it for moving (only when stopped) |

There are no keyboard controls.

## Getting started

### On iPad with Xogot
1. Get the `xogot-project-upload` branch onto the iPad and open the project in Xogot.
2. Run the project. It starts in `scenes/main/main.tscn`, the training floor.

### On a computer with Godot
1. Download or clone the `xogot-project-upload` branch.
2. Open `project.godot` in Godot 4.7 or newer.
3. The game expects touch input. To test with a mouse, turn on **Project Settings > Input Devices > Pointing > Emulate Touch From Mouse**. That gives only one finger, so moving and looking at the same time needs a touch screen.

### Running the tests
Open `tests/qa_runner.tscn` and run that scene. It runs smoke tests against the main scene, shows the results on screen, and saves them to `user://qa_runner_latest.txt`.

## Project layout

```
project.godot              Godot project settings
scenes/
  main/main.tscn           Training floor (the starting scene)
  equipment/               Bags, KOLE defibrillator, test pickup
  stretcher/               Stretcher
  patient/                 Training mannequin
scripts/
  player/                  Player movement and camera
  interaction/             Pickup, hold, toss, stretcher grab
  equipment/               KOLE impact damage
  stretcher/               Stretcher steering, locks, pad, height, push
  patient/                 Mannequin assessment and loading
ui/mobile_controls.gd      Touch joystick, LOOK pad and buttons
tests/                     On-device QA runner
assets/                    Models, materials, textures (empty so far)
documentation/
  GAME_DESIGN.md           Vision, design pillars and roadmap
  DEVELOPMENT_LOG.md       What each milestone added and what still needs testing
claude_suggestions/        Code reviews and plans from Claude Code
```

## How the project is built

The maintainer makes every design decision. Two AI tools help:

- **ChatGPT 6 Luna** writes and changes the game code, and records each milestone in `documentation/DEVELOPMENT_LOG.md`.
- **Claude Code** reviews the code and researches options. It never changes game code. It writes dated Markdown files in [`claude_suggestions/`](https://github.com/AiryPotter/Paramedic-Game-WIP-Open-Source-/tree/xogot-project-upload/claude_suggestions). Each file lists affected files, the issue and a proposed change. When two files disagree, the later one wins.

Nothing from a suggestion is applied until the maintainer approves it. Changes are tested on the iPad before the next one starts.

Key documents:
- [Game design](https://github.com/AiryPotter/Paramedic-Game-WIP-Open-Source-/blob/xogot-project-upload/documentation/GAME_DESIGN.md)
- [Milestone plan](https://github.com/AiryPotter/Paramedic-Game-WIP-Open-Source-/blob/xogot-project-upload/claude_suggestions/2026-11-25-milestone-plan.md), with recorded maintainer decisions
- [Open-source code we can borrow](https://github.com/AiryPotter/Paramedic-Game-WIP-Open-Source-/blob/xogot-project-upload/claude_suggestions/2026-11-25-open-source-borrowing.md)
- [Latest code review](https://github.com/AiryPotter/Paramedic-Game-WIP-Open-Source-/blob/xogot-project-upload/claude_suggestions/2026-11-25-code-review-4.md)

## Roadmap

| Milestone | Focus |
|---|---|
| 9 | Core reliability and first patient interaction (current) |
| 10 | Game structure: menus, call stages, scenario files |
| 11 | Stretcher obstacle course in a two-level house, with a stair chair for stairs |
| 12 | People: patient, partner and bystanders, and patient transfers |
| 13 | Dialogue and history taking |
| 14 | Patient assessment and condition, from approved protocols |
| 15 | Backup by radio: Advanced and Critical Care Paramedics, police, and online medical control |
| 16 | Ambulance loading and hospital handover (MIST report) |
| 17 | Full scenario, scoring and debrief |
| 18 | Polish and a demo build that runs on the maintainer's iPad |

## Contributing

- **Talk to the maintainer first.** Open an issue describing the change before writing code.
- **GDScript only.** Xogot may not run C# or GDExtension add-ons, so do not add them.
- **One change at a time.** Test it on iPad if possible, and add a short entry to `documentation/DEVELOPMENT_LOG.md`.
- **Borrowed code and assets:** use only MIT, CC0, Apache-2.0 or Unlicense material. Keep its license file, and list it in `THIRD_PARTY_NOTICES.md` (to be created when the first piece is added). Do not use GPL code. Do not copy anything that has no license.
- **Medical content:** do not invent symptoms, vital signs, protocols or treatment steps. Content must come from the maintainer's service protocols and be checked by a qualified clinician.
- **Never commit** real patient information, passwords, API keys or tokens, or material you do not have permission to share.
- **No real brands or likenesses.** Equipment uses fictional names such as KOLE. Do not copy real logos or product designs.
- **Code reviews from Claude Code** go in `claude_suggestions/` as a new dated file, never as code changes.

## License

No license has been chosen yet. The project is meant to be open source, but until a license file is added, the code is under default copyright and others may not reuse it.
