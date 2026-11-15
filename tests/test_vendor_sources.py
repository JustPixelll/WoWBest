import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from catalog_vendors import vendor_routes


class VendorTests(unittest.TestCase):
    def test_item_to_seller_and_standing_must_agree(self):
        items = {
            20041: {"repFactionID": 509, "minStanding": 8, "repName": "The League of Arathor"},
            20042: {"repFactionID": 510, "minStanding": 8},
            271903: {"repFactionID": 2799, "minStanding": 5},
            271911: {"repFactionID": 2799, "minStanding": 5},
            274748: {"repFactionID": 21, "minStanding": 6, "repName": "Booty Bay"},
            274749: {"repFactionID": 21},
        }
        results = dict(vendor_routes([], items))
        self.assertEqual(set(results), {20041, 271903, 274748})
        self.assertEqual(results[20041]["faction"], "Alliance")
        self.assertEqual(results[20041]["kind"], "PvP")
        self.assertIn("Exalted", results[20041]["source"])
        self.assertIn("Bryanna Embreeze", results[271903]["source"])
        self.assertIn("Gezzy Gunkgear", results[274748]["source"])
        self.assertNotIn("faction", results[274748])
        self.assertNotIn("observed", results[274748]["source"])

    def test_observed_price_supersedes_reference_and_faire_requires_ticket_cost(self):
        def stock(name, items):
            return {"name": name, "positions": [{"uiMap": 2548, "mapX": .79, "mapY": .54}],
                    "entries": {str(item["itemId"]): item for item in items}}

        items = {274745: {"repFactionID": 21, "minStanding": 5}, 19491: {}, 19295: {}, 3023: {}, 3: {}}
        vendors = {
            "265575": stock("Gezzy Gunkgear", [{"itemId": 274745, "costs": {"5": 1000}}]),
            "14828": stock("Gelvas Grimegate", [
                {"itemId": 19491, "costItems": [{"amount": 1200, "currencyId": 515, "name": "Darkmoon Prize Ticket"}]},
                {"itemId": 19295, "costItems": [{"amount": 5, "currencyId": 999, "name": "Other Currency"}]},
            ]),
            "7": stock("Fizzix Boomshot", [{"itemId": 3023}]),
            "14844": stock("Temporary vendor", [{"itemId": 3}]),
        }
        with tempfile.TemporaryDirectory() as temp:
            build = Path(temp)
            (build / "vendors.json").write_text(json.dumps({"vendors": vendors}))
            (build / "npcs.json").write_text(json.dumps({"npcs": {id: {"side": "Neutral"} for id in vendors}}))
            routes = list(vendor_routes([build], items))

        self.assertEqual(len(routes), 3)
        result = dict(routes)
        self.assertIn("10s", result[274745]["source"])
        self.assertEqual(result[274745]["minStanding"], 5)
        self.assertEqual(result[19491]["eventName"], "Darkmoon Faire")
        self.assertEqual(result[19491]["eventVendorID"], 14828)
        self.assertEqual(result[19491]["requiredCurrencyAmount"], 1200)
        self.assertEqual(result[19491]["requiredCurrencyID"], 515)
        self.assertIn("Elwynn Forest or Mulgore", result[19491]["source"])
        self.assertIn("Riverglades (79, 54)", result[3023]["source"])


if __name__ == "__main__":
    unittest.main()
