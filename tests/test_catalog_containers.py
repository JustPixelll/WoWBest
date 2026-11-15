import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from catalog_containers import container_routes


def observation(items, world_map=None, instance=0):
    return {"items": {str(i): {"drops": 1} for i in items},
            "positions": [{"instance": instance, "uiMap": world_map}] if world_map else []}


class ContainerTests(unittest.TestCase):
    def test_two_step_fishing_and_chest_access(self):
        with tempfile.TemporaryDirectory() as temp:
            builds = []
            objects = {"2857": {"type": 3, "name": "Solid Chest"},
                       "17": {"type": 3, "name": "Solid Chest", "questItems": [99]}}
            contents = observation([6554, 2987, 999])
            contents["items"]["2987"]["quest"] = True
            observations = (
                {"fishing:1413": observation([20708], 1413, 1),
                 "fishing:1434|group": observation([21150], 1434),
                 "object:2857|spell:3365": observation([4041], 1434),
                 "object:17|spell:3365": observation([1], 1434),
                 "object:2857|spell:6477": observation([2], 1434)},
                {"item:20708": contents, "item:21150|group": observation([863]),
                 "item:6356": observation([3]), "item:777": observation([4]),
                 "object:2857|spell:3365|group": observation([5], 1434, 36),
                 "object:2857|spell:3365": observation([6])},
            )
            for n, sources in enumerate(observations):
                path = Path(temp) / str(n)
                path.mkdir()
                (path / "loot.json").write_text(json.dumps({"sources": sources}))
                (path / "object_details.enUS.json").write_text(json.dumps({"objects": objects}))
                builds.append(path)
            items = {i: {} for i in (1, 2, 3, 4, 5, 6, 863, 4041, 6554, 2987)}
            result = dict(container_routes(builds, items))
        self.assertEqual(set(result), {863, 4041, 6554})
        self.assertIn("Solid Chest, Stranglethorn Vale", result[4041]["source"])
        self.assertNotIn("professionID", result[4041])
        self.assertEqual(result[6554]["acquireProfessionID"], 356)
        self.assertEqual(result[6554]["professionRank"], 1)
        self.assertEqual(result[863]["professionRank"], 130)
        self.assertIn("Iron Bound Trunk", result[863]["source"])
        self.assertTrue(all(r["kind"] == "Drop" for r in result.values()))


if __name__ == "__main__":
    unittest.main()
