"""JSON mission specs for a later TSK-style teaching loop (no Godot needed)."""

from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]
MISSION = ROOT / "game" / "content" / "missions" / "tsk-01.json"

KAM_M1_ALLOWED = {"hall", "training", "inn", "lumber", "quarry"}
KAM_M1_HIDDEN = {"farm", "vineyard", "winery", "barracks", "sawmill", "house"}
KAM_M1_ROLES = {"builder", "servant", "instructor", "lumberjack", "stonecutter"}


class Tsk01MissionSpecTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MISSION.is_file(), f"missing {MISSION}")
        self.data = json.loads(MISSION.read_text())

    def test_identity_and_save_key(self):
        self.assertEqual(self.data["id"], "tsk-01")
        self.assertEqual(self.data["save_mission_key"], "tsk-01")
        self.assertTrue(self.data.get("briefing"))

    def test_available_set_is_storehouse_school_inn_wood_stone(self):
        available = set(self.data["available_buildings"])
        self.assertTrue(KAM_M1_ALLOWED <= available)
        self.assertTrue(available.isdisjoint(KAM_M1_HIDDEN))
        self.assertEqual(set(self.data["available_roles"]), KAM_M1_ROLES)

    def test_start_is_hall_only_with_low_stock(self):
        buildings = self.data["start"]["buildings"]
        self.assertEqual([b["kind"] for b in buildings], ["hall"])
        stock = self.data["start"]["stock"]
        self.assertLess(stock["wood"], 80)
        self.assertLess(stock["stone"], 80)
        self.assertEqual(stock["grapes"], 0)
        self.assertEqual(stock["wine"], 0)

    def test_win_is_not_the_sandbox_wine_checklist(self):
        kinds = {row["kind"] for row in self.data["objectives"] if row.get("op") == "completed"}
        self.assertEqual(kinds, {"training", "inn", "lumber", "quarry"})
        self.assertTrue(self.data["win"].get("all_objectives"))
        blob = json.dumps(self.data)
        self.assertNotIn("wine_delivered", blob)
        self.assertNotIn("12", json.dumps(self.data["objectives"]))


if __name__ == "__main__":
    unittest.main()
