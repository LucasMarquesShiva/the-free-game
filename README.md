# The Free Game

**Lucas Marques, from Shiva**

An open medieval village-building game. Plan roads and buildings, train workers,
and watch the village work autonomously. Built with Godot 4.7.2 and GDScript.

[Play in your browser](https://vale-dos-vinhedos.lucas579686.chatgpt.site/) ·
[Português](README.pt-BR.md) · [简体中文](README.zh-CN.md) · [Contribute](CONTRIBUTING.md) · [Architecture](docs/ARCHITECTURE.md)

![The main building](game/assets/approved/previews/hall.png)

## Get started in the editor

1. Download this repository with **Code → Download ZIP**, or fork and clone it.
2. Install the **standard Godot 4.7.2 editor** from the
   [official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).
   The .NET edition is not needed.
3. In Godot, choose **Import**, select `game/project.godot`, and open it.
4. Wait for the first asset import, then press **F6** on `scenes/approved.tscn`,
   or **F5** to run the main scene.

The source includes the game, runtime textures and meshes, original concept
art, tests, and browser export tooling. No account, API key, paid service,
or image-generation service is required to develop or play locally.

## Commands

Optional command-line workflow requires Python 3.10+ and the same Godot editor.
Use `python3` on macOS/Linux or `py` on Windows if `python` is unavailable.

```sh
python tools/dev.py doctor
python tools/dev.py run
python tools/dev.py test
python tools/dev.py export-web
python tools/dev.py serve --port 8000
```

If Godot is not on your PATH, add `--godot "/path/to/Godot"` to any engine
command, or set `GODOT_BIN` to its executable. A macOS `.app` path also works.
For browser export, install the **4.7.2 export templates** through Godot's
**Editor → Manage Export Templates** first.

The export command creates a temporary Compatibility-renderer copy, preserving
the desktop project's renderer. Output goes to `builds/web/`. Open
`http://127.0.0.1:8000/` after `serve`; do not open the HTML as a local file.
To publish your own version, upload **all files** from `builds/web/` to a static
HTTPS host that supports the exported file sizes. See [web publishing](docs/WEB.md).

## What is playable

This is a desktop-browser beta, not a finished commercial release. It begins
with a main building, an instructor school, a plaza, and villagers. You draw
roads, place buildings, train professions, and expand the economy.

- Civilians accept tasks automatically and gather in the plaza when idle.
- Servants deliver materials; builders construct buildings and road tiles.
- Every building requires wood and stone.
- Gardens visibly grow and food is harvested and transported.
- The economic chain includes vineyards and a winery.
- The school opens the training panel when clicked.
- Manual saves and autosaves are local to each browser/device.

There is no army, multiplayer, cloud save, or server economy in this beta.
Mobile controls and performance still need dedicated work. Concept art includes
ideas for later versions; it is not a promise that all depicted features exist.

## Find your way around

| Folder | Contents |
| --- | --- |
| `game/` | Complete editable Godot project |
| `game/simulation/` | Civilian autonomy, roads, building, production, saves |
| `game/presentation/` | 3D scene, terrain, people, procedural building models |
| `game/ui/` | HUD, training, build menus, player feedback |
| `game/assets/` | Runtime images, textures, mesh resources, shaders, previews |
| `game/tests/` | Simulation checks and development render harnesses |
| `art/` | Original art, concept sheets, visual specifications and prompts |
| `tools/` | Portable development commands and browser loading screen |
| `docs/` | Architecture, customization and publication guides |

## Reuse and credit

**Code, tools and documentation: MIT. Original artwork: CC BY 4.0.**
You may modify, distribute and use them commercially under those licenses.
Keep the MIT notice with the code. Credit original artwork to
**Lucas Marques, from Shiva**, link CC BY 4.0, and indicate changes.

See [LICENSE](LICENSE), [LICENSE-ASSETS.md](LICENSE-ASSETS.md) and
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Engine/dependency notices retain
their own required attribution. Some artwork was generated with AI and is
included as editable project material and design references.

A suggested artwork credit is:
> Original artwork: Lucas Marques, from Shiva — The Free Game.
> CC BY 4.0. Changes: [describe your changes, if any].

[Browse the original art catalog / Abrir o catálogo de artes](art/catalogo-visual-v1/catalogo.html) — download the repository and open this HTML locally.
