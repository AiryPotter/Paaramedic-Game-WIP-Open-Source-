# How the Code Works

A guide to the Paramedic Simulator prototype for someone who can program but has not seen this project. Read this first, then the script you want to change. Every gameplay script also starts with a short summary of its own.

**Engine:** Godot 4.7, Mobile renderer, GDScript only (Xogot on iPad cannot run C# or compiled add-ons).
**State described:** after the 2026-11-27 combine of `merged-edition` (menus, ambulance, vehicles, bystanders) with the approved fixes and readability cleanup.

---

## 1. The big picture

The app opens on a **main menu** (`scenes/ui/main_menu.tscn`). START TRAINING begins the training scenario and loads `scenes/main/main.tscn`: a training floor with the player, a stretcher, two bags, the KOLE defibrillator, a training mannequin, a parked ambulance, two parked vehicles and four bystanders.

The mission: **assess the mannequin → transfer it onto the lowered stretcher → raise and wheel it to the ambulance → load it.**

| Script | Class | Job in one line |
|---|---|---|
| `scripts/game/game_state.gd` | autoload `GameState` | Saved settings, the current scenario, its objectives, and a log of what happened. |
| `scripts/game/scenario_definition.gd` | `ScenarioDefinition` | Data only: a scenario's title, briefing, objectives and the events that complete them. |
| `ui/mobile_controls.gd` | (none) | Turns touches into joystick values and button presses, and draws the on-screen controls. |
| `scripts/player/player_controller.gd` | `PlayerController` | Walks and looks. While operating the stretcher, stands at its handle and passes the joystick on. |
| `scripts/interaction/pickup_interactor.gd` | `PickupInteractor` | Knows what the player is aiming at, and carries out button presses on the next physics tick. |
| `scripts/interaction/holdable_object.gd` | `HoldableObject` | Base for anything carryable: loose, held in hand, or stuck to the stretcher pad. |
| `scripts/equipment/defibrillator.gd` | `Defibrillator` | KOLE: a holdable whose screen cracks on a hard impact, except on the pad. |
| `scripts/stretcher/stretcher_controller.gd` | `StretcherController` | The stretcher: driving, caster locks, sticky pad, LOWER/RAISE, PUSH, bumps, LOAD animation. |
| `scripts/patient/training_patient.gd` | `TrainingPatient` | The mannequin: ASSESS, then TRANSFER onto a lowered, lined-up stretcher. |
| `scripts/ambulance/ambulance_controller.gd` | `AmbulanceController` | Parked ambulance: checks the stretcher is lined up at the rear ramp, then starts LOAD. |
| `scripts/ui/main_menu.gd`, `pause_menu.gd`, `control_layout_editor.gd` | | Menu, pause overlay, and the editor for dragging the two joysticks. |
| `scripts/props/training_vehicle.gd`, `training_bystander.gd` | | Scenery built from simple shapes in code (they also draw in the editor). |

**The one rule that keeps it simple:** input flows one way.

```mermaid
flowchart LR
    T[Touch screen] --> MC[mobile_controls.gd]
    MC -- joystick and look --> P[PlayerController]
    MC -- button taps --> I[PickupInteractor]
    I -- labels and enabled state --> MC
    P -- joystick while operating --> S[StretcherController]
    I -- grab, release, push, height, locks --> S
    I -- pick up, drop, toss --> H[HoldableObject: bags, KOLE]
    I -- assess, transfer --> TP[TrainingPatient]
    I -- load --> A[AmbulanceController]
    A -- begin_ambulance_load --> S
    S -- sticks items to the pad --> H
    TP -- rides on --> S
    TP & S -- record_event --> G[GameState]
    G -- current objective --> MC
```

- The UI never moves anything itself. It only calls methods on the player and the interactor.
- The player and the interactor never read touches. They get plain numbers and requests.
- So the touch UI can be replaced (for example by the Virtual Joystick add-on) without touching gameplay.
- Gameplay scripts report what happened to `GameState.record_event()`; they never touch objectives directly.

---

## 2. Game flow, objectives and settings

```mermaid
flowchart LR
    M[Main menu] -- START TRAINING --> G[GameState.start_scenario]
    G --> W[Training scene]
    W -- PAUSE --> PM[Pause menu]
    PM -- RESUME --> W
    PM -- RESTART --> G
    PM -- MAIN MENU --> M
    M & PM -- SETTINGS / edit controls --> E[Control layout editor]
```

- **Objectives advance by event name.** `resources/scenarios/training_sandbox.tres` lists four objectives and four event names (`patient_assessed`, `patient_secured_to_stretcher`, `stretcher_raised`, `stretcher_loaded_into_ambulance`). When the event for the *current* objective is recorded, the next objective shows at the top of the status panel. Events out of order are logged but do not skip ahead.
- **Settings** (look sensitivity, volume, where the MOVE and LOOK pads sit) are saved to `user://settings.cfg`. Pad positions are stored as a share of the screen size, so they fit any iPad. `GameState.settings_changed` tells the UI to refresh.
- **Pause** uses Godot's `get_tree().paused`. The pause menu is set to keep working while paused.
- Starting `main.tscn` directly (as the QA runner does) works, but no scenario is active, so no objective shows.

---

## 3. The scene tree

```
Main (Node3D)
├── WorldEnvironment, DirectionalLight3D
├── TrainingFloor (StaticBody3D, 24 x 24 m, top at y = 0)
├── PickupTruck, TrainingCar (TrainingVehicleProp)      obstacles
├── Ambulance (AmbulanceController, group "ambulance")  at (0, 0, -7), rear ramp facing the player
├── Bystander x4 (TrainingBystander)                    around the edge
├── Player (CharacterBody3D, PlayerController)          starts at (0, 0, 5)
│   ├── BodyCollision (capsule, radius 0.35, height 1.8)
│   ├── Camera3D (head height 1.55)
│   │   └── HoldPoint (Marker3D: where held items go)
│   └── Interactor (Node, PickupInteractor)
├── PrimaryBag, SecondaryBag (HoldableObject)
├── KOLEDefibrillator (Defibrillator)
├── Stretcher (RigidBody3D, StretcherController)        see section 6
├── TrainingPatient (TrainingPatient)
└── MobileControlsLayer (CanvasLayer)
    └── MobileControls (Control, mobile_controls.gd)     builds its buttons and the pause menu in code
```

Groups used to find things: `grabbable_stretcher`, `training_patient`, `ambulance`, `pickupable` (all carryable items).

---

## 4. A frame, step by step

Godot runs two loops. `_process` runs once per drawn frame. `_physics_process` runs at a fixed 60 Hz, **before** the physics engine moves bodies. After the physics step, `_integrate_forces` runs for bodies that define it.

```mermaid
sequenceDiagram
    participant Touch
    participant UI as mobile_controls
    participant Player as PlayerController
    participant Int as PickupInteractor
    participant Str as StretcherController
    participant Phys as Physics engine
    Touch->>UI: finger down / drag / up
    UI->>Player: set_movement_input(stick) or apply_look(drag)
    UI->>Int: request_interaction() etc. (button tap)
    Note over Int: request waits for the physics tick
    Int->>Int: _physics_process: aim ray, then carry out the request
    Player->>Str: _physics_process: set_operator_input(stick) while operating
    Str->>Str: _physics_process: joystick to target velocity
    Phys->>Str: physics step moves the body
    Str->>Str: _integrate_forces: apply bumps, then wheel rules
    UI->>UI: _process: refresh button text, visibility and objective from Int and GameState
```

Why requests wait for the physics tick: a tap can arrive at any time. Doing the work inside `_physics_process` means it never fights the physics engine halfway through a step.

**What INTERACT does** depends on the moment, checked in this order: drop the held item → (operating the stretcher) LOAD it if the ambulance says it is lined up, otherwise let go → act on what is aimed at (assess or transfer the mannequin, pick up an item, grab the stretcher). The button's label always says which.

---

## 5. Carrying things: HoldableObject

Every carryable item is always in exactly one state:

```mermaid
stateDiagram-v2
    [*] --> Loose
    Loose --> Held: pick_up()
    Held --> Loose: release() (drop or toss)
    Loose --> Stuck: touches the stretcher pad
    Stuck --> Held: pick_up() (unsticks first)
```

| State | Physics | Collisions | Who moves it |
|---|---|---|---|
| Loose | normal rigid body | on | the physics engine |
| Held | frozen (kinematic) | off (layer and mask 0) | `PickupInteractor` puts it at `HoldPoint` every tick |
| Stuck | frozen (kinematic) | mask off, layer kept (so it can still be aimed at) | the item follows the stretcher every tick |

**Stuck items predict.** `_physics_process` runs before the stretcher moves. If a stuck item just copied the stretcher's position, it would be drawn a step behind (about 4 cm at full speed). So it copies where the stretcher **will** be after this step, using the stretcher's velocity.

**KOLE** adds one check in `_integrate_forces`: while touching something, if velocity changed by 3 m/s or more since the last step, it was a hard hit, so the screen cracks. Contacts on top of the stretcher pad are ignored (the pad cushions it).

The mannequin is **not** a HoldableObject. It cannot be picked up or tossed.

---

## 6. The stretcher

### Its parts

```
Stretcher (RigidBody3D, 26 kg)
├── DeckAssembly (Node3D)          moves down 0.22 m on LOWER
│   ├── Deck                       mesh only
│   └── PadArea (Area3D)           thin sensor on the pad top: things touching it stick
├── SideRail x2, Crossbar x2       chassis meshes; stay put when the deck lowers
├── CollisionDeck                  deck collider, a DIRECT child (see section 10); follows the deck
├── CollisionFloorSupport          low box under the frame
├── WheelCollision x4              wheel colliders, direct children
├── Caster x4 (Node3D)             wheel visuals that turn and widen
└── FrontLockLever, RearLockLever  animated levers
```

Sizes: deck 1.0 m wide and 2.2 m long, pad top at 0.82 m (0.60 m lowered), casters 1.6 m apart.

### How it drives

Each end has a pair of casters. A pair is **locked** (wheels held straight, still rolling) or **free** (wheels turn to follow the motion). A lock is not a brake.

| Front | Rear | How it moves |
|---|---|---|
| Free | Free | Any direction. From an end, sideways input also swings that end. |
| Locked | Free | Front axle cannot slide sideways; the rear steers, forklift style. |
| Free | Locked | Rear axle cannot slide sideways; the front steers. |
| Locked | Locked | Straight along its length only. |

The joystick is read **relative to the handle the player grabbed**: up means "toward the stretcher's center from where I stand". There are four handles: both ends and both sides.

**Two steps every physics tick:**

1. `_physics_process`: turn the joystick into a target velocity and turn rate, and ease toward them.
   - All free: `_drive_all_free()`.
   - Any locked: `_drive_with_locks()`. It drives only along the length, and with one pair locked it steers with the bicycle formula: turn rate = forward speed × tan(steer angle) ÷ 1.6 m. At the 0.6 rad maximum, the tightest turn is about 2.3 m across.
2. `_integrate_forces`: runs inside the physics step on the real velocities. It first applies any queued bump, then enforces the wheel rules:
   - Both locked: no sideways sliding and no turning.
   - One locked: sideways speed is set so the locked axle does not slide.

Because the rules are applied in step 2, they hold for everything: driving, coasting after a PUSH, and bumps from the walking player.

### Other features

| Feature | How it works | Where |
|---|---|---|
| Sticky pad | Each tick, any loose item touching `PadArea` becomes stuck, flat on the pad, keeping its landing spot and turn. Paused while the deck moves. | `_stick_holdables_to_pad()` |
| LOWER / RAISE | A 0.55 s tween moves `DeckAssembly` and `CollisionDeck` by 0.22 m. Stuck items and the mannequin move with it. Only while held and nearly stopped. **The body is frozen during the move and stays frozen while lowered**, so it cannot roll away during a transfer; PUSH shows "RAISE TO MOVE". | `toggle_height()` |
| PUSH | Lets go and adds an impulse toward 2.2 m/s in the facing direction, along the length if any pair is locked. It then coasts about 1 m. | `push_from_operator()` |
| Bumps | The walking player calls `apply_character_bump()` on contact. The impulse is queued and applied at the contact point in `_integrate_forces()`, so a hit near an end swings it. | `apply_character_bump()` |
| LOAD | Releases the operator, turns off collisions, becomes a child of the ambulance and slides to its `CargoPose` over 1.1 s. After that it cannot be grabbed. | `begin_ambulance_load()` |

---

## 7. The mannequin

```mermaid
flowchart LR
    A[On the floor] -- INTERACT: ASSESS --> B[Assessed]
    B -- stretcher lowered, stopped, lined up; INTERACT: TRANSFER --> C[Transferring, 0.45 s]
    C --> D[Secured on the stretcher]
```

- `get_transfer_hint()` returns the next step as a button label: `ASSESS PATIENT`, `BRING STRETCHER`, `LOWER STRETCHER`, `STOP STRETCHER`, `LINE UP STRETCHER`, `ALIGN STRETCHER`, or `TRANSFER PATIENT` when ready. The INTERACT button shows it; the status panel shows a longer sentence for each.
- Lined up means: mannequin within 4.0 m sideways and 1.0 m along the stretcher from its center, long axes within 25 degrees of parallel (head-first or feet-first).
- TRANSFER freezes the mannequin, makes it a child of `DeckAssembly` (so it rides along and rises with RAISE), slides it on, and adds its 18 kg to the stretcher.
- **No clinical content yet.** It will come from the maintainer's service protocols, reviewed by a qualified paramedic or instructor.

---

## 8. The ambulance

- Generic and unbranded, built from boxes in `scenes/ambulance/ambulance.tscn`, with collision walls, a roof and an open rear with a ramp.
- `get_loading_hint()` explains what is missing once the stretcher is within 2 m of the staging spot behind the ramp: secure the mannequin first, raise the deck, stop, or line up.
- Lined up for LOAD means: stretcher center within 0.42 m sideways and 0.7 m along of the staging spot (3.4 m behind the ambulance's center), and within 0.35 rad (about 20 degrees) of straight, either way round.
- While the stretcher is held and lined up, INTERACT reads **LOAD STRETCHER**.

---

## 9. Collision layers

| Layer | Used by |
|---|---|
| 1 | Everything physical: floor, vehicles, ambulance, bystanders, player, items, stretcher, mannequin body |
| 2 | The mannequin's `InteractionArea`, so the aim ray can find it |

The aim ray checks layers 1 and 2 and includes areas. The pad sensor has no layer of its own, and watches layer 1.

---

## 10. Things that will bite you

1. **A `CollisionShape3D` only works as a direct child of a physics body or `Area3D`.** Put it under a plain `Node3D` and Godot silently ignores it. This happened to the deck in November 2026. The QA test "Stretcher collision shapes are direct children of collision bodies" now catches it.
2. **Change a rigid body's velocity inside `_integrate_forces` when the physics engine must see it this step.** Changes in `_physics_process` can be overwritten by the engine's own state, which is why bumps once disappeared.
3. **`_physics_process` runs before bodies move.** Anything that follows a moving body must predict, as stuck items do.
4. **Frozen bodies move only when code moves them.** Held and stuck items, the secured mannequin, and the lowered or loaded stretcher are frozen.
5. **Reparent outside the physics step.** The mannequin's TRANSFER and the stretcher's LOAD use `call_deferred` before `reparent()`.
6. **GDScript in Godot 4.7 is stricter than older examples online.** `:=` fails when the right side has no known type (for example `.get()` or `==` on an untyped value): write the type, `var x: bool = ...`. Lists of text join as `", ".join(list)`, not `list.join(", ")`. Both of these stopped scripts loading in November 2026.
7. **GDScript only.** No C#, no GDExtension. Borrowed add-ons must be pure GDScript with a permissive license (see `claude_suggestions/2026-11-25-open-source-borrowing.md`).
8. **`claude_suggestions/2026-11-27-suggested-code/` has a `.gdignore`** so Godot does not load the suggestion scripts. Keep it.

---

## 11. Key numbers

| What | Value | Where |
|---|---|---|
| Walking speed | 4.0 m/s | `PlayerController.move_speed` |
| Stretcher top speed | 2.2 m/s | `StretcherController.maximum_speed` |
| Stretcher steer angle | 0.6 rad | `maximum_steer_angle` |
| Stretcher turn speed cap | 1.2 rad/s | `maximum_turn_speed` |
| Reach: stretcher | 5.5 m (maintainer decision) | `PickupInteractor.stretcher_interaction_distance` |
| Reach: items and mannequin | 2.8 m | `bag_interaction_distance` |
| Toss speed | 2.8 m/s | `maximum_toss_speed` |
| KOLE crack threshold | 3.0 m/s change | `Defibrillator.crack_speed_change` |
| Joystick dead zone | 12% | `PlayerController.MOVEMENT_DEADZONE` |
| Camera transition | 0.65 s | `CAMERA_TRANSITION_TIME` |
| Default pad positions | MOVE (9%, 67%), LOOK (91%, 67%) of the screen | `GameState.DEFAULT_*_JOYSTICK_POSITION` |

---

## 12. Testing

**On the iPad (Xogot):** open `tests/qa_runner.tscn` and run it. It loads the main scene, runs 58 checks (including the whole mission: assess, transfer, raise, load), shows the results, and saves them to `user://qa_runner_latest.txt`. Real multitouch, app switching, the menus and the feel of the controls still need hands-on testing.

**On a computer, without a window** (used for the November 2026 merges):

```
Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script res://tests/run_qa_headless.gd --quit-after 40000
```

`tests/run_qa_headless.gd` explains why it needs an iPad-sized view and a fixed 60 fps.

---

## 13. Where to go next

- `documentation/GAME_DESIGN.md`: what the game should become.
- `documentation/DEVELOPMENT_LOG.md`: what each milestone changed.
- `claude_suggestions/2026-11-25-milestone-plan.md`: the roadmap and the maintainer's decisions.
- `claude_suggestions/2026-11-27-suggested-code/CHERRY_PICK.md`: open fixes and starter scripts not yet applied.
