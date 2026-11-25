# Open-Source Code to Borrow

**For:** ChatGPT 6 Luna
**Written by:** Claude Code
**Date:** 2026-11-25
**Read with:** `2026-11-25-code-review.md`, `2026-11-25-code-review-2.md`, `2026-11-25-feature-plan.md`

## Ground rules

- Suggestions only. No project code was changed.
- Get the maintainer's approval before copying anything in, one piece at a time.
- None of this was run here. Test each borrowed piece in **Xogot on iPad** before building on it.
- Licenses and activity were checked on 2026-11-25 through the GitHub and Codeberg APIs.

## Xogot limits

The maintainer builds in **Xogot**, the Godot editor for iPad. The project is Godot 4.7, Mobile renderer.

- **Use plain GDScript only.** I found no source saying that Xogot runs C# or GDExtension add-ons (native compiled code). Treat both as unavailable until tested.
- Copying a folder into `addons/` should work. Check that the plugin appears and enables in Xogot's Project Settings.
- Many templates use the Forward+ renderer. Their scripts still work. Their shaders, lights and effects may look different or fail on Mobile.
- Do not add the old `godot-jolt` extension. Godot 4.4 and newer already include Jolt physics, and the extension is native code.

## License rules

- **Use only MIT, CC0, Apache-2.0 or Unlicense code.** Keep each project's copyright and license text.
- **Avoid GPL and AGPL code.** Copying it would make the whole game GPL.
- **No license means no permission to copy.** Use those projects only as ideas.
- Add a `THIRD_PARTY_NOTICES.md` file at the repo root. List each borrowed project with its license and link, and paste the license text.
- The game repo has no license file. The maintainer should choose one before public release.

## Best matches for this game

Ranked by how much work each saves.

### 1. Touch joystick: Virtual Joystick (MIT)
https://github.com/MarcoFazioRandom/Virtual-Joystick-Godot (about 1,000 stars, pure GDScript)

- **Fixes:** Review 2 item N6, where a missed touch release can stick the joystick. This add-on tracks its own finger index and handles multitouch.
- **Use:** Replace the hand-written joystick in the touch UI with it. Keep our action names so movement code is unchanged.
- **Note:** Its README recommends "Emulate Touch From Mouse" ON and "Emulate Mouse From Touch" OFF. Recheck the PUSH, TOSS and INTERACT buttons after changing those settings.
- Backup option: https://github.com/Wesley-Source/versatile-mobile-joystick (MIT, smaller).

### 2. Carry, throw and impact damage: COGITO (MIT)
https://codeberg.org/Phazorknight/Cogito (it moved from GitHub to Codeberg; Godot 4.6, Forward+)

A first-person template that already has carrying, throwing and damage from impacts. **Borrow ideas and small pieces, not the whole framework.** It is large and its parts depend on each other.

| COGITO file | Useful for |
|---|---|
| `addons/cogito/Components/Interactions/CarryableComponent.gd` | Holding an object in front of the camera and throwing it with an impulse. Compare with our `holdable_object.gd` and `pickup_interactor.gd`. |
| `addons/cogito/Components/ImpactAttributeDamage.gd` | Damage only above a minimum impact speed, with a short cooldown between hits. Same idea as the KOLE crack check in review 2 N11. The cooldown stops a bounce from counting twice. |
| `addons/cogito/Components/ImpactSounds.gd` | Impact sounds by speed. Cheap feedback for drops and tosses. |
| `addons/cogito/Components/PlayerInteractionComponent.gd` | Interaction prompts ("Pick up", "Lock wheels"). |

### 3. Pickup and hand-off patterns: Godot XR Tools (MIT)
https://github.com/GodotVR/godot-xr-tools

Made for VR, but `addons/godot-xr-tools/objects/pickable.gd` is a well-tested pick-up, drop and release design. It has release modes, `can_pick_up()` and grab points. **Read, do not install.** The add-on needs XR nodes.

### 4. Official Godot demos (MIT)
https://github.com/godotengine/godot-demo-projects

These are maintained by the Godot team, so they match current Godot.

| Demo | Useful for |
|---|---|
| `3d/truck_town` | Steering a wheeled body. Compare with the stretcher's caster steering. |
| `3d/physics_tests` | Small test scenes for contacts, joints and rigid bodies. `utils/rigidbody_pick.gd` drags rigid bodies with the pointer. Use it to check stretcher bumps (review 2 N1, N2). |
| `3d/rigidbody_character` | Pushing rigid bodies while walking. Relevant to bump plus PUSH. |
| `mobile/multitouch_cubes` and `mobile/multitouch_view` | Correct multitouch handling on iPad. |

### 5. Menus and settings: Maaack's Godot Game Template (MIT)
https://github.com/Maaack/Godot-Game-Template (about 1,760 stars, GDScript)

Main menu, pause, options, credits and a loading screen. Use it later when the game needs a start screen and settings. The credits screen can also show the third-party notices. A smaller version without the game loop: https://github.com/Maaack/Godot-Menus-Template.

### 6. Player movement reference: Modular Character Controller (MIT)
https://github.com/expressobits/character-controller (GDScript)

First-person movement with head bob and camera motion. Only worth borrowing if the current player controller needs rework. Do not replace a working controller.

### 7. Later features

| Need | Project | License |
|---|---|---|
| Patient and partner conversation | https://github.com/nathanhoad/godot_dialogue_manager | MIT. GDScript core; the C# part is optional and should be skipped. |
| Equipment bags with contents | https://github.com/peter-kish/gloot | MIT, GDScript |
| On-screen debug console for iPad testing | https://github.com/Ark2000/PankuConsole | MIT, GDScript |

## Medical content (reference only)

No usable open-source paramedic game exists. The GitHub matches are tiny, unlicensed or for Unity.

- **Infirmary Integrated** (https://github.com/tanjera/infirmary-integrated, Apache-2.0) is a medical device simulator for training: cardiac monitor rhythms, defibrillator and vital signs. It is C#, so it cannot run in Xogot. Use it as a reference for how rhythms and vitals change, then rewrite small parts in GDScript, keeping the Apache notice.
- **BioGears** (https://github.com/BioGearsEngine/core, Apache-2.0) is a full body physiology engine in C++. It is too heavy for this game. Only consider it if the game needs realistic vitals responses.
- Any medical content still needs a qualified clinician to check it before students rely on it.

## Free 3D models and textures (CC0)

CC0 means no credit is required, though crediting is polite.

- Kenney: https://kenney.nl/assets. Its starter kits are also MIT Godot projects, for example https://github.com/KenneyNL/Starter-Kit-FPS.
- Quaternius: https://quaternius.com (low-poly characters and props)
- Poly Haven: https://polyhaven.com (textures, HDRIs, models)
- ambientCG: https://ambientcg.com (textures)

Check each asset's own page for its license before using it. Do not use models of real branded equipment (see the KOLE note in the feature plan).

## Do not use

| Project | Reason |
|---|---|
| `warrpy/Godot-VehicleBody-Demo` | GPL-3.0 |
| `Bytezz/godot-virtual_joystick` | GPL-3.0 |
| `MacdonaldRobinson/Godot4-3D-inventory-and-interaction-system` | No license |
| `gdquest-demos/godot-4-3d-third-person-controller` | Mixed license terms (NOASSERTION). Read its license file first. |
| GDExtension or C# add-ons (Terrain3D, godot-sqlite, Rapier physics and others) | May not run in Xogot |

## Suggested order

1. Virtual Joystick, to fix review 2 N6. Smallest change with the biggest payoff on iPad.
2. Read COGITO's `ImpactAttributeDamage.gd` while building the KOLE crack check (N11). Add the hit cooldown.
3. Use the `physics_tests` and `rigidbody_character` demos as test scenes for stretcher bumps and pushes (N1 to N4).
4. Add menus from Maaack's template once there is more than one scene.
5. Add dialogue and vitals later, when patients are added.

## Copy checklist for each borrowed piece

- [ ] License is MIT, CC0, Apache-2.0 or Unlicense.
- [ ] Only GDScript files, scenes and resources. No `.gdextension`, `.dll`, `.so`, `.dylib` or `.cs` files.
- [ ] Folder placed in `addons/<name>/` with its LICENSE file kept.
- [ ] Entry added to `THIRD_PARTY_NOTICES.md`.
- [ ] Opens, enables and runs in Xogot on iPad.
- [ ] One piece per commit, so it can be reverted.
