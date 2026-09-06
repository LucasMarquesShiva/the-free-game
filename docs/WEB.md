# Build and publish a browser version

Install Godot 4.7.2 and its matching export templates. Then, from the repository:

```sh
python tools/dev.py export-web
python tools/dev.py serve --port 8000
```

Open `http://127.0.0.1:8000/`. This address only works on the developer's computer.
The export helper temporarily selects Godot's Compatibility renderer for WebGL;
the editable desktop project keeps its existing renderer.

## Public hosting

Upload all of `builds/web/` to an HTTPS static host and use its public URL.
The HTML, loader JavaScript, WASM, PCK, preview images and stylesheet must remain
together with the generated filenames. Use `application/wasm` for `.wasm` files.
This preset disables engine threads, so it does not depend on SharedArrayBuffer.
The development server supplies isolation headers as well.

Check the host's single-file and total-size limits first: uncompressed game data
and the engine can each be tens of megabytes. The project does not require
server-side game code, a database, API keys or a particular hosting vendor.
Your hosting provider's terms and limits still apply.

Keep license notices alongside your distributed game. `export-web` includes the
project and artwork license files in the output, in addition to Godot's own notices.

## Updates and saves

Keep the same public origin and the configured user-data directory when you want users to retain browser saves. A fork
hosted at a different address has separate local storage. Clearing site data or
using another browser also starts with separate saves. There is no cloud sync.

Before sharing, open a fresh browser session, build a short road, train a worker,
save, reload and load the game. Check the browser console for errors. Test a
machine with modest graphics hardware if that is part of your intended audience.

## Optional packaging for hosts with small file limits

```sh
python tools/pack_static.py builds/web builds/static
```

Use an empty output folder. This verified packaging step splits engine and game
data into content-addressed gzip parts, validates their hashes, and creates a
loader that reconstructs them. Upload all of `builds/static/` together. It requires
a browser with DecompressionStream support. Ordinary hosts can use the normal
`builds/web/` export instead. The transport regression checks can be run with
`node tools/test-transport.mjs` when Node.js is available; Node is optional for
game development.
