# First changes

Start from a fork or a downloaded copy, run the unchanged game, and change one
thing at a time. The Godot editor provides search, script navigation and a live
debugger; no generator account is needed.

## Adjust a construction cost

Open `game/simulation/approved_sim.gd` and find the building definitions and cost
validation. Follow the definitions into `village_sim.gd` when inherited. Change
both wood and stone deliberately. Run the simulation tests and place that
building in a new game. Check resource reservation, delivery and completion.

## Change the ground or a building

Start in `presentation/approved_terrain.gd`, `approved_materials.gd` or
`approved_buildings.gd`. Geometry is built in code, with resources in `assets/`.
Use the Godot inspector and the model helpers to trace dimensions and materials.
Keep the collision/placement footprint in the simulation consistent with the model.

Original concept sheets are in `art/catalogo-visual-v1/` and `art/conceitos-v1/`.
They provide the visual direction; changing a sheet does not update the 3D model.

## Add a profession or a building

Trace an existing example through simulation definitions, job assignment,
production, HUD entries and world rendering. Add a simulation test that proves
the new job actually changes resources and completes under valid road conditions.
Check what the player sees when inputs, workers or access are missing.

## Change the interface or loading screen

The in-game interface is in `game/ui/approved_hud.gd`. The browser loading screen
is in `tools/web-shell/`. Run `export-web` after editing the loading screen; it
is embedded into the exported HTML by `tools/prepare_web.py`.

## Change the project name in your fork

Change `config/name` in `game/project.godot`, visible HUD labels and the browser
shell title. Keep the required license and artwork attribution. Review the
save-storage location when renaming the application: changing the custom user-data directory moves saves on desktop and Web. Preserve it for compatible updates, or choose a new directory deliberately for an independent fork.
