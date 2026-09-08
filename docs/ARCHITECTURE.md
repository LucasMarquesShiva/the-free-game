# Architecture

The active entry scene is `game/scenes/approved.tscn`. The word `approved` is a
stable internal name; renaming it is not required to extend The Free Game.

| File | Responsibility |
| --- | --- |
| `presentation/approved_game.gd` | Input, commands, simulation clock, saving and scene orchestration |
| `simulation/approved_sim.gd` | Current village rules and economic simulation |
| `simulation/village_sim.gd` | Shared simulation base used by the current and earlier prototypes |
| `core/simulation_clock.gd` | Fixed-step clock, decoupled from drawing |
| `presentation/approved_world.gd` | 3D world and visual updates from simulation state |
| `presentation/approved_buildings.gd` | Current building models |
| `presentation/approved_people.gd` | Current villagers and visible motion |
| `presentation/approved_terrain.gd` | Ground, roads and landscape |
| `presentation/approved_crop_growth.gd` | Visible crop growth |
| `ui/approved_hud.gd` | Player menus, resources, school and notifications |

Paths in this table are relative to `game/`. Older `frontier`, `illustrated`
and other prototype files are retained as development material. Start with the
active scene and the `approved_*` files. Some shared helpers are still used;
check references before removing a historical module.

## Simulation and rendering

The simulation owns resources, jobs, paths, construction progress and production.
The view reads that state to update models and animation. Player actions become
simulation commands; avoid modifying inventory or jobs from a visual script.
The clock uses fixed simulation steps, so frame rate should not change the economy.

Current visual assets combine procedural 3D geometry, materials, textures and
previews. High-resolution concept illustrations live separately in `art/`;
those sheets are visual references, not automatically rigged 3D models.

## Rules to preserve

- New games begin with the main building, instructor school and a paved plaza.
- Idle civilians gather in the plaza; the player does not command individuals.
- Placing a building creates a job. Available servants deliver goods
  and builders work autonomously. Missing workers must be visible to the player.
- Completed roads connect building deliveries. Planned road tiles permit
  parallel material delivery and construction, not one sequential tile at a time.
- School spends gold and spawns a new civilian. Workers eat at the inn.
- The storehouse is the physical pick/drop node once built; the hall is only the fallback depot.
- Woodcutters harvest map trees into trunks; the sawmill turns trunks into timber.
- A quarry requires a stone deposit. Barracks consume a walking recruit plus weapon wares.
- Crop growth and harvesting are visible; harvested goods must be transported.
- Inventory must remain consistent when jobs are assigned, canceled or restored.

## Saves

Manual and automatic saves use Godot's `user://` storage. In the browser they
belong to that origin and browser profile, not to an online account. Legacy
`vale-approved-*` filenames and the configured custom user-data directory are intentionally retained for compatibility. Changing the display name does not change that storage path.
Do not rename save keys casually. Inspect the serializer in `approved_sim.gd`
and the migration/round-trip tests before changing schema.

## Checks

`python tools/dev.py test` imports the project, then runs the main simulation
suite, harvest-delivery regressions and parked-servant regressions. The scripts
report failures and exit nonzero. Other files in `game/tests/` include historical
experiments and rendering harnesses; they are not all part of this release gate.
