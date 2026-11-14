"""Generate the offline Forever catalog from pinned local git checkouts. See DATA.md."""
import argparse
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import html
import json
import re
import subprocess

from catalog_vendors import vendor_routes

PINS = {
    "polestar": ("fitzforge/polestar", "19bd636e7d6f33231770f6029c76d2d4dfc63798"),
    "observations": ("JIVESCORP/eg-link-output-wowf", "ea970da071079b32e56f349e09648ff0e314b351"),
    "cache": ("Napalmsteak/WoW-Classic-Item-Caches", "eff4560809de2e852e9164183e3edf5a795edd20"),
}
ROOT = Path(__file__).resolve().parents[1]
ANY_RACE = 0xFF | 3 << 32  # Eight original races plus the two Skyborne mask bits.
SKILLS = {"Alchemy": 171, "Blacksmithing": 164, "Enchanting": 333, "Engineering": 202,
          "Leatherworking": 165, "Tailoring": 197, "Jewelcrafting": 755, "Mining": 186,
          "Herbalism": 182, "Skinning": 393, "Cooking": 185, "First Aid": 129, "Fishing": 356}
STANDINGS = {"Neutral": 4, "Friendly": 5, "Honored": 6, "Revered": 7, "Exalted": 8}
SLOTS = {"Head": 1, "Neck": 2, "Shoulder": 3, "Chest": 5, "Waist": 6, "Legs": 7,
         "Feet": 8, "Wrist": 9, "Hands": 10, "Finger": 11, "Trinket": 12, "One-Hand": 13,
         "Ranged": 15, "Back": 16, "Two-Hand": 17, "Main Hand": 21, "Off Hand": 22,
         "Held In Off-hand": 23, "Thrown": 25, "Relic": 28}
# Original instances have published portal minimums. New ones have published recommended floors.
DUNGEONS = {
    "Ragefire Chasm": 10, "Wailing Caverns": 10, "The Deadmines": 10,
    "Shadowfang Keep": 14, "The Stockade": 15, "Blackfathom Deeps": 15, "Gnomeregan": 19,
    "Scarlet Monastery": 21, "Scarlet Monastery: Library": 21, "Razorfen Kraul": 25,
    "Razorfen Downs": 35, "Uldaman": 30, "Zul'Farrak": 39, "Maraudon": 30,
    "Sunken Temple": 45, "The Temple of Atal'Hakkar": 45, "Blackrock Depths": 48,
    "Blackrock Spire": 48, "Blackrock Spire: Upper": 48, "Dire Maul": 48,
    "Scholomance": 48, "Stratholme": 48, "Hall of Thanes": 13, "Ruins of Lordaeron": 15,
    "Excavation Site": 24, "Excavation Site: Wetlands": 24, "City of Dalaran": 28,
    "The Drowned City": 35, "Krol'dok Stronghold": 40, "Alcaz Prison": 48, "Blackmaw Hold": 55,
    "Shaper's Terrace": 58,
}
MAP_DUNGEONS = {33: "Shadowfang Keep", 36: "The Deadmines", 43: "Wailing Caverns",
                47: "Razorfen Kraul", 48: "Blackfathom Deeps", 90: "Gnomeregan",
                129: "Razorfen Downs", 189: "Scarlet Monastery", 389: "Ragefire Chasm",
                2959: "City of Dalaran", 2970: "The Drowned City", 2998: "Excavation Site",
                2999: "Ruins of Lordaeron", 3065: "Hall of Thanes"}
CLASS_QUESTS = {81: 1, 141: 2, 261: 3, 162: 4, 262: 5, 82: 7, 161: 8, 61: 9, 263: 11}
# Profession, holiday, war-effort and expired-event quests have additional access requirements.
SKIP_QUEST_CATEGORIES = {1, 22, 24, 101, 121, 181, 182, 201, 264, 284, 304, 324, 344,
                         364, 365, 366, 368, 369, 641, 666, 676}
BAD_NAME = re.compile(r'\b(?:NYI|UNUSED|Deprecated|QA|TEST|PH|DEBUG|DNT|TESTING|TMP)\b', re.I)


def read_map(build, filename, field):
    with (build / (filename + ".json")).open(encoding="utf-8") as stream:
        return json.load(stream)[field]


def indexed_lua(text):
    return {int(k): v.replace("\\'", "'").replace('\\"', '"').replace("\\\\", "\\")
            for k, v in re.findall(r'^\[(\d+)\]="(.*)",$', text, re.M)}


def lua_tables(text):
    sections = re.split(r"^(names|src|quests|npcs|zones) = \{\n", text, flags=re.M)
    return {sections[i]: indexed_lua(sections[i + 1]) for i in range(1, len(sections), 2)}


def stat_metadata(raw):
    inv, ilvl, level, _quality, cls, sub, *tokens = raw.split()
    if int(cls) not in (2, 4) or int(inv) not in set(SLOTS.values()) | {14, 20, 26}:
        return {}
    meta = dict(invType=int(inv), itemLevel=int(ilvl), minLevel=max(int(level), 1),
                classID=int(cls), subclassID=int(sub))
    for token in tokens:
        if token.startswith("cls") and token[3:].isdigit():
            meta["classMask"] = int(token[3:])
        elif token == "uniq1":
            meta["maxCopies"] = 1
    return meta


def from_tooltip(row):
    tip = row["tooltipHtml"]
    loc = re.search(r"<tr><td>([\w -]+)</td>(?:<th><!--sc|</tr>)", tip)
    if not loc or loc[1] not in SLOTS:
        return {}
    cls, sub = (int(v) for v in re.search(r"<!--scstart(\d+):(-?\d+)-->", tip).groups()) if "<!--scstart" in tip else (4, 0)
    inv = SLOTS[loc[1]]
    if inv == 22 and cls == 4 and sub == 6:
        inv = 14
    if inv == 15 and sub == 19:
        inv = 26
    ilvl = re.search(r"<!--ilvl-->(\d+)", tip)
    level = re.search(r"<!--rlvl-->(\d+)", tip)
    item = dict(name=row["name"], invType=inv, itemLevel=int(ilvl[1]) if ilvl else 0,
                minLevel=int(level[1]) if level else 1, classID=cls, subclassID=max(0, sub))
    if "Binds when picked up" in tip:
        item["binding"] = "BoP"
    elif "Binds when equipped" in tip:
        item["binding"] = "BoE"
    for entity in ("class", "race"):
        ids = {int(x) for x in re.findall(f'/forever/{entity}=(\\d+)/', tip)}
        if ids:
            if entity == "race":
                ids = {33 if x == 95 else 34 if x == 96 else x for x in ids}
            item[entity + "Mask"] = sum(1 << (i - 1) for i in ids)
    unique = re.search(r"<!--ue--><br>Unique(?:-Equipped)?(?:: ([^<(]+) \((\d+)\))?(?: \((\d+)\))?<!--ue-->", tip)
    if unique:
        if unique[1]:
            item["unique"] = "group:" + html.unescape(unique[1])
            item["uniqueLimit"] = int(unique[2])
        else:
            item["itemLimit"] = int(unique[3] or 1)
    rep = re.search(r'Requires <a href="/forever/faction=(\d+)/[^"]+"[^>]*>([^<]+)</a> - (\w+)', tip)
    if rep and rep[3] in STANDINGS:
        item.update(repFactionID=int(rep[1]), repName=html.unescape(rep[2]), minStanding=STANDINGS[rep[3]])
    rank = re.search(r"Requires [^<]+?\(Rank (\d+)\)", tip)
    if rank:
        item["minPvPRank"] = int(rank[1])
    skill = re.search(r'Requires <a href="/forever/skill=(\d+)/[^"]+"[^>]*>[^<]+</a> \((\d+)\)', tip)
    if skill:
        item.update(professionID=int(skill[1]), professionRank=int(skill[2]))
    return item


def acquire_items(polestar, cache):
    folder = polestar / "addon/Polestar_ItemDB"
    overlay = (folder / "Forever.lua").read_text(encoding="utf-8")
    tables = lua_tables(overlay)
    era = indexed_lua((folder / "Items.lua").read_text(encoding="utf-8"))
    items = {i: meta for i, s in era.items() if (meta := stat_metadata(s))}
    overlay_stats = overlay.split("DB.Register(nil, {", 1)[1].split("DB.RegisterLeveling({", 1)[0]
    for i, s in indexed_lua(overlay_stats).items():
        meta = stat_metadata(s)
        if meta:
            items[i] = meta
            stats = " ".join(s.split()[6:])
            if stats:
                items[i]["foreverStats"] = stats
    for i, name in tables["names"].items():
        if i in items:
            items[i]["name"] = name
    rows = json.loads((cache / "Forever Cache.json").read_text(encoding="utf-8"))
    for row in rows:
        meta = from_tooltip(row)
        if meta:
            item = items.setdefault(row["itemId"], {})
            # The Forever tooltip supersedes the earlier Era/Forever class and unique restrictions.
            for field in ("classMask", "raceMask", "maxCopies", "itemLimit", "unique", "uniqueLimit"):
                item.pop(field, None)
            item.update(meta)
    return items, tables, rows


def quest_sources(builds, tables, items):
    quests, repeatable, observed, offered, withheld = {}, set(), defaultdict(set), set(), set()
    for build in builds:
        quests.update({int(k): v for k, v in read_map(build, "quests.enUS", "quests").items()})
        with (build / "quest_scan.json").open() as stream:
            scan = json.load(stream)
        repeatable.update(map(int, scan.get("repeatable", {})))
        withheld.update(map(int, scan["noData"]))
        withheld.difference_update(map(int, scan["described"]))
        for q, facts in read_map(build, "turn_ins", "quests").items():
            observed[int(q)].update(t["faction"] for t in facts if t.get("faction"))
        for entity in ("npcs", "objects"):
            for npc in read_map(build, "npcs", entity).values():
                offered.update(map(int, npc.get("offers", {})))
    for qid, q in sorted(quests.items()):
        title = q.get("title", "")
        category = q.get("categoryId", 0)
        if (not title or BAD_NAME.search(title) or qid in withheld or category in SKIP_QUEST_CATEGORIES
                or q.get("questInfoId") in (41, 62)):
            continue
        legacy = tables["quests"].get(qid)
        if not (qid in observed or qid in offered or legacy):
            continue
        # A client can describe unoffered quests. Require sightings for special/endgame content.
        if q.get("level", 0) >= 50 and qid not in offered and qid not in observed:
            continue
        faction, cls, min_level, race = None, 0, max(1, q.get("minLevel", 1)), int(q["raceMask"], 16) & ANY_RACE
        zone = q.get("zoneAreaId")
        if legacy:
            head, _choices, _fixed, _title = legacy.split("|", 3)
            _lvl, _min, side, legacy_zone, legacy_race, cls, _iscave = map(int, head.split())
            faction = {1: "Alliance", 2: "Horde"}.get(side)
            zone = zone or legacy_zone
            if race == ANY_RACE and legacy_race:
                race = legacy_race & ANY_RACE
        elif len(observed[qid]) == 1:
            faction = next(iter(observed[qid]))
        elif race == ANY_RACE and len(observed[qid]) != 2:
            # An NPC offering the quest alone does not establish its side/class eligibility.
            continue
        if category in CLASS_QUESTS:
            cls = 1 << (CLASS_QUESTS[category] - 1)
        if zone == 16593:  # The origin quest line can require the Skyborne account unlock.
            race &= 3 << 32
        if not race:
            continue
        zone_name = tables["zones"].get(zone)
        if q.get("questInfoId") == 81 and zone_name in DUNGEONS:
            min_level = max(min_level, DUNGEONS[zone_name])
        source = "Quest: " + title + (" (" + zone_name + ")" if zone_name else "")
        route = dict(kind="Quest", source=source, questID=qid, minLevel=min_level)
        if faction:
            route["faction"] = faction
        if cls:
            route["classMask"] = cls
        if race != ANY_RACE:
            route["raceMask"] = race
        if qid in repeatable:
            route["once"] = False
        for field in ("choices", "items"):
            for reward in q["rewards"].get(field, []):
                ident = reward["itemId"]
                if ident not in items:
                    continue
                result = dict(route)
                if qid not in repeatable:
                    result["maxCopies"] = reward.get("count", 1)
                    if field == "choices":
                        result["choice"] = qid
                yield ident, result


def observed_boss_drops(builds, items):
    encounters = {}
    for build in builds:
        if (build / "encounters.json").exists():
            encounters.update(read_map(build, "encounters", "encounters"))
    for build in builds:
        for key, roll in read_map(build, "loot", "rolls").items():
            match = re.fullmatch(r"encounter:(\d+)\|threshold:\d+", key)
            encounter = encounters.get(match[1]) if match else None
            if not encounter:
                continue
            zone = MAP_DUNGEONS.get(encounter.get("map"))
            boss = encounter.get("name")
            if not zone or not boss:
                continue
            for raw, drop in roll.get("items", {}).items():
                ident = int(raw)
                if ident in items and drop.get("drops", 0) > 0:
                    yield ident, dict(kind="Dungeon", source=f"Dungeon: {zone} - {boss}", minLevel=DUNGEONS[zone])


def dungeon_and_craft_sources(builds, tables, items, rows):
    # Corroborate recipe and dungeon metadata with launch trainer observations or another
    # Forever item source. A recipe dropping from a boss is not the crafted gear itself.
    trainers = set()
    for build in builds:
        for trainer in read_map(build, "trainers", "trainers").values():
            trainers.update(map(int, trainer.get("services", {})))
    routes = {r["itemId"]: r for r in rows}
    professions = list(SKILLS)
    for i, raw in tables["src"].items():
        if i not in items:
            continue
        item, cached = items[i], routes.get(i, {})
        for token in raw.split():
            if token.startswith("c"):
                spell, prof, rank = map(int, re.fullmatch(r"c(\d+)p(\d+)s(\d+)", token).groups())
                if not prof or prof > len(professions):
                    continue
                if spell not in trainers and ("Crafted" not in cached.get("sourceTypes", []) or rank > 225):
                    continue
                name = professions[prof - 1]
                route = dict(kind="Crafted", source=f"Crafted: {name} ({rank})")
                if item.get("binding") == "BoP" or (not item.get("binding") and spell not in trainers):
                    route.update(professionID=SKILLS[name], professionRank=rank)
                yield i, route
            elif token.startswith("d"):
                npc, _chance, zone = map(int, re.fullmatch(r"d(\d+)x(\d+)z(\d+)", token).groups())
                zone_name = tables["zones"].get(zone)
                if zone_name not in DUNGEONS or "Dungeon" not in cached.get("sourceTypes", []):
                    continue
                boss = tables["npcs"].get(npc)
                yield i, dict(kind="Dungeon", source="Dungeon: " + zone_name + (" - " + boss if boss else ""),
                              minLevel=DUNGEONS[zone_name])
    for row in rows:
        i = row["itemId"]
        if i not in items or "Crafted" in row["sourceTypes"]:
            continue
        zones = [n for n, k in zip(row["sourceLabels"], row["sourceTypes"]) if k == "Dungeon" and n in DUNGEONS]
        for zone in zones:
            bosses = row.get("bossNames", []) if len(zones) == 1 else []
            if not bosses:
                continue
            yield i, dict(kind="Dungeon", source="Dungeon: " + zone + " - " + " / ".join(bosses),
                          minLevel=DUNGEONS[zone])


def observed_world_drops(builds, items):
    for build in builds:
        creatures = read_map(build, "creature_details.enUS", "creatures")
        for key, data in read_map(build, "loot", "sources").items():
            source = re.match(r"npc:(\d+)(?:\||$)", key)
            if not source:
                continue
            mob = creatures.get(source[1], {}).get("name")
            if not mob or BAD_NAME.search(mob):
                continue
            # Require evidence the corpse was in the outdoor world. No guessing instance gates.
            positions = {pos.get("instance") for pos in data.get("positions", [])}
            if not positions.intersection({0, 1, 2991}):
                continue
            for raw, drop in data.get("items", {}).items():
                i = int(raw)
                if i in items and drop.get("drops", 0) > 0 and not drop.get("quest"):
                    yield i, dict(kind="Drop", source="World drop: " + mob)


def merged(item, i, route):
    out = dict(item, id=i)
    for field, v in route.items():
        if field in ("minLevel", "professionRank", "minPvPRank", "minStanding"):
            out[field] = max(v, out.get(field, 0))
        elif field in ("classMask", "raceMask") and field in out:
            out[field] &= v
            if not out[field]:
                return None
        elif field == "maxCopies":
            out[field] = min(v, out.get(field, v))
        elif field == "professionID" and out.get(field, v) != v:
            return None
        else:
            out[field] = v
    return out


def lua_scalar(x):
    if isinstance(x, str):
        return json.dumps(x, ensure_ascii=False)
    if isinstance(x, bool):
        return str(x).lower()
    return str(x)


def generate(polestar, observations, cache, output):
    builds = [p for p in sorted((observations / "data/wowf").iterdir())
              if 70790 <= int(p.name.split(".")[-1]) <= 70938]
    items, tables, rows = acquire_items(polestar, cache)
    hotfixes = read_map(builds[-1], "item_hotfixes.enUS", "items")
    for raw, response in hotfixes.items():
        if response["status"] in ("removed", "invalid"):
            items.pop(int(raw), None)
    # Give unnamed common items the names actually seen on launch vendor lists.
    for build in builds:
        for seller in read_map(build, "vendors", "vendors").values():
            for listing in seller.get("entries", {}).values():
                if listing.get("itemId") in items and listing.get("name"):
                    items[listing["itemId"]].setdefault("name", listing["name"])
    routes = defaultdict(set)
    for source in (quest_sources(builds, tables, items), dungeon_and_craft_sources(builds, tables, items, rows),
                   observed_boss_drops(builds, items), observed_world_drops(builds, items), vendor_routes(builds, items)):
        for i, route in source:
            if i in items and not BAD_NAME.search(items[i].get("name", "")):
                record = merged(items[i], i, route)
                if record:
                    routes[i].add(tuple(sorted(record.items())))
    header = ("-- Generated by tools/build_catalog.py; see DATA.md and licenses/.\n"
              "-- Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0; modified.\n"
              "-- Includes ForeverLevelingBiS data (c) 2026 Thunder, MIT. Game facts (c) Blizzard.\n"
              "local _, A = ...\nA.Catalog = {}\n"
              "local function add(item, routes)\n"
              "    for _, route in ipairs(routes) do\n"
              "        for k, v in pairs(item) do if route[k] == nil then route[k] = v end end\n"
              "        A.Catalog[#A.Catalog + 1] = route\n"
              "    end\nend\n")
    buf = [header]
    def lua_record(record):
        return "{" + ",".join(k + "=" + lua_scalar(v) for k, v in sorted(record.items())) + "}"
    counts = Counter()
    for i, variants in sorted(routes.items()):
        variants = [dict(t) for t in sorted(variants)]
        fields = set.intersection(*[set(row.items()) for row in variants])
        item = dict(fields)
        # Keep source type/description with its route for easy auditing.
        shared = {k: v for k, v in item.items() if k not in ("kind", "source")}
        per_route = []
        for row in variants:
            counts[row["kind"]] += 1
            per_route.append(lua_record({k: v for k, v in row.items() if k not in shared}))
        buf.append("add(" + lua_record(shared) + ",{" + ", ".join(per_route) + "})\n")
    output.write_text("".join(buf), encoding="utf-8", newline="\n")
    print(f"{len(routes)} unique items; {sum(counts.values())} routes: {dict(sorted(counts.items()))}")
    print("Catalog SHA-256", hashlib.sha256(output.read_bytes()).hexdigest())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in PINS:
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    for name, (_repo, expected) in PINS.items():
        actual = subprocess.check_output(["git", "-C", getattr(args, name), "rev-parse", "HEAD"], text=True).strip()
        if actual != expected:
            parser.error(f"{name} must be at {expected}, found {actual}")
    generate(args.polestar, args.observations, args.cache, ROOT / "WoWBest/Catalog.lua")


if __name__ == "__main__":
    main()
