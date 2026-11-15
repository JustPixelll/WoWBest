"""Build routes from observed outdoor chest openings and catches on Forever.

Inputs are the Efficient Games launch-build loot.json and object_details.enUS.json
files already included in the sparse checkout described in DATA.md.
"""
from collections import defaultdict
import json
import re

from catalog_vendors import ZONE_NAMES


# Unlocked containers. A quest chest, locked box, ore vein or herb can require
# its own quest, key, tool or profession. Never treat those as public treasure.
OPEN_CHESTS = {"Battered Chest", "Large Battered Chest", "Solid Chest", "Large Solid Chest", "Weapon Crate"}
FISHED_CONTAINERS = {6356: "Battered Chest", 20708: "Tightly Sealed Trunk", 21150: "Iron Bound Trunk"}
# Zone skill thresholds: https://www.wowhead.com/forever/guide/professions/fishing/overview-leveling
# 130 is the mainland threshold in Stranglethorn; Jaguero Isle requires 205.
FISHING_MINIMUM = {1411: 1, 1413: 1, 1434: 130}


def _dropped(observation):
    return {int(k) for k, drop in observation.get("items", {}).items()
            if drop.get("drops", 0) > 0 and not drop.get("quest")}


def container_routes(builds, items):
    caught, contents = defaultdict(set), defaultdict(set)
    for build in builds:
        with (build / "object_details.enUS.json").open(encoding="utf-8") as stream:
            objects = json.load(stream)["objects"]
        with (build / "loot.json").open(encoding="utf-8") as stream:
            sources = json.load(stream)["sources"]
        for key, observation in sources.items():
            opened = re.fullmatch(r"item:(\d+)(?:\|group)?", key)
            fishing = re.fullmatch(r"fishing:(\d+)(?:\|group)?", key)
            chest = re.fullmatch(r"object:(\d+)\|spell:3365(?:\|group)?", key)
            if opened:
                container = int(opened[1])
                if container in FISHED_CONTAINERS:
                    contents[container].update(_dropped(observation).intersection(items))
                continue
            if not (fishing or chest):
                continue
            positions = observation.get("positions")
            # Exclude unlocated or mixed instance/outdoor observations. Item
            # drops and positions are separate aggregates inside each record.
            if not positions or any(p.get("instance") not in (0, 1) for p in positions):
                continue
            zones = {p["uiMap"] for p in positions if p.get("uiMap") in ZONE_NAMES}
            if fishing:
                zone = int(fishing[1])
                if zone in FISHING_MINIMUM and zone in zones:
                    for container in _dropped(observation).intersection(FISHED_CONTAINERS):
                        caught[container].add(zone)
                continue
            obj = objects.get(chest[1], {})
            name = obj.get("name")
            if name in OPEN_CHESTS and obj.get("type") == 3 and not obj.get("questItems"):
                for zone in sorted(zones):
                    for item in sorted(_dropped(observation).intersection(items)):
                        yield item, {"kind": "Drop", "source": f"World chest: {name}, {ZONE_NAMES[zone]} (random contents)."}

    # Both halves must have occurred on a launch build. Never infer a chest's
    # contents from its item level, the zone, or an unlinked loot window.
    for container, gear in sorted(contents.items()):
        for zone in sorted(caught[container]):
            place = ZONE_NAMES[zone] + (" (mainland)" if zone == 1434 else "")
            rank = FISHING_MINIMUM[zone]
            source = f"Fishing: {FISHED_CONTAINERS[container]} caught in {place}. Open for a chance at this item (Fishing {rank})."
            for item in sorted(gear):
                yield item, {"kind": "Drop", "source": source, "professionID": 356, "professionRank": rank,
                             "acquireProfessionID": 356, "acquireProfessionRank": rank}
