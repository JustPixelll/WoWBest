"""Turn post-launch merchant observations and sourced quartermaster stock into routes.

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
    1457: "Darnassus", 1458: "Undercity", 2521: "Zephras Isle", 2548: "Riverglades",
}
STANDINGS = {4: "Neutral", 5: "Friendly", 6: "Honored", 7: "Revered", 8: "Exalted"}
# These outdoor quartermasters are separate from the disabled capital honor shops.
PVP_QUARTERMASTERS = {263569: 2799, 263570: 2798, 15126: 510, 15127: 509}
REP_QUARTERMASTERS = {**PVP_QUARTERMASTERS, 265574: 470, 265575: 21,
                      265576: 369, 265577: 577, 255897: 2827}
GELVAS = 14828
DARKMOON_TICKETS = 515
# Each ID has an affirmative item-to-merchant listing. A reputation or a similar
# opposing-faction item alone cannot establish stock. See the sources in DATA.md.
REFERENCE_STOCK = {
    15127: ("Samuel Hawke", "Refuge Pointe, Arathi Highlands (46, 45)", "Alliance",
            (*range(20041, 20062), 20069, 20070, 20071, 20073,
             *range(20088, 20130), 21117, 21118, 21119)),
    263569: ("Bryanna Embreeze", "Northwatch Hold, The Barrens (63, 59)", "Alliance",
             (271903, 271904, 271905, 271906, 271907, 271908, 271909, 271910,
              271913, 271914, 271915, 271917, 271918, 271919, 271921, 271922,
              271924, 271925, 271926, 271928, 271929, 271930, 271932, 271933,
              271934, 271936, 271937, 271938, 271940, 271941, 271945, 271946,
              271948, 271949, 271950, 271951, 271953, 271954, 271955, 271956,
              271957, 271959, 272957)),
    265575: ("Gezzy Gunkgear", "Booty Bay, Stranglethorn Vale", None, range(274745, 274750)),
    265576: ("Rettrick", "Gadgetzan, Tanaris", None, range(274750, 274755)),
    265577: ("Zippie Fizzbolt", "Everlook, Winterspring", None, range(274755, 274762)),
    255897: ("Friz Frazzlespark", "Powderfuse Port, Riverglades", None, range(276200, 276205)),
}
# These other Faire sellers and deployed Reagent Bots have no modeled availability gate.
TEMPORARY_MERCHANTS = {14844, 14845, 242498}
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


def _route(npc_id, name, location, side, entry, item):
    if not name or not location:
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

    if npc_id == GELVAS:
        costs = entry.get("costItems") or []
        if len(costs) != 1 or costs[0].get("currencyId") != DARKMOON_TICKETS or not costs[0].get("amount"):
            return
        route.update(eventName="Darkmoon Faire", eventVendorID=GELVAS,
                     requiredCurrencyID=DARKMOON_TICKETS, requiredCurrencyAmount=costs[0]["amount"])
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
    """Yield each seller/item once, preferring the latest observed price when available."""
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
    observed = set()
    for npc_id, entries in sorted(merchants.items()):
        npc = npcs.get(str(npc_id))
        if not npc or npc_id in TEMPORARY_MERCHANTS:
            continue
        for item_id, (vendor, entry) in sorted(entries.items()):
            location = ("Darkmoon Faire (Elwynn Forest or Mulgore)" if npc_id == GELVAS
                        else _location(vendor))
            route = _route(npc_id, vendor.get("name"), location, npc.get("side"), entry, items[item_id])
            if route:
                observed.add((npc_id, item_id))
                yield item_id, route
    for npc_id, (name, location, side, item_ids) in REFERENCE_STOCK.items():
        for item_id in item_ids:
            if (npc_id, item_id) in observed or item_id not in items:
                continue
            route = _route(npc_id, name, location, side, {}, items[item_id])
            if route:
                yield item_id, route
