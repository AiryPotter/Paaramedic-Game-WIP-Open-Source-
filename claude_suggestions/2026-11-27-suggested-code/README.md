# Claude Code's Suggested Code (package)

Start with **`CHERRY_PICK.md`**. It lists every code suggestion, its status and which file has the code.

```
CHERRY_PICK.md      Checklist: tick what you want, then hand it to ChatGPT
fixes/              Fixes for the current game, as exact find-and-replace steps
new_files/          Complete files used by some fixes
starters/           New scripts for planned features (driving, loading, stair chair, game state)
applied/            Archive of earlier suggestions that are already in the game
```

- Checked against game code at `9ae595b` on `xogot-project-upload`. If the game has changed since, some "find" text may not match; ChatGPT should adapt it.
- **No code here was run.** Test every piece in Xogot on the iPad.
- Everything is plain GDScript, so it works in Xogot.
- The empty `.gdignore` file tells Godot to skip this folder. Without it, Godot would load these `.gd` files as part of the game, and `new_files/training_patient.gd` would clash with the real one. Copy a script into the game's own folders only when you apply it.
- No clinical content is included. Medical values come later from the maintainer's service protocols, with clinical review.
