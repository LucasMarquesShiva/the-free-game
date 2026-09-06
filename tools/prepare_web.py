#!/usr/bin/env python3
"""Build the Portuguese loading shell while preserving Godot's export config."""
from pathlib import Path
import hashlib
import json
import re
import sys
import argparse


def prepare(page: Path, assets_project: Path | None = None) -> None:
    source = Path(__file__).resolve().parent
    project = assets_project if assets_project is not None else source.parent / "game"
    html = page.read_text(encoding="utf-8")
    config_match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html)
    threads_match = re.search(r"const GODOT_THREADS_ENABLED = (true|false);", html)
    if not config_match or not threads_match:
        raise ValueError("Configuração da exportação Godot ausente; página preservada.")
    config = json.loads(config_match.group(1))
    if config.get("executable") != "index":
        raise ValueError("A exportação aprovada precisa usar index.html.")
    old_pack = config.get("mainPack") or config["executable"] + ".pck"
    pack = page.parent / old_pack
    digest = hashlib.sha256(pack.read_bytes()).hexdigest()
    name = f"the-free-game-{digest[:12]}.pck"
    config["mainPack"] = name
    config.setdefault("fileSizes", {}).pop(old_pack, None)
    config["fileSizes"][name] = pack.stat().st_size
    if name != old_pack:
        pack.replace(page.parent / name)
    tokens = {"CONFIG":json.dumps(config, ensure_ascii=False, separators=(",", ":")).replace("<", "\\u003c"), "THREADS":threads_match.group(1)}
    assets = {
        "CSS":source / "web-shell/approved.css",
        "JS":source / "web-shell/approved.js",
        "HALL":project / "assets/approved/previews/hall.png",
        "SERVANT":project / "assets/approved/people-previews/servant.png",
    }
    data = {key:path.read_bytes() for key,path in assets.items()}
    template = (source / "web-shell/approved.html").read_text(encoding="utf-8")
    for key, path in assets.items():
        name = f"vila-{key.lower()}-{hashlib.sha256(data[key]).hexdigest()[:12]}{path.suffix}"
        tokens[key] = name
    for key,value in tokens.items():
        template = template.replace(f"@@{key}@@", value)
    if re.search(r"@@[A-Z]+@@", template):
        raise ValueError("Marcador de template não resolvido; página preservada.")
    for key in assets:
        (page.parent / tokens[key]).write_bytes(data[key])
    page.write_text(template, encoding="utf-8")
    root = source.parent
    notices = [root / "LICENSE", root / "LICENSE-ASSETS.md", root / "THIRD_PARTY_NOTICES.md",
               root / "licenses/CC-BY-4.0.txt", root / "licenses/GODOT-THIRD-PARTY.txt", project / "GODOT-LICENSE.txt"]
    for notice in notices:
        (page.parent / notice.name).write_bytes(notice.read_bytes())
    pack = page.parent / config["mainPack"]
    digest = hashlib.sha256(pack.read_bytes()).hexdigest()
    release = {"name": "The Free Game", "version": "0.4.4", "build": digest[:12],
               "pack": config["mainPack"], "sha256": digest}
    (page.parent / "release.json").write_text(json.dumps(release, indent=2) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('page', type=Path)
    parser.add_argument('--assets-project', type=Path)
    args = parser.parse_args()
    prepare(args.page, args.assets_project)
