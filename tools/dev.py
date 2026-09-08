#!/usr/bin/env python3
"""Portable, dependency-free development commands for The Free Game."""

from __future__ import annotations

import argparse
import functools
import http.server
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_VERSION = "4.7.2"
TEST_SCRIPTS = (
    "tests/test_approved.gd",
    "tests/test_approved_harvest_delivery.gd",
    "tests/test_parked_servants.gd",
    "tests/test_kam_gaps.gd",
    "tests/test_harvest_map.gd",
)


class DevError(Exception):
    """An actionable setup or command failure."""


def executable_path(value: str) -> Path | None:
    """Resolve a binary, command name, or macOS application bundle."""
    candidate = Path(value).expanduser()
    if candidate.suffix.lower() == ".app":
        candidate /= "Contents/MacOS/Godot"
    if candidate.is_file() and (os.name == "nt" or os.access(candidate, os.X_OK)):
        return candidate.resolve()
    found = shutil.which(value)
    return Path(found).resolve() if found else None


def find_godot(explicit: str | None = None) -> Path:
    """An explicit selection takes precedence and never silently falls back."""
    selection = explicit or os.environ.get("GODOT_BIN")
    if selection:
        found = executable_path(selection)
        if found:
            return found
        origin = "--godot" if explicit else "GODOT_BIN"
        raise DevError(f"{origin} does not identify an executable: {selection}")
    candidates = ["godot", "godot4"]
    if sys.platform == "darwin":
        candidates.extend((
            "/Applications/Godot.app",
            str(Path.home() / "Applications/Godot.app"),
        ))
    for candidate in candidates:
        found = executable_path(candidate)
        if found:
            return found
    raise DevError(
        f"Godot {EXPECTED_VERSION} was not found. Install the matching Godot editor "
        "and export templates from https://godotengine.org/download/archive/, "
        "then pass --godot /path/to/Godot, set GODOT_BIN, or put godot/godot4 on PATH."
    )


def command_environment(root: Path) -> dict[str, str]:
    env = os.environ.copy()
    cache = root / ".local-data/cache"
    cache.mkdir(parents=True, exist_ok=True)
    env["XDG_CACHE_HOME"] = str(cache)
    # Keep normal data/config paths so installed export templates remain visible.
    return env


def verify_version(engine: Path, env: dict[str, str]) -> str:
    result = subprocess.run(
        [str(engine), "--version"], capture_output=True, text=True, env=env,
        check=False,
    )
    version = result.stdout.strip()
    if result.returncode:
        raise DevError(f"Godot --version failed: {result.stderr.strip() or version}")
    if not re.match(r"^" + re.escape(EXPECTED_VERSION) + r"(?:[.\s-]|$)", version):
        raise DevError(
            f"Expected Godot {EXPECTED_VERSION}; found {version or 'no version output'} "
            f"at {engine}. Select the matching editor with --godot or GODOT_BIN."
        )
    return version


def run_engine(engine: Path, project: Path, env: dict[str, str], *args: str) -> int:
    result = subprocess.run(
        [str(engine), "--path", str(project), *args], cwd=project,
        env=env, check=False,
    )
    return result.returncode if result.returncode >= 0 else 1


def import_project(engine: Path, project: Path, env: dict[str, str]) -> int:
    return run_engine(engine, project, env, "--headless", "--editor", "--import")


def check_project(project: Path) -> None:
    if not (project / "project.godot").is_file():
        raise DevError(f"Godot project is missing: {project / 'project.godot'}")


def test_project(engine: Path, project: Path, env: dict[str, str]) -> int:
    for script in TEST_SCRIPTS:
        if not (project / script).is_file():
            raise DevError(f"Required simulation test is missing: {project / script}")
    result = import_project(engine, project, env)
    if result:
        return result
    failed = []
    for script in TEST_SCRIPTS:
        print(f"Running {script}", flush=True)
        result = run_engine(engine, project, env, "--headless", "--script", f"res://{script}")
        if result:
            failed.append(script)
    if failed:
        print("Failed: " + ", ".join(failed), file=sys.stderr)
        return 1
    print("All three simulation test scripts passed.")
    return 0


def set_project_value(text: str, section: str, key: str, value: str) -> str:
    """Change one section's property without rewriting unrelated project settings."""
    match = re.search(r"^\[" + re.escape(section) + r"\]\s*$", text, re.MULTILINE)
    entry = f"{key}={value}\n"
    if not match:
        return text.rstrip() + f"\n\n[{section}]\n" + entry
    start = match.end()
    next_section = re.search(r"^\[", text[start:], re.MULTILINE)
    end = start + next_section.start() if next_section else len(text)
    block = text[start:end]
    pattern = r"^" + re.escape(key) + r"\s*=.*(?:\n|$)"
    if re.search(pattern, block, re.MULTILINE):
        block = re.sub(pattern, lambda _: entry, block, count=1, flags=re.MULTILINE)
    else:
        block = block.rstrip() + "\n" + entry + "\n"
    return text[:start] + block + text[end:]


def prepare_export_project(source: Path, destination: Path) -> None:
    """Mirror source assets and import metadata, omitting generated cache directories."""
    generated = {".godot", "builds", "cache", ".cache", "__pycache__", ".git", ".local-data"}

    def ignore(directory: str, names: list[str]) -> list[str]:
        return [name for name in names if name == ".DS_Store" or (
            name in generated and (Path(directory) / name).is_dir()
        )]

    shutil.copytree(source, destination, ignore=ignore)
    settings = destination / "project.godot"
    text = settings.read_text(encoding="utf-8")
    text = set_project_value(text, "application", "config/features",
                             'PackedStringArray("4.7", "GL Compatibility")')
    for key in ("renderer/rendering_method", "renderer/rendering_method.mobile",
                "renderer/rendering_method.web"):
        text = set_project_value(text, "rendering", key, '"gl_compatibility"')
    settings.write_text(text, encoding="utf-8")


def export_web(engine: Path, root: Path, env: dict[str, str]) -> int:
    source = root / "game"
    if not (source / "export_presets.cfg").is_file():
        raise DevError(f"Missing {source / 'export_presets.cfg'}; a Web export preset is required.")
    output = root / "builds/web/index.html"
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="the-free-game-web-") as directory:
        project = Path(directory) / "game"
        prepare_export_project(source, project)
        result = import_project(engine, project, env)
        if result:
            return result
        result = run_engine(engine, project, env, "--headless", "--export-release", "Web", str(output))
        if result:
            print(f"Web export failed. Check that Godot {EXPECTED_VERSION} export templates "
                  "are installed and the Web preset is valid.", file=sys.stderr)
            return result
        if not output.is_file():
            raise DevError(f"Godot completed without producing {output}")
        prepare = root / "tools/prepare_web.py"
        if prepare.is_file():
            result = subprocess.run(
                [sys.executable, str(prepare), str(output), "--assets-project", str(source)],
                cwd=root, env=env, check=False,
            )
            if result.returncode:
                return result.returncode if result.returncode >= 0 else 1
    print(f"Exported {output}")
    return 0


class LocalWebHandler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
    }

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


def serve(root: Path, port: int) -> int:
    directory = root / "builds/web"
    if not (directory / "index.html").is_file():
        raise DevError("No web build found. Run python tools/dev.py export-web first.")
    handler = functools.partial(LocalWebHandler, directory=str(directory))
    with http.server.ThreadingHTTPServer(("127.0.0.1", port), handler) as server:
        print(f"Serving http://127.0.0.1:{server.server_port}/ (Ctrl+C to stop)", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


def port_number(value: str) -> int:
    try:
        port = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("port must be an integer") from error
    if not 1 <= port <= 65535:
        raise argparse.ArgumentTypeError("port must be between 1 and 65535")
    return port


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", help="Godot executable or .app (otherwise GODOT_BIN or PATH)")
    commands = parser.add_subparsers(dest="command", required=True)
    descriptions = {
        "doctor": "check the project and required Godot version",
        "run": "launch the game",
        "test": "import and run the three headless simulation tests",
        "export-web": "export a temporary Compatibility copy to builds/web",
        "serve": "serve builds/web on 127.0.0.1",
    }
    for name, description in descriptions.items():
        command = commands.add_parser(name, help=description)
        command.add_argument("--godot", default=argparse.SUPPRESS,
                             help="Godot executable or .app (also accepted before the command)")
        if name == "serve":
            command.add_argument("--port", type=port_number, default=8000)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        if args.command == "serve":
            return serve(ROOT, args.port)
        project = ROOT / "game"
        check_project(project)
        engine = find_godot(args.godot)
        env = command_environment(ROOT)
        version = verify_version(engine, env)
        if args.command == "doctor":
            print(f"Godot: {version}\nExecutable: {engine}\nProject: {project}\n"
                  f"Cache: {env['XDG_CACHE_HOME']}\n"
                  f"Web export requires matching {EXPECTED_VERSION} export templates.")
            missing = [script for script in TEST_SCRIPTS if not (project / script).is_file()]
            if missing:
                raise DevError("Missing simulation tests: " + ", ".join(missing))
            return 0
        if args.command == "run":
            result = import_project(engine, project, env)
            return result or run_engine(engine, project, env)
        if args.command == "test":
            return test_project(engine, project, env)
        return export_web(engine, ROOT, env)
    except (DevError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
