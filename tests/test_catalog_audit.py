import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from audit_catalog import Route, by_level, compare_cache, write_report
from build_catalog import from_tooltip, reference_dungeon


class CoverageTests(unittest.TestCase):
    def test_unique_limits_survive_both_forever_tooltip_layouts(self):
        def limits(header):
            tip = (header + '<table width="100%"><tr><td>Finger</td><th>'
                   '<!--scstart4:0-->Ring</th></tr></table>')
            item = from_tooltip({"itemId": 273031, "name": "Ring", "tooltipHtml": tip})
            return {name: item[name] for name in ("itemLimit", "unique", "uniqueLimit") if name in item}

        self.assertEqual(limits("<br>Unique-Equipped<!--ue--><!--ue-->"), {"itemLimit": 1})
        self.assertEqual(limits("<br>Unique<!--ue--><br>Unique-Equipped: Watcher's Ring (1)<!--ue-->"),
                         {"itemLimit": 1, "unique": "group:Watcher's Ring", "uniqueLimit": 1})

    def test_graveyard_reference_sources(self):
        for zone in ("Scarlet Monastery", "Scarlet Monastery: Library"):
            self.assertIsNone(reference_dungeon(zone, "Scorn"))
            self.assertEqual(reference_dungeon(zone, "Fallen Champion")["source"],
                             "Dungeon: Scarlet Monastery: Graveyard - Fallen Champion")
        self.assertEqual(reference_dungeon("Scarlet Monastery: Library", "Arcanist Doan")["source"],
                         "Dungeon: Scarlet Monastery: Library - Arcanist Doan")

    def test_count_ids_across_alternate_routes_and_level_ranges(self):
        rows = [
            Route(1, "Drop", "Head", 20, 60, "", 0, 0),
            Route(1, "Quest", "Head", 15, 19, "Horde", 1, 1 << 33),
            Route(2, "Vendor", "Head", 19, 60, "", 0, 0),
            Route(2, "Dungeon", "Head", 19, 60, "", 0, 0),
        ]
        levels = by_level(rows, "Horde", 1, 96)
        self.assertEqual(list(levels), list(range(1, 61)))
        self.assertEqual(levels[14]["Head"], set())
        self.assertEqual(levels[15]["Head"], {1})
        self.assertEqual(levels[19]["Head"], {1, 2})
        self.assertEqual(levels[60]["Head"], {1, 2})
        for options in (("Alliance", 1, 96), ("Horde", 2, 96), ("Horde", 1, 95)):
            self.assertEqual(by_level(rows, *options)[19]["Head"], {2})
        self.assertEqual(by_level(rows[:1])[19]["Head"], set())
        self.assertEqual(by_level(rows[1:2])[20]["Head"], set())

    def test_comparison_keeps_cache_labels_separate_from_route_evidence(self):
        simple = '<tr><td>Head</td><th><!--scstart4:1-->'
        def item(ident, name, tip, labels):
            return {"itemId": ident, "name": name, "tooltipHtml": tip, "sourceTypes": labels}
        cache = [item(4, "Dropped helm", simple, ["Drop", "Vendor"]),
                 item(5, "Quest helm", simple, ["Quest"]),
                 item(6, "Appearance", simple.replace("4:1", "4:5"), ["Vendor"]),
                 item(7, "Unused Helm", simple, ["Other"]),
                 item(8, "Out of level range", simple + "<!--rlvl-->80", ["Other"])]
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "Forever Cache.json"
            path.write_text(json.dumps(cache))
            groups, missing = compare_cache(path.parent, {4, 99})
        self.assertEqual(groups, {"Drop": {4}, "Vendor": {4}, "Quest": {5}})
        self.assertEqual(missing, {5: (5, "Quest helm", 1, "Head", "Quest")})

    def test_report_separates_leads_and_shared_ids_at_each_level(self):
        rows = [Route(5, "Drop", "Head", 10, 60, "", 0, 0, True),
                Route(5, "Quest", "Head", 20, 60, "", 0, 0),
                Route(7, "Drop", "Head", 20, 60, "", 0, 0, True)]
        with tempfile.TemporaryDirectory() as temp:
            report = Path(temp) / "COVERAGE.md"
            catalog = Path(temp) / "Catalog.lua"
            catalog.write_text("-- test fixture")
            write_report(report, rows, {"Drop": {5, 7, 9}}, catalog)
            text = report.read_text()
        self.assertIn("| 19 | 0 | 1 | 49 | 1 | 2 |", text)
        self.assertIn("| 30 | 1 | 2 | 60 | 1 | 2 |", text)
        self.assertIn("| Drop | 3 | 1 | 1 | 1 |", text)


if __name__ == "__main__":
    unittest.main()
