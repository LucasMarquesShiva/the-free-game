import importlib.util
import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / "tools/prepare_approved_web.py"
spec = importlib.util.spec_from_file_location("prepare_approved_web", TOOL)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WebShellTests(unittest.TestCase):
    def test_uses_explicit_asset_project(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            page = root / 'index.html'
            page.write_text('const GODOT_CONFIG = {"executable":"index"};\nconst GODOT_THREADS_ENABLED = false;')
            for path, data in [('previews/hall.png', b'prepared-hall'), ('people-previews/servant.png', b'prepared-servant')]:
                asset = root / 'assets/approved' / path
                asset.parent.mkdir(parents=True, exist_ok=True)
                asset.write_bytes(data)
            module.prepare(page, root)
            for kind, data in [('hall', b'prepared-hall'), ('servant', b'prepared-servant')]:
                name = f'vila-{kind}-{hashlib.sha256(data).hexdigest()[:12]}.png'
                self.assertEqual(data, (root / name).read_bytes())
                self.assertIn(name, page.read_text())

    def test_export_fingerprint_stays_compatible_with_shell(self):
        exporter_spec = importlib.util.spec_from_file_location("export_approved", TOOL.with_name("export_approved.py"))
        exporter = importlib.util.module_from_spec(exporter_spec)
        exporter_spec.loader.exec_module(exporter)
        payload = b"game-payload-test"
        config = {"executable":"index", "mainPack":"index.pck", "fileSizes":{"index.pck":len(payload)}}
        with tempfile.TemporaryDirectory() as folder:
            page = Path(folder) / "index.html"
            page.write_text(f"const GODOT_CONFIG = {json.dumps(config)};\nconst GODOT_THREADS_ENABLED = false;")
            (page.parent / "index.pck").write_bytes(payload)
            module.prepare(page)
            build = exporter.fingerprint_web_pack(page)
            release = json.loads((page.parent / "release.json").read_text())
            self.assertEqual(hashlib.sha256(payload).hexdigest()[:12], build)
            self.assertEqual(payload, (page.parent / release["pack"]).read_bytes())
            self.assertIn(release["pack"], page.read_text())
            self.assertEqual(hashlib.sha256(page.read_bytes()).hexdigest(), release["web_shell_sha256"])

    def test_preserves_engine_config_and_is_repeatable(self):
        config = {"executable":"index", "mainPack":"vila-example.pck", "args":["<example>"], "fileSizes":{"index.wasm":123, "vila-example.pck":456}, "focusCanvas":True}
        with tempfile.TemporaryDirectory() as folder:
            page = Path(folder) / "index.html"
            page.write_text(f"const GODOT_CONFIG = {json.dumps(config)};\nconst GODOT_THREADS_ENABLED = false;")
            module.prepare(page)
            before = {p.name:p.read_bytes() for p in Path(folder).iterdir()}
            module.prepare(page)
            self.assertEqual(before, {p.name:p.read_bytes() for p in Path(folder).iterdir()})
            html = page.read_text()
            exported = json.loads(re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", html).group(1))
            self.assertEqual(config, exported)
            self.assertIn('lang="pt-BR"', html)
            self.assertNotIn("@@", html)
            self.assertNotIn("<example>", html)
            for name in re.findall(r'(?:src|href)="(vila-[^"]+)"', html):
                self.assertTrue((page.parent / name).is_file(), name)

    def test_refuses_unknown_export_without_overwriting_it(self):
        with tempfile.TemporaryDirectory() as folder:
            page = Path(folder) / "index.html"
            original = "<html>not an exported game</html>"
            page.write_text(original)
            with self.assertRaises(ValueError):
                module.prepare(page)
            self.assertEqual(original, page.read_text())


if __name__ == "__main__":
    unittest.main()
