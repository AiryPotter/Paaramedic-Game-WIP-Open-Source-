# Development Log

## Milestone 1 — Basic environment and player movement

- Added `scenes/main/main.tscn` with a lit training floor, two collision-enabled block obstacles, a capsule player, and a first-person camera.
- Added `scripts/player/player_controller.gd` using `CharacterBody3D` for gravity and smoothed horizontal movement.
- Configured the project to launch the new main scene.

## Milestone 2 — Touch movement and look controls

- Added `ui/mobile_controls.gd` with a floating left-side joystick and right-side drag-to-look input.
- The controls track independent touch IDs, allowing movement and looking with two fingers.
- Updated `PlayerController` with relative movement and clamped vertical camera look; UI remains decoupled through movement/look methods.
- No keyboard controls, interaction buttons, or external dependencies were added.

**Validation note:** The developer confirmed on iPad that the joystick and camera look work well. Re-test simultaneous two-finger input and touch release as needed.

## Training-scene visibility and camera controls

- Added a muted warm-gray floor, high-contrast orange and teal obstacles, a dark blue-gray background, and soft ambient illumination.
- Increased the first-person camera FOV to 85 degrees.
- Added a visible right-side LOOK pad with a responsive thumb indicator while retaining drag-to-look input.
- Kept the original low-poly geometry and gameplay unchanged. The developer confirmed the scene looks good.

## Milestone 3 — Physical object interaction

- Added a reusable `HoldableObject` rigid-body component and a `PickupInteractor` that queues camera-ray pickup/release requests for physics ticks.
- Added a temporary yellow test pickup in `scenes/equipment/test_pickup.tscn`.
- Added a center reticle and an on-screen INTERACT button; the button is excluded from look-touch tracking.
- Held objects are frozen and moved to a camera-relative hold point; release restores collision and physics and inherits some player velocity.
- The developer confirmed pickup and release work in the running game.

## Milestone 4 — Paramedic bags

- Added primary and secondary low-poly physical bag scenes, each with collision and the reusable holdable script.
- Replaced the test pickup in the main scene with both bags, placed within the training area.
- Bags can be picked up, carried, and physically set down using the existing INTERACT control. A contextual TOSS button now provides a short, capped underhand toss. Stretcher-deck placement is deferred until it is integrated with the stretcher.
- The developer approved the bag models and requested the stretcher as the next milestone.

## Milestone 5 — Stretcher and grab mode

- Added a reusable low-poly stretcher scene with a deck, frame, four wheel meshes, and physics collision shapes.
- Added a grab/release path to the existing interaction button. The stretcher can be grabbed from its ends or either long side; the operator offset changes while the camera stays at the same third-person orientation.
- While grabbed, the vertical joystick axis drives the stretcher forward/back with rigid-body force, the horizontal axis provides basic yaw steering, and the player follows the nearest handle position.
- Added a smooth camera transition from first person to a fixed third-person view during stretcher mode; look rotation is disabled while pushing.
- Set separate reach limits: 5.5 m for the stretcher and 2.0 m for bags. Added a contextual TOSS control for held bags with a 2.8 m/s launch-speed cap and slight upward arc.
## Milestone 6 — Caster locks and touch reliability

- Added independent front and rear caster swivel locks with controls available during stretcher mode.
- Locking spreads the matching caster legs and animates its end lever; unlocking narrows the legs and returns the lever. These animations are separate from the grab/release camera tween.
- Both caster pairs free: the stretcher moves omnidirectionally. With one pair swivel-locked, it steers car-style from the other pair; with both locked it rolls straight. A swivel lock fixes caster direction only and is not a wheel brake.
- Added front/rear operating positions so the player can grab from either end or side while keeping a consistent third-person camera orientation.
- Added cancellation, focus-loss, pause, and scene-exit cleanup to reset touch input and release a stuck movement joystick.
- Touch recovery clears stale IDs on focus/resume, viewport resize, and stretcher-mode changes. If a new touch reuses an active finger index, it first releases the stale joystick/look state; a second finger still cannot steal an active joystick.
- Locking a caster pair now snaps its wheels straight immediately. While operating the stretcher, the left pad drives and the right LOOK pad orbits the camera around the character; dragging right moves the camera around to the left, and vice versa.
- Drive direction and operator facing are captured at grab time. With the front pair locked, the rear pair leads steering; with the rear pair locked, the front pair leads steering. Side operators can drive along the stretcher and steer the free end.
- Moved wheel collision shapes directly under the rigid body, set low rolling friction, and constrained lateral slip at swivel-locked axles while preserving forward roll. Bumping an unoccupied stretcher now imparts a speed-scaled impulse; grabbing stops its drift. Analog input has a dead zone and retains variable speed.
- Runtime validation is pending: verify wheel contact, bump/coast/grab behavior, each lock combination from both ends and sides, steering visuals, camera orbit, multitouch buttons, and touch recovery after Xogot interrupts input.

## Milestone 7 — KOLE defibrillator equipment

- Added a low-poly, pickupable KOLE-brand defibrillator to the training scene.
- A hard impact reveals a persistent cosmetic cracked-screen overlay. Tossing alone does not crack it; landing on the stretcher pad is cushioned.
- Runtime validation is pending: check soft and hard floor drops, toss impacts, and padded-deck landings.

## Milestone 8 — Longer stretcher and sticky equipment pad

- Extended the stretcher deck to 2.20 m and updated the rails, crossbars, casters, wheel colliders, wheelbase, and operator end positions. The stretcher now spawns at floor height.
- Expanded the pad sensor to the full deck; any holdable that touches it sticks immediately, with no footprint or overhang restriction. Objects flatten, preserve their yaw and landing position, and predict the stretcher's next physics pose to avoid one-tick trailing while moving.
- Picking up a secured object restores its collision mask and normal rigid-body behavior. Side/leg impacts do not trigger sticking.
- Increased caster swivel response, steering angle, turn acceleration, and turn-speed cap for quicker steering; broader turning-radius tuning remains deferred.
- KOLE cracks on hard impacts except for contacts with the padded stretcher top.
- Runtime validation is pending: test immediate sticking across the full pad, overhanging items, pickup after sticking, hard/soft KOLE impacts, quicker steering in both directions with the rear pair locked, deck travel, and wheel contact.

## Milestone 9 — Core reliability and first patient interaction

- Fixed one-tick sticky-pad trailing by predicting the stretcher's next physics pose. Reused touch indexes now clear stale joystick/look input before starting a new touch.
- Added a non-graphic low-poly training patient, contextual assessment interaction, and a compact touch-safe status panel. The patient interaction is a placeholder only: no symptoms, vitals, diagnosis, or treatment advice are invented before approved protocols and clinician review.
- Added a LOWER/RAISE stretcher control. The deck lowers 0.22 m only while stopped; the deck collision, pad sensor, and secured equipment follow the deck while the chassis rails and crossbars remain fixed. The chassis locks while lowered and unlocks on raise. After assessment, the mannequin is transferred by a short INTERACT animation only when the lowered stretcher is stopped, the mannequin center is within 4.0 m sideways and 1.0 m along the deck, and their long axes are aligned within 25°; patient pickup and tossing are intentionally unavailable.
- Prevented look input from fighting camera enter/exit tweens, preserved the original walk-camera pose across quick re-grabs, and normalized transition yaw to the shortest turn.
- Routed character-bump impulses through the rigid body's integration state before caster constraints are applied; the collision point supplies torque so a sideways hit can swing a free end. Locked-wheel bump behavior still needs device verification.
- On grab, player facing now aligns with the selected end/side operating spot, avoiding oblique input mixing. When both caster pairs are free, an end operator's sideways input swings that end and retains half the sideways slide; side operators still slide without yaw. Both are starting feel values and need device tuning.
- Added a contextual PUSH control while operating the stretcher. It releases the operator and applies a capped impulse in the direction they face; with casters locked, the push projects onto the stretcher's long axis and indicates when the operator should align first.
- Locked-caster constraints operate on `PhysicsDirectBodyState3D`; character bumps are queued and applied there before those constraints. Steering yaw uses actual forward speed; bump and push behavior still needs device verification.
- Added `documentation/GAME_DESIGN.md` with the iPad demo target, core loop, and staged roadmap. No clinical findings or treatment steps are presented in this milestone.
- Developer feedback confirms stretcher maneuvering and sticky bag overhang feel good. The controlled mannequin transfer is new and still needs runtime/device validation. Further checks remain pending: assess the patient, lower/raise the deck, confirm secured equipment follows both transitions, raise with the patient aboard, verify touch-safe UI and camera transition/orbit/re-grab behavior, grab from oblique angles at each end/side and confirm facing aligns, test PUSH in each caster-lock setup, bump the stretcher in all four lock states and confirm a sideways hit swings the free end with one axle pair locked, test swing-and-slide from both ends when both caster pairs are free, and retest touch recovery.

## Milestone 10 — Game structure (in progress)

- Added a touch-friendly main menu with a training-sandbox entry and look-sensitivity, master-volume, and draggable MOVE/LOOK control-position settings. Stick positions persist in `user://settings.cfg`, can be reset, and default to about one-third of the screen height above the bottom edge.
- Replaced the two colored-box obstacles with a simple blue car and red pickup truck built from Godot primitives, and added four low-poly bystanders around the training-area perimeter.
- Kept the touch-layout editor actions visible near the top of the screen and added a pause-menu **SAVE & RESUME** action so players can save control positions and immediately return to the active game.
- Added a pause overlay with resume, restart, settings, and return-to-menu controls.
- Added a lightweight `GameState` autoload with session event logging and persisted settings, plus a data-only scenario resource with neutral placeholder patient content, objectives, hazards, and scoring metadata.
- Connected the scenario launch, patient assessment and controlled stretcher transfer, stretcher lower/raise, and ambulance loading to the event log.
- Runtime validation is pending: verify launch from the menu, pause/resume, restart, return to menu, settings persistence, and event-log contents.

## Milestone 16 — Ambulance loading (early work in progress)

- Added a generic low-poly parked ambulance with an open rear bay, rear ramp, collision walls, and a stretcher cargo pose; driving and branded real-world details remain out of scope.
- Expanded the training sandbox into a neutral transport mission: assess the mannequin, secure it on the lowered stretcher, raise and wheel the stretcher to the ambulance, then align and load it.
- Added an alignment-checked rear LOAD action with clear guidance for missing patient, lowered deck, movement, and alignment requirements. The stretcher releases its operator, freezes safely, and animates into the cargo bay; completion is logged only after the animation.
- Runtime validation is pending: inspect the ambulance model in-game, confirm the loading zone and alignment feel generous on touch, verify the loading animation and patient follow-through, and check objective completion.
