"""Turn post-launch Efficient Games merchant observations into acquisition routes.

The merchant log records stock and prices. Item tooltip metadata independently
supplies equipment and reputation requirements. The buyer's discount standing
in a price sample is never evidence of a minimum purchase standing.
"""

import json

ZONE_NAMES = {
    1411: "Durotar", 1412: "Mulgore", 1413: "The Barrens", 1414: "Kalimdor",
    1417: "Arathi Highlands", 1420: "Tirisfal Glades", 1421: "Silverpine Forest",
    1424: "Hillsbrad Foothills", 1425: "The Hinterlands", 1429: "Elwynn Forest",
    1431: "Duskwood", 1433: "Redridge Mountains", 1434: "Stranglethorn Vale",
    1435: "Swamp of Sorrows", 1436: "Westfall", 1437: "Wetlands", 1438: "Teldrassil",
    1439: "Darkshore", 1440: "Ashenvale", 1441: "Thousand Needles",
    1442: "Stonetalon Mountains", 1443: "Desolace", 1444: "Feralas",
    1445: "Dustwallow Marsh", 1450: "Moonglade", 1453: "Stormwind City",
    1454: "Orgrimmar", 1455: "Ironforge", 1456: "Thunder Bluff",
    1457: "Darnassus", 1458: "Undercity", 2521: "Zephras Isle",
}
STANDINGS = {4: "Neutral", 5: "Friendly", 6: "Honored", 7: "Revered", 8: "Exalted"}
# These outdoor quartermasters are separate from the disabled capital honor shops.
PVP_QUARTERMASTERS = {263570: 2798, 15126: 510}
REP_QUARTERMASTERS = {**PVP_QUARTERMASTERS, 265574: 470}
# Faire vendors rotate with the calendar. A deployed Reagent Bot is temporary.
# Neither provides a permanent merchant at the coordinates of the observation.
TEMPORARY_MERCHANTS = {14828, 14844, 14845, 242498}
# Opposed Desolace centaur quartermasters require their faction's favor.
CENTAUR_MERCHANTS = {253139, 253140}


def _load(path, key):
    if not path.is_file():
        return {}
    with path.open(encoding="utf-8") as f:
        return json.load(f).get(key, {})


def _money(copper):
    gold, rem = divmod(copper, 10000)
    silver, copper = divmod(rem, 100)
    return " ".join(f"{n}{unit}" for n, unit in ((gold, "g"), (silver, "s"), (copper, "c")) if n)


def _location(vendor):
    for point in vendor.get("positions", []):
        zone = ZONE_NAMES.get(point.get("uiMap"))
        if zone:
            x, y = point.get("mapX"), point.get("mapY")
            if x is not None and y is not None:
                return f"{zone} ({x * 100:.0f}, {y * 100:.0f})"
            return zone


def _route(npc_id, vendor, npc, entry, item):
    name = vendor.get("name")
    location = _location(vendor)
    if not npc or not name or not location or npc_id in TEMPORARY_MERCHANTS:
        return
    rep = item.get("repFactionID")
    standing = item.get("minStanding")
    if npc_id in REP_QUARTERMASTERS and (rep != REP_QUARTERMASTERS[npc_id] or not standing):
        return
    if npc_id in CENTAUR_MERCHANTS and not (rep and standing):
        return

    kind = "PvP" if npc_id in PVP_QUARTERMASTERS else "Vendor"
    route = {"kind": kind}
    details = [f"{kind}: {name}, {location}"]
    side = npc.get("side")
    if side in ("Alliance", "Horde"):
        route["faction"] = side
    if rep and standing:
        if standing not in STANDINGS:
            return
        route.update(repFactionID=rep, minStanding=standing)
        details.append(f"{item.get('repName') or 'Faction ' + str(rep)}: {STANDINGS[standing]}")
    if item.get("minPvPRank"):
        route["minPvPRank"] = item["minPvPRank"]
        details.append(f"PvP rank {item['minPvPRank']}")

    prices = entry.get("costs") or {}
    copper = prices.get("4")
    if copper is None and prices:
        copper = max(prices.values())
    if copper:
        details.append(f"observed {_money(copper)}")
    for cost in entry.get("costItems", []):
        if not cost.get("amount") or not cost.get("name"):
            return
        details.append(f"{cost['amount']} {cost['name']}")
    if entry.get("limited"):
        details.append("limited stock")
    route["source"] = " · ".join(details)
    return route


def vendor_routes(builds, items):
    """Yield (item ID, distinct vendor route), newest receipt per merchant/item."""
    npcs = {}
    merchants = {}
    for build in builds:
        npcs.update(_load(build / "npcs.json", "npcs"))
        for key, vendor in _load(build / "vendors.json", "vendors").items():
            entries = merchants.setdefault(int(key), {})
            for entry in vendor.get("entries", {}).values():
                item_id = entry.get("itemId")
                if item_id in items:
                    entries[item_id] = (vendor, entry)
    for npc_id, entries in sorted(merchants.items()):
        for item_id, (vendor, entry) in sorted(entries.items()):
            route = _route(npc_id, vendor, npcs.get(str(npc_id)), entry, items[item_id])
            if route:
                yield item_id, route
