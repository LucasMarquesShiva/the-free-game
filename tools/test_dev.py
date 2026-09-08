"""Run with python -m unittest discover -s tools -p test_dev.py (no Godot needed)."""

from pathlib import Path
import os
import subprocess
import tempfile
import unittest
from unittest import mock

import dev


class DeveloperCliTests(unittest.TestCase):
    def test_engine_precedence_and_invalid_explicit_selection(self):
        with mock.patch.dict(os.environ, {"GODOT_BIN": "configured-engine"}), \
                mock.patch.object(dev, "executable_path", return_value=Path("selected")) as resolve:
            self.assertEqual(dev.find_godot("explicit-engine"), Path("selected"))
            resolve.assert_called_once_with("explicit-engine")
            resolve.reset_mock()
            dev.find_godot()
            resolve.assert_called_once_with("configured-engine")
        with mock.patch.object(dev, "executable_path", return_value=None) as resolve:
            with self.assertRaisesRegex(dev.DevError, "--godot"):
                dev.find_godot("missing-engine")
            resolve.assert_called_once_with("missing-engine")

    def test_path_fallback_and_exact_version(self):
        with mock.patch.dict(os.environ, {}, clear=True), \
                mock.patch.object(dev, "executable_path", side_effect=[None, Path("godot4")]):
            self.assertEqual(dev.find_godot(), Path("godot4"))
        with mock.patch.object(dev.subprocess, "run") as run:
            run.return_value = subprocess.CompletedProcess([], 0, "4.7.2.stable.official\n", "")
            self.assertEqual(dev.verify_version(Path("godot"), {}), "4.7.2.stable.official")
            run.return_value.stdout = "4.7.20.stable.official"
            with self.assertRaisesRegex(dev.DevError, "Expected Godot 4.7.2"):
                dev.verify_version(Path("godot"), {})

    def test_global_option_positions_and_serve_routing(self):
        self.assertEqual(dev.parse_args(["--godot", "a", "test"]).godot, "a")
        self.assertEqual(dev.parse_args(["test", "--godot", "b"]).godot, "b")
        with mock.patch.object(dev, "serve", return_value=0) as serve, \
                mock.patch.object(dev, "find_godot") as find:
            self.assertEqual(dev.main(["serve", "--port", "9011"]), 0)
            serve.assert_called_once_with(dev.ROOT, 9011)
            find.assert_not_called()

    def test_simulation_failure_is_nonzero_and_other_tests_still_run(self):
        with tempfile.TemporaryDirectory() as folder:
            project = Path(folder)
            for script in dev.TEST_SCRIPTS:
                file = project / script
                file.parent.mkdir(exist_ok=True)
                file.touch()
            with mock.patch.object(dev, "run_engine", side_effect=[0, 0, 2, 0, 0]) as run:
                self.assertEqual(dev.test_project(Path("godot"), project, {}), 1)
                self.assertEqual(run.call_count, 5)
                self.assertEqual(run.call_args.args[-1], "res://tests/test_kam_gaps.gd")

    def test_temporary_web_export_preserves_sources_and_runs_preparation(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "game"
            source.mkdir()
            original = '[application]\nconfig/features=PackedStringArray("4.7", "Forward Plus")\n\n'
            original += '[rendering]\nrenderer/rendering_method="forward_plus"\n'
            (source / "project.godot").write_text(original)
            (source / "export_presets.cfg").write_text('[preset.0]\nname="Web"\n')
            for relative in ("assets/icon.svg.import", "scripts/sim.gd.uid", "meshes/house.glb", ".import/keep"):
                path = source / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"preserve-exactly")
            for directory in (".godot", "builds", "cache"):
                (source / directory).mkdir()
                (source / directory / "generated").touch()
            (root / "tools").mkdir()
            (root / "tools/prepare_web.py").touch()
            temporary_projects = []

            def engine_run(engine, project, env, *args):
                temporary_projects.append(project)
                self.assertNotEqual(project, source)
                for relative in ("assets/icon.svg.import", "scripts/sim.gd.uid", "meshes/house.glb", ".import/keep"):
                    self.assertEqual((project / relative).read_bytes(), b"preserve-exactly")
                for directory in (".godot", "builds", "cache"):
                    self.assertFalse((project / directory).exists())
                self.assertIn('renderer/rendering_method="gl_compatibility"',
                              (project / "project.godot").read_text())
                if "--export-release" in args:
                    self.assertEqual(args[-2], "Web")
                    Path(args[-1]).write_text("web build")
                return 0

            with mock.patch.object(dev, "run_engine", side_effect=engine_run) as run, \
                    mock.patch.object(dev.subprocess, "run", return_value=subprocess.CompletedProcess([], 0)) as prepare:
                self.assertEqual(dev.export_web(Path("godot"), root, {}), 0)
                self.assertEqual(run.call_args_list[0].args[3:], ("--headless", "--editor", "--import"))
                self.assertEqual(prepare.call_args.args[0][-2:], ["--assets-project", str(source)])
            self.assertEqual((source / "project.godot").read_text(), original)
            self.assertTrue((source / ".godot/generated").exists())
            self.assertTrue((root / "builds/web/index.html").is_file())
            self.assertTrue(temporary_projects)
            self.assertTrue(all(not project.exists() for project in temporary_projects))


if __name__ == "__main__":
    unittest.main()
