# Research: Xogot's Language, Driving, Loading and Crash Physics

**For:** the maintainer and ChatGPT 6 Luna
**Written by:** Claude Code
**Date:** 2026-11-27
**Read with:** `2026-11-25-milestone-plan.md`, `2026-11-25-open-source-borrowing.md`

## Ground rules

- Research and suggestions only. No project code was changed.
- Nothing here was run. Test every idea in Xogot on iPad.
- Sources are web searches on 2026-11-27. Some are reviews, forum posts or player comments, and are marked as such.

## Maintainer decisions (2026-11-27)

| Topic | Decision |
|---|---|
| Depth | Describe what other games do, **and** how each feature could be built in Godot in Xogot |
| Purpose of driving and crashes | **Both:** ambulance driving (with crashes as a result of unsafe driving), and vehicle crash scenes that the paramedic responds to |
| Driving controls | **Joystick, like the first-person view.** Wheel-and-pedals and tilt steering are researched below as alternatives. |
| Unsafe transport | **Loses points and is explained in the debrief.** This covers driving off with the stretcher unsecured, and harsh driving with a patient on board. |
| Crash scenes | **The paramedic is alone on scene.** No fire crew or other responders. |
| Trapped patients | **None yet.** Early crash scenes have patients who can be reached without extrication. Entrapment comes later. Extrication roles are researched below. |

**Fit with the milestone plan:** Milestone 16 keeps driving out of the first demo. Everything on driving here is for after the demo. Loading (section 3) applies now. Crash scenes (section 4) could become a later scenario.

## 1. Xogot's coding language

### What Xogot supports on iPad
- **GDScript only.** Xogot's documentation says the iPad and iPhone app supports game logic in GDScript only. Projects and add-ons in C#, C++, Swift or other languages are unlikely to work there.
- **Add-ons:** only add-ons written in GDScript. Add-ons in C++, C# or other compiled languages are not supported, because Apple's security rules do not let an app load outside compiled code.
- **C# is available only in Xogot for Mac,** where Xogot builds and installs it. C# on iOS is still experimental. It does not run in the iPad app.
- **Device:** iPad with an A12 Bionic chip or newer. The editor is a one-time purchase.
- **Tooltips** need a trackpad or Apple Pencil, because an iPad has no hover. Tooltip text in this game's buttons will not show on iPad.
- Projects open in desktop Godot and the other way round, so the same files can be edited on a computer.

### GDScript in brief
GDScript is Godot's own language. It looks like Python: indentation marks blocks, `func` defines a function, and `var` defines a variable. Features this project already uses, and that the ideas below rely on:

| Feature | Example | Used for |
|---|---|---|
| Optional static typing | `var speed: float = 2.2` | Catches mistakes early, and runs faster |
| `@export` | `@export var max_speed := 2.2` | Values that can be tuned in the editor |
| Signals | `signal crashed(impact_speed)` | One node announcing an event without knowing who listens |
| `_physics_process(delta)` | Runs every physics tick | Driving, steering, traffic |
| `_integrate_forces(state)` | Direct access to a rigid body during the physics step | Wheel rules, crash detection (as in the stretcher and KOLE) |
| Tweens | `create_tween().tween_property(...)` | Short animations such as loading |
| `Resource` files | Scenario data | Scenarios, vehicle setups |

Godot's shader language is used for materials and visual effects. It is not GDScript.

## 2. Racing and ambulance driving

### What other games do
| Game | Feature | What players or reviewers said |
|---|---|---|
| Ambulance Life: A Paramedic Simulator (2025) | Run to the ambulance on a call, turn on the siren, drive to the scene through heavy realistic traffic. Each ambulance handles differently. | Some players said pedestrians do not react realistically to sirens, which hurt immersion. Reviews were mixed. |
| Flashing Lights | The siren alerts drivers ahead. | A guide notes the siren is needed for drivers to notice you. The developers have said they plan traffic AI improvements. |
| Police Simulator: Patrol Officers | Lights to pull cars over. | Players complained AI cars stop in the middle of the road instead of pulling over (2022 forum posts; may since be fixed). |
| GTA V mods (MTFO, Cryptic Emergency Traffic) | Make traffic yield to sirens in a more human way. | Settings include the speed at which yielding starts and delays before drivers react, separately for lights only and for siren. The MTFO author warns that GTA's AI is unpredictable. |
| Burnout 3: Takedown (2004) | Deliberately shunting rivals ("Takedowns") fills the boost bar. A slow-motion replay shows each wreck, then cuts back to the race. | One player said cutting from slow motion straight back to full speed made it easy to crash again. |

Common racing features (general knowledge, not tied to one source): a route line or GPS arrow, a minimap, a timer, checkpoints, a speed readout, and a results screen.

### How it could work in this game
**Vehicle physics**
- Use the built-in `VehicleBody3D` with `VehicleWheel3D` nodes. It is a raycast car built on `RigidBody3D`. Keep wheel meshes separate from the body mesh, as the Godot docs say. That also helps crash damage later.
- References (MIT, GDScript):
  - [`3d/truck_town`](https://github.com/godotengine/godot-demo-projects/tree/master/3d/truck_town) in the Godot demos: several vehicles, a town, and a speedometer.
  - [Kenney Starter Kit Racing](https://github.com/KenneyNL/Starter-Kit-Racing) (about 460 stars): arcade handling, simple to tune.
  - [GDCustomRaycastVehicle](https://github.com/Tobalation/GDCustomRaycastVehicle): a custom raycast car, for when `VehicleBody3D` cannot be tuned enough.
  - [Seerban/godot-vehicle](https://github.com/Seerban/godot-vehicle): more detailed vehicle physics. Probably more than this game needs.
  - Avoid `warrpy/Godot-VehicleBody-Demo`, which is GPL.
- Ambulance model: the Kenney Car Kit ambulance (CC0).
- An ambulance is heavy and top-heavy. Use a high mass and a center of mass that is not too low, so fast turns feel risky. This is a tuning starting point, not a measured value.

**Touch controls on iPad (maintainer decision: joystick)**
- Reuse the existing left joystick, so walking and driving feel the same:
  - Left and right steer.
  - Push forward to accelerate, and pull back to brake. Holding back after the ambulance has stopped reverses, after a short pause of about 0.3 s so braking does not turn into reversing by accident.
  - Steering returns to center when the thumb lifts, and gas is released.
  - At higher speed, the same stick movement steers less. This keeps the heavy ambulance stable.
  - Use a small dead zone, as the walking joystick already has.
- The right LOOK pad orbits the chase camera, which drifts back behind the ambulance after a moment.
- Buttons: SIREN, LIGHTS, a horn, and PARK (parking brake) for loading.
- Review 4 suggested turning the iPad's motion sensors off. With joystick driving they are not needed.

**Steering options compared** (research for later)

| Scheme | What research and players say | How in Godot |
|---|---|---|
| **Joystick (chosen)** | One usability study compared five touch schemes for a driving game: buttons, a steering wheel, a joystick, joystick plus buttons, and tilt. Its detailed results were not checked here. A forum player said a stick or wheel suits top-down and overhead views better. | Reuse `ui/mobile_controls.gd`'s joystick, as above. |
| On-screen wheel and pedals | GRID Autosport on iOS offers a "Wheel Touch" mode with an on-screen steering wheel. Real Racing 3 offers automatic gas as an option. Some players dislike tilt and prefer these. | A wheel control on the left that turns with the thumb's angle around its center. Gas and brake buttons on the right that read how far down the finger is held. |
| Tilt steering | Most mobile racing games use it by default, with buttons as a fallback. One study found tilt gave more immersion and better performance than touch in a racing game. Another found players preferred a different tilt mapping from the one they performed best with. Forum players are split: some want anything but tilt. | `Input.get_accelerometer()` or `Input.get_gravity()`, with a dead zone and smoothing. It returns zero in the editor, so test on the device. Needs the motion sensor settings left on. |

The common advice from players is to offer more than one scheme. Wheel-and-pedals and tilt could be added later as options in settings.

**Traffic that yields** (this is what reviewers missed in Ambulance Life and Police Simulator)
- Traffic cars follow lanes made with `Path3D` and `PathFollow3D`. They do not need full physics until they are hit.
- Yield rule, modeled on the GTA mods' settings:
  1. Each traffic car checks whether the ambulance has its siren on, is within about 40 m, and is behind it in the same direction.
  2. After a short random delay (0.5 to 1.5 s), the car slows and moves to the side of the lane. It does **not** stop in the middle of the road.
  3. Once the ambulance has passed, it waits a moment and pulls back into the lane.
  4. Use a shorter range when only the lights are on.
- Pedestrians at crossings stop and wait when they hear a siren.
- At intersections, some cars react late. This teaches clearing intersections carefully.
- The distances and delays above are starting values to tune.

**Scoring**
- Response time.
- Safe-driving events: collisions, speeding through red lights without slowing, and nearly hitting pedestrians.
- **Patient comfort while transporting:** measure hard acceleration, braking and cornering. The KOLE-style velocity-change check can measure this. Which limits matter clinically is for the maintainer and clinical reviewer to decide.
- **Maintainer decision: unsafe transport loses points and is explained in the debrief.** That covers:
  - driving off with the stretcher not secured (section 3, step 5),
  - harsh driving with a patient on board.

  The debrief shows when it happened and why it matters. The exact point values come with the scoring rubric in Milestone 17.
- Avoid Burnout's problem: any crash replay should end with the ambulance stopped or slowed, not straight back at full speed.

## 3. Loading an object onto or into another object

### What other games do
| Game | Feature | What players or reviewers said |
|---|---|---|
| Moving Out (2020) | Players carry furniture from a house into a van against a timer. A sofa has to be lifted at each end and angled through doorways. | Items can spill out of the van because of the physics. A tips guide suggests loading big items first, then throwing small ones in. A later update added a reverse mode: unloading the truck. One review said getting the physics to cooperate was part of the challenge. |
| SnowRunner | Some cargo is loaded with a crane. Before using the crane, the player sets the handbrake and lowers the support legs, or the truck rolls or tilts. Cargo must then be **confirmed as loaded** so it does not fall off during the trip. | One player said manual loading felt incomplete. |
| Death Stranding | Carried weight affects the character's balance. With over 60 kg, the character sways when moving sideways. Cargo can also go on vehicles. | Guides treat balance as a core skill. |
| Ambulance Life | Serious patients are moved into the ambulance for transport. | No mechanism details found. |

Developer forums (Roblox, Unreal) report that loose physics objects inside a moving vehicle often glitch: they jitter, slide or fall through. This is a known, general problem.

### How it could work in this game
This uses the same pattern as the sticky pad and patient transfer. Movement is physical up to the moment of loading. Then a scripted, frozen step takes over, so nothing glitches inside a moving vehicle.

1. **Load zone:** an `Area3D` at the ambulance's rear doors.
2. **Alignment check:** the stretcher is inside the zone, lined up within about 15 degrees, nearly stopped, raised to loading height, and the patient is secured. Show a hint for anything missing, such as "LINE UP" or "SLOW DOWN".
3. **Vehicle ready**, like SnowRunner: the ambulance's parking brake is on and the rear doors are open. If not, show "SET PARKING BRAKE" or "OPEN DOORS".
4. **LOAD action:** freeze the stretcher and patient (kinematic), reparent them to the ambulance, and play a short tween or animation as it slides in.
5. **Secure step**, like SnowRunner's confirmation: tap SECURE to lock the stretcher mount. **Driving off unsecured loses points and appears in the debrief** (maintainer decision).
6. **Unload** at the hospital is the reverse. Moving Out's reverse mode shows unloading can be its own challenge.
7. **Equipment inside the ambulance:** stick bags and KOLE to shelves the same way as the pad, so nothing loose rides along.
8. **Weight and balance** (optional, like Death Stranding): when the player carries something heavy, slow walking slightly and sway the camera.

## 4. Vehicle crash physics

### What other games do
| Game | Approach | Notes |
|---|---|---|
| BeamNG.drive | **Soft-body physics.** Each vehicle is a hidden frame of points with mass (nodes), joined by springs (beams), defined in JSON-like "JBeam" files. Each beam has a spring value (how much it flexes back), a deformation value (when it bends permanently) and a strength (when it breaks). | The developer says there is no predefined damage. Independent articles say results do not always match real crashes. Very demanding on computers. |
| Wreckfest | Heavy, detailed crash damage. | Its technical method was not found. Players compare it with BeamNG and say it is less detailed but runs better. |
| Burnout series | Spectacular scripted crashes. Takedowns, slow-motion crash cameras, steering the wreck in mid-air ("aftertouch"), and a multi-angle replay ("Showtime" in Burnout Paradise). | Focused on spectacle rather than realism. |

### How it could work in this game, from lightest to heaviest

| Method | How | iPad cost | Use for |
|---|---|---|---|
| **A. Damage states** | Swap in pre-made damaged meshes or materials after hits pass set thresholds. Detach parts (bumper, door, mirror) as separate rigid bodies. | Very low | Ambulance crashes while driving. Recommended first. |
| **B. Pre-built wreck scenes** | Model the crashed cars in their final state. Nothing is simulated. Add smoke, fluid decals, broken glass, hazards. | Very low | Crash scenes the paramedic arrives at. Recommended. |
| **C. Vertex denting** | On impact, take the contact point and force, and push nearby vertices of the body mesh inward, less the farther they are (with `MeshDataTool` or `ArrayMesh`). Do this once per impact. | Medium. Keep the body mesh low-poly. | Extra detail on top of A |
| **D. Soft-body** | `SoftBody3D` springs back (no permanent dents), so community projects build custom soft-body systems on Jolt physics. | Very high | Not recommended for iPad |

Notes on the methods:
- Method C can stretch the mesh oddly, because nothing keeps the surface area the same. Moving bones instead of vertices is more controllable.
- A Godot forum thread describes a real-time car deformation and destruction system for mobile. It was not checked in detail, so test before relying on it.
- **Crash detection:** reuse the KOLE pattern. Turn on contact monitoring and compare velocity before and after a contact. A large change is a crash, and its size gives the severity. Emit a signal such as `crashed(severity, contact_point)` so damage, sound, the patient's state and the event log can each react.

### Crash scenes to respond to
**Maintainer decisions: the paramedic is alone on scene, and there are no trapped patients yet.**

- Build the scene with method B: one or two wrecked cars and the hazards that the protocols list.
- Every patient can be reached without cutting: through an open or unlocked door, or already out of the car.
- Because the paramedic is alone, there is no partner for lifting. How a lone paramedic moves a patient follows the maintainer's protocols. This affects the stretcher and stair chair work in Milestones 11 and 12, which assumed a partner.
- Hazards and patient care steps at a crash, such as scene safety, traffic and spinal care, must come from the maintainer's protocols with clinical review. None is described here.

### Extrication roles (research for later, when trapped patients are added)
**Real-world extrication** uses hydraulic rescue tools: spreaders, shears (often called the Jaws of Life), combination spreader-shears, and rams. Crews often remove windows, cut the roof posts and sometimes lift the roof off. One 2016 crash needed seven tools at once: two cutters, a spreader and four rams. A rescue or squad truck carries them.

| Option | What it looks like | Notes |
|---|---|---|
| Fire crews do it on their own | Fire crews arrive and cut the patient free while the paramedic gives care. Same pattern as Milestone 15 backup. | The Emergency series of strategy games is known for this split of fire crews freeing people and medics treating them. That is general knowledge; game details were not found in these searches. Simplest to build. |
| Paramedic directs it | The paramedic tells the fire crew where and when to cut, based on the patient's needs. | Tests leadership and communication. Needs a command menu and more crew behaviors. |
| Paramedic does it | The paramedic uses the tools themselves. | Some EMS systems train paramedics in this. In Pittsburgh, every paramedic must pass a Basic Vehicle Rescue course that covers cutting and spreading tools. Fits the "paramedic alone" decision, but adds tool use, car parts that can be cut, and a lot of safety rules. |

No game-specific details about extrication were found in Firefighting Simulator: The Squad or Emergency 4 during these searches.

### Crashes as a result of the ambulance's driving
- A crash (method A) adds a delay, damages the ambulance, and is logged for the debrief.
- If the patient is on board, a severe crash could change the patient's condition, using scenario data from approved protocols.
- Keep it consequence-focused, not spectacle: no Burnout-style slow-motion replays.

## Questions for the maintainer (all answered)

1. Driving controls: joystick, like the first-person view. Wheel-and-pedals and tilt are researched as later options.
2. Unsafe transport: loses points and is explained in the debrief.
3. Crash scenes: the paramedic is alone on scene, with no trapped patients yet. Extrication roles are researched for later.

**New follow-up:** the stretcher and stair chair plans assumed a partner. With the paramedic alone at crash scenes, should the partner also be removed from house calls, or only from crash scenes?

## Sources

- Xogot: [Differences from Godot: iPad and iPhone](https://docs.xogot.com/documentation/xogot/differences/), [.NET and C# in Xogot for Mac](https://docs.xogot.com/documentation/xogot/mac_dotnet/), [Getting Started](https://docs.xogot.com/documentation/xogot/getting-started/), [Godot showcase: Xogot](https://godotengine.org/article/godot-showcase-xogot/)
- Godot: [Scripting languages](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_languages.html), [VehicleBody3D](https://docs.godotengine.org/en/4.3/classes/class_vehiclebody3d.html), [Forum: deforming a car like a real one](https://forum.godotengine.org/t/how-would-i-make-a-car-in-godot-deform-similar-to-a-real-car/58203), [Forum: soft-body crash prototype on Jolt](https://forum.godotengine.org/t/real-time-soft-body-car-crash-physics-prototype-godot-jolt-customized/131259), [Forum: car deform and destruction on mobile](https://forum.godotengine.org/t/real-time-car-deform-and-destruction-system-in-godot-mobile/136348), [Q&A: deforming a car mesh](https://ask.godotengine.org/100682/how-to-deform-mesh-car-when-it-collides-car-crash-simulation)
- Ambulance Life: [Steam](https://store.steampowered.com/app/1926520/Ambulance_Life_A_Paramedic_Simulator/), [Gamepressure](https://gamepressure.com/games/ambulance-life-a-paramedic-simulator/zf6bcd)
- Traffic and sirens: [Police Simulator forum](https://steamcommunity.com/app/997010/discussions/0/3266808619797481398), [Flashing Lights guide](https://gamerjournalist.com/how-pull-someone-over-in-flashing-lights-traffic-stop-guide/), [MTFO mod](https://www.lcpdfr.com/downloads/gta5mods/scripts/47768-mtfo-move-the-f-over/), [Cryptic Emergency Traffic mod](https://www.lcpdfr.com/downloads/gta5mods/scripts/55359-cryptic-emergency-traffic/)
- Burnout: [GameSpot review](https://gamespot.com/reviews/burnout-3-takedown-review/1900-6106835/), [GameSpot preview](https://gamespot.com/articles/burnout-3-takedown-feature-preview/1100-6104473/), [GameSpot user review](https://www.gamespot.com/burnout-3-takedown/user-reviews/2200-535143/), [Burnout series](https://Www.wikipedia.org/wiki/Burnout_(series))
- Loading: [Moving Out (Wikipedia)](https://en.wikipedia.org/wiki/Moving_Out_(video_game)), [Game Informer review](https://www.gameinformer.com/review/moving-out/moving-out-review-packed-with-frustration), [Shacknews tips](https://shacknews.com/article/117802/moving-out-5-helpful-tips-for-beginners?amphtml=1), [SnowRunner crane guide](https://www.gamepressure.com/snowrunner/crane/zbd502), [SnowRunner loading feedback](https://community.focus-entmt.com/focus-entertainment/snow-runner/ideas/8061-manual-loading-and-unloading-cargo-is-not-as-good-as-it-could-be), [Death Stranding balance](https://www.powerpyx.com/death-stranding-how-to-balance-cargo), [Roblox forum: objects in moving vehicles](https://devforum.roblox.com/t/objects-in-moving-vehicle-being-glitchy/2315508), [Unreal forum: physics objects in a cart](https://forums.unrealengine.com/t/physics-objects-inside-a-physics-container-shopping-cart/2606280/4)
- Crash physics: [BeamNG physics](https://beamng.com/game/about/physics), [JBeam physics theory](https://wiki.beamng.com/JBeam_Physics_Theory), [Yahoo Autos on BeamNG realism](https://autos.yahoo.com/no-those-viral-beamng-crash-200000996.html), [Steam discussion comparing Wreckfest](https://steamcommunity.com/app/228380/discussions/0/3559414588254146916), [Overtake.gg on soft-body physics](https://overtake.gg/news/comments/92223)
- Extrication: [Hydraulic rescue tool](https://Www.Wikipedia.org/wiki/Hurst_Tool), [Squad truck](https://en.wikipedia.org/wiki/Squad_truck), [Vehicle extrication](https://Www.Wikipedia.org/wiki/Vehicle_extrication), [Fire Engineering: one tough extrication](https://www.fireengineering.com/technical-rescue/one-tough-extrication/), [Fire Engineering: rush-hour technical rescue](https://www.fireengineering.com/technical-rescue/a-technical-rescue-in-rush-hour-traffic/), [Firefighting Simulator: The Squad](https://www.playstation.com/en-au/games/firefighting-simulator-the-squad/)
- Steering: [Tilt or Touch (study)](https://www.researchgate.net/profile/Muhammad-Suhaib-6/publication/328127724_Tilt_or_Touch_An_Evaluation_of_Steering_Control_of_Racing_Game_on_Tablet_or_Smartphone/links/5bd95e1492851c6b279b9df9/Tilt-or-Touch-An-Evaluation-of-Steering-Control-of-Racing-Game-on-Tablet-or-Smartphone.pdf), [Rocha et al. 2019, five control schemes](https://estudogeral.sib.uc.pt/bitstream/10316/87771/1/Rocha%20et%20al.%20-%202019%20-%20Mapping%20Controls%20on%20a%202D%20User%20Drawn%20Racetracks%20Driving%20Game%20%e2%80%93%20An%20Usability%20Assessment.pdf), [York University tilt study](https://www.yorku.ca/mack/ie2014.html), [Droid Gamers poll](https://www.droidgamers.com/news/poll-do-you-prefer-using-tilt-to-steer-or-on-screen-navigation-buttons-for-racing-titles/), [TouchArcade forum](https://toucharcade.com/community/threads/how-do-you-prefer-to-steer-in-a-car-game.173404/), [GRID Autosport iOS controls](https://support.feralinteractive.com/en/mac-linux-games/gridautosport/faqs/ios_control_methods), [Godot controller features](https://docs.godotengine.org/en/stable/tutorials/inputs/controller_features.html), [Godot Input class](https://docs.godotengine.org/en/4.2/classes/class_input.html)
- Vehicle code: [Godot demo projects](https://github.com/godotengine/godot-demo-projects), [Kenney Starter Kit Racing](https://github.com/KenneyNL/Starter-Kit-Racing), [GDCustomRaycastVehicle](https://github.com/Tobalation/GDCustomRaycastVehicle), [Seerban/godot-vehicle](https://github.com/Seerban/godot-vehicle), [Kenney Car Kit](https://www.kenney.nl/assets/car-kit)
