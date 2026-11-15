"""Generate the offline Forever catalog from pinned local git checkouts. See DATA.md."""
import argparse
from collections import Counter, defaultdict
from pathlib import Path
import hashlib
import html
import json
import re
import subprocess

from catalog_vendors import ZONE_NAMES, vendor_routes
from catalog_containers import container_routes

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
# Dungeon-tagged quests that can be finished outside the instance portal.
# For the Deadmines and Wailing Caverns IDs, the launch objective records include
# mainland progress on every required objective. See DATA.md for the other sources.
OUTDOOR_DUNGEON_QUESTS = {167, 168, 214, 704, 709, 962, 1275, 1486, 2418}
# Verified reward chains whose tag is on an earlier mandatory step. Tuples run
# forward from that step to the reward. Every edge is checked against the launch
# server's nextQuestId below; zone names alone never imply a prerequisite.
DUNGEON_REWARD_CHAINS = (
    (1160, 6628, 1394),        # Scarlet Monastery library book
    (2949, 2950),              # Grime-Encrusted Ring / Sparklematic, Gnomeregan
    (5728, 5729, 5730),        # Bazzalan and Jergosh, Ragefire Chasm
    (79360, 79364, 79361, 79366, 79442),  # Charlga, Razorfen Kraul
    (96264, 79358, 96135, 96016),          # Other faction's Razorfen Kraul chain
    (95036, 95111, 95125, 95126),         # Paladin Moonsilver Blade reagents
    (92415, 95161),            # Blood-Stained Letter, Ruins of Lordaeron
    (97288, 97289, 97290),     # Abominable Head, Ruins of Lordaeron
    (4764, 4765),              # Doomrigger's Clasp in Upper Blackrock Spire
)
# The server quest objective records specify the required gated item even
# on quests lacking the Dungeon tag. ZoneArea alone is never such proof.
DUNGEON_QUEST_ITEMS = {11129: "Blackrock Depths", 12871: "Blackrock Spire: Upper"}
# Exclude the old raid and unverified battleground reward chains even when
# the server still returns legacy quest records.
UNAVAILABLE_QUEST_ZONES = {19, 2159, 2597, 2677, 2717, 3428, 3429, 3456}
POSSIBLE_DROP = "Possible world drop: Classic source, Forever origin unconfirmed"
POSSIBLE_SUFFIX_DROP = POSSIBLE_DROP + ". Random suffix varies"
CLASS_QUESTS = {81: 1, 141: 2, 261: 3, 162: 4, 262: 5, 82: 7, 161: 8, 61: 9, 263: 11}
# Profession, holiday, war-effort and expired-event quests have additional access requirements.
# Rare-fish exchanges with item rewards verified in the launch quest and NPC logs.
FISH_REWARDS = {8221: (19805, "Keefer's Angelfish"), 8225: (19803, "Brownell's Blue Striped Racer")}
# Recipe reagents from the Forever client. NPCs and skill gates come from launch data.
GOGGLE_RECIPES = {3934: "6 Light Leather, 2 Tigerseye", 3940: "4 Medium Leather, 2 Shadowgem",
                  3956: "4 Medium Leather, 2 Moss Agate, 1 Flying Tiger Goggles"}
# The optional planning display can show the known stats without pretending the wearer
# passes the client's live requirements.
# Confirmed tradeable via launch AH listings (see DATA.md); uncommon+ cache omits
# most low-quality items. Do not infer that a missing tooltip proves tradeability.
AUCTION_TRADEABLE = {2568, 2844, 2845, 6219, 7026}
HEAD_GUIDE_IDS = {4368, 4373, 4385, 10499, 19972}
PRIMARY_STAT = {3: "agi", 4: "str", 5: "int", 6: "spi", 7: "sta"}
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
    if (int(cls) not in (2, 4) or int(inv) not in set(SLOTS.values()) | {14, 20, 26}
            or (int(cls), int(sub)) == (4, 5)):
        return {}
    meta = dict(invType=int(inv), itemLevel=int(ilvl), minLevel=max(int(level), 1),
                classID=int(cls), subclassID=int(sub))
    for token in tokens:
        if token.startswith("cls") and token[3:].isdigit():
            meta["classMask"] = int(token[3:])
        elif token == "uniq1":
            meta["itemLimit"] = 1
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
    elif "<!--bo-->" in tip and "Binds " not in tip and "Quest Item" not in tip:
        item["binding"] = "Unbound"
    for entity in ("class", "race"):
        ids = {int(x) for x in re.findall(f'/forever/{entity}=(\\d+)/', tip)}
        if ids:
            if entity == "race":
                ids = {33 if x == 95 else 34 if x == 96 else x for x in ids}
            item[entity + "Mask"] = sum(1 << (i - 1) for i in ids)
    # Plain limits appear after the binding. Named categories appear between
    # the ue comments. An item may be capped independently in both ways.
    header = tip.partition('<table width="100%">')[0]
    for unique in re.finditer(r"<br>Unique(?:-Equipped)?(?:: ([^<(]+) \((\d+)\))?(?: \((\d+)\))?(?=<!--ue-->|<br>)", header):
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
        item.update(wearProfessionID=int(skill[1]), wearProfessionRank=int(skill[2]),
                    professionID=int(skill[1]), professionRank=int(skill[2]))
    if row["itemId"] in HEAD_GUIDE_IDS:
        lines, tokens = [], []
        for key, amount, stat in re.findall(r"<!--stat(\d+)-->\+(\d+) (\w+)", tip):
            if int(key) in PRIMARY_STAT:
                lines.append(f"+{amount} {stat}")
                tokens.append(PRIMARY_STAT[int(key)] + amount)
        armor = re.search(r"<!--amr-->(\d+)", tip)
        if armor:
            lines.append(armor[1] + " armor")
            tokens.append("armor" + armor[1])
        item["foreverStats"] = " ".join(tokens)
        item["statSummary"] = ", ".join(lines)
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
            if i == 279391 and items[i].get("foreverStats") == "armor28":
                items[i]["statSummary"] = "28 armor"
    rows = json.loads((cache / "Forever Cache.json").read_text(encoding="utf-8"))
    for row in rows:
        meta = from_tooltip(row)
        if meta and (meta["classID"], meta["subclassID"]) == (4, 5):
            items.pop(row["itemId"], None)  # An appearance, not combat gear.
            continue
        if meta:
            item = items.setdefault(row["itemId"], {})
            # The Forever tooltip supersedes the earlier Era/Forever class and unique restrictions.
            for field in ("classMask", "raceMask", "maxCopies", "itemLimit", "unique", "uniqueLimit"):
                item.pop(field, None)
            item.update(meta)
    for i in AUCTION_TRADEABLE:
        if i in items:
            items[i].setdefault("binding", "Tradeable")
    return items, tables, rows


def quest_sources(builds, tables, items):
    quests, repeatable, observed, offered, withheld = {}, set(), defaultdict(set), set(), set()
    givers = {}
    fishbot_offers = set()
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
                ids = set(map(int, npc.get("offers", {})))
                offered.update(ids)
                if npc.get("name") == "Fishbot 5000":
                    fishbot_offers.update(ids)
                position = next((p for p in npc.get("positions", []) if p.get("uiMap") in ZONE_NAMES
                                 and "mapX" in p and "mapY" in p), None)
                if position and npc.get("name"):
                    place = f"{npc['name']}, {ZONE_NAMES[position['uiMap']]} ({100*position['mapX']:.0f}, {100*position['mapY']:.0f})"
                    for ident in ids:
                        givers.setdefault(ident, place)
    dungeon_steps = {qid: qid for qid, q in quests.items()
                     if q.get("questInfoId") == 81 and qid not in OUTDOOR_DUNGEON_QUESTS}
    for chain in DUNGEON_REWARD_CHAINS:
        if (chain[0] in dungeon_steps
                and all(quests.get(step, {}).get("nextQuestId") == following
                        for step, following in zip(chain, chain[1:]))):
            dungeon_steps[chain[-1]] = chain[0]

    for qid, q in sorted(quests.items()):
        title = q.get("title", "")
        category = q.get("categoryId", 0)
        fish = FISH_REWARDS.get(qid) if qid in fishbot_offers else None
        if fish and not any(obj.get("type") == "item" and obj.get("objectId") == fish[0]
                            and obj.get("amount") == 1 for obj in q.get("objectives", [])):
            fish = None
        if (not title or BAD_NAME.search(title) or qid in withheld or (category in SKIP_QUEST_CATEGORIES and not fish)
                or q.get("zoneAreaId") in UNAVAILABLE_QUEST_ZONES or q.get("questInfoId") in (41, 62)):
            continue
        legacy = tables["quests"].get(qid)
        # The server can return a reward window even for a quest nobody can start.
        # The character's own active log can establish access where the static
        # evidence does not. It never turns these rows into future quest offers.
        active_only = qid not in observed and qid not in offered and (not legacy or q.get("level", 0) >= 50)
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
            active_only = True
        if category in CLASS_QUESTS:
            cls = 1 << (CLASS_QUESTS[category] - 1)
        if zone == 16593:  # The origin quest line can require the Skyborne account unlock.
            race &= 3 << 32
        if not race:
            continue
        zone_name = tables["zones"].get(zone)
        dungeon_step = dungeon_steps.get(qid)
        dungeon = tables["zones"].get(quests[dungeon_step].get("zoneAreaId")) if dungeon_step else None
        for obj in q.get("objectives", []):
            if obj.get("type") == "item" and obj.get("objectId") in DUNGEON_QUEST_ITEMS:
                dungeon_step, dungeon = qid, DUNGEON_QUEST_ITEMS[obj["objectId"]]
                break
        if dungeon in DUNGEONS:
            min_level = max(min_level, DUNGEONS[dungeon])
        source = "Quest: " + title
        if qid in givers:
            source += " - " + givers[qid]
        elif zone_name:
            source += " (" + zone_name + ")"
        route = dict(kind="Quest", source=source, questID=qid, minLevel=min_level)
        if active_only:
            route.update(requiresQuestInLog=True, source=source + " [must be in your quest log]")
        if dungeon_step:
            route["requiresDungeon"] = True
            label = dungeon if dungeon in DUNGEONS else "dungeon"
            activity = "Previous quest step" if dungeon_step != qid else "Dungeon objective"
            route["source"] += f" [{activity}: {label}]" if label != "dungeon" else f" [{activity}]"
        if fish:
            route.update(eventName="Stranglethorn Fishing Extravaganza", requiresItemID=fish[0],
                         requiresQuestInLog=True,
                         source=f"Quest: Fish {fish[1]} from tournament pools during the Stranglethorn Fishing Extravaganza. Turn in to Fishbot 5000, Booty Bay (27, 77).")
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


def reference_dungeon(zone, boss):
    # The source cache uses the parent instance; the leveling index sometimes
    # calls its Graveyard rares Library bosses. All three spawn in Graveyard.
    graveyard_rares = {"Fallen Champion", "Azshir the Sleepless", "Ironspine"}
    if zone.startswith("Scarlet Monastery") and boss == "Scorn":
        # An event encounter in Era without a verified Forever spawn. Actual
        # launch loot observations can still supply their own independent route.
        return None
    label = ("Scarlet Monastery: Graveyard" if zone.startswith("Scarlet Monastery")
             and boss in graveyard_rares else zone)
    return dict(kind="Dungeon", source="Dungeon: " + label + (" - " + boss if boss else ""),
                minLevel=DUNGEONS[zone])


def dungeon_and_craft_sources(builds, tables, items, rows):
    # Corroborate recipe and dungeon metadata with launch trainer observations or another
    # Forever item source. A recipe dropping from a boss is not the crafted gear itself.
    trainers = defaultdict(dict)
    for build in builds:
        for npc, trainer in read_map(build, "trainers", "trainers").items():
            for key, service in trainer.get("services", {}).items():
                trainers[int(key)][int(npc)] = (service, trainer)
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
                if spell not in trainers and "Crafted" not in cached.get("sourceTypes", []):
                    continue
                name = professions[prof - 1]
                if spell in trainers:
                    ranks = {a["skillRank"] for a, _ in trainers[spell].values()
                             if a.get("skill") == name and a.get("skillRank", 0) > 0}
                    if len(ranks) == 1:
                        rank = ranks.pop()
                route = dict(kind="Crafted", craftSpellID=spell, craftProfessionID=SKILLS[name],
                             craftProfessionRank=rank)
                if spell in trainers:
                    route["trainerRecipe"] = True
                personal_only = spell not in trainers and rank > 225
                if personal_only or item.get("binding") not in ("BoE", "Unbound", "Tradeable"):
                    route.update(acquireProfessionID=SKILLS[name], acquireProfessionRank=rank,
                                 professionID=SKILLS[name], professionRank=rank, requiresKnownCraft=True)
                route["source"] = f"Craft: {name} {rank}"
                if personal_only:
                    route.update(requiresCraftable=True, source=route["source"] + ". Your learned recipe and materials")
                elif item.get("binding") in ("BoE", "Unbound", "Tradeable"):
                    route["source"] += ". Buy the unbound item or ask a crafter"
                if item.get("wearProfessionID"):
                    required = next((n for n, value in SKILLS.items() if value == item["wearProfessionID"]), name)
                    route["source"] += f". Wear: {required} {item['wearProfessionRank']}"
                if spell in GOGGLE_RECIPES:
                    route["source"] += ". Materials: " + GOGGLE_RECIPES[spell] + "."
                    teachers = []
                    for npc in (5518, 3412):
                        if npc in trainers.get(spell, {}):
                            trainer = trainers[spell][npc][1]
                            teachers.append(trainer["name"] + (" (Alliance, Stormwind 62,31)" if npc == 5518
                                                              else " (Horde, Orgrimmar 76,25)"))
                    if teachers:
                        route["source"] += " Trainers: " + " / ".join(teachers) + "."
                    if spell == 3940:
                        route["source"] += " Learn Schematic: Shadow Goggles (#4410)."
                yield i, route
            elif token.startswith("d"):
                npc, _chance, zone = map(int, re.fullmatch(r"d(\d+)x(\d+)z(\d+)", token).groups())
                zone_name = tables["zones"].get(zone)
                if (zone_name not in DUNGEONS or "Dungeon" not in cached.get("sourceTypes", [])
                        or "Crafted" in cached.get("sourceTypes", [])):
                    continue
                boss = tables["npcs"].get(npc)
                if route := reference_dungeon(zone_name, boss):
                    yield i, route
    for row in rows:
        i = row["itemId"]
        if i not in items or "Crafted" in row["sourceTypes"]:
            continue
        # sourceTypes is a deduplicated set: several named sourceKeys can
        # share one type. Each sourceKey encodes its own expansion and type.
        keys = set(row["sourceKeys"])
        zones = [z for z in DUNGEONS if f"forever::dungeon::{z.lower()}" in keys]
        for zone in zones:
            bosses = row.get("bossNames", []) if len(zones) == 1 else []
            # A dungeon tag on a quest reward can identify the quest's area.
            # Only an independent source can establish an additional drop.
            if "Quest" in row["sourceTypes"] and not bosses:
                continue
            if route := reference_dungeon(zone, " / ".join(bosses)):
                yield i, route


def observed_creature_drops(builds, items):
    names, habitats = {}, defaultdict(set)
    for build in builds:
        for key, creature in read_map(build, "creatures", "creatures").items():
            if creature.get("name"):
                names[key] = creature["name"]
            habitats[key].update(p["instance"] for p in creature.get("positions", []) if "instance" in p)
        for key, creature in read_map(build, "creature_details.enUS", "creatures").items():
            if creature.get("name"):
                names[key] = creature["name"]
    for build in builds:
        for key, data in read_map(build, "loot", "sources").items():
            # spell: keys are skinning/pickpocket results, not normal corpse loot.
            source = re.fullmatch(r"npc:(\d+)(?:\|quest)?(?:\|group)?", key)
            if not source:
                continue
            mob = names.get(source[1])
            if not mob or BAD_NAME.search(mob):
                continue
            positions = {p.get("instance") for p in data.get("positions", [])} or habitats[source[1]]
            if positions and positions.issubset({0, 1, 2991}):
                route = dict(kind="Drop", source="World drop: " + mob)
            elif len(positions) == 1 and (zone := MAP_DUNGEONS.get(next(iter(positions)))):
                route = dict(kind="Dungeon", source=f"Dungeon: {zone} - {mob}", minLevel=DUNGEONS[zone])
            else:
                continue
            for raw, drop in data.get("items", {}).items():
                i = int(raw)
                if i in items and drop.get("drops", 0) > drop.get("shared", 0) and not drop.get("quest"):
                    yield i, route


def possible_world_drops(cache, rows, items, hotfixes, world_ids):
    # A valid live item response proves the item record exists, not where it
    # drops. The explicit flag is interpreted by Sources.lua (default off).
    classic = json.loads((cache / "Classic Era Cache.json").read_text(encoding="utf-8"))
    historical = {r["itemId"] for r in classic if r["sourceLabels"] == ["World drops"]}
    for row in rows:
        i = row["itemId"]
        if (i in world_ids or i not in historical or row["sourceTypes"] != ["Drop"]
                or hotfixes.get(str(i), {}).get("status") != "valid"
                or items.get(i, {}).get("binding") != "BoE"):
            continue
        text = POSSIBLE_SUFFIX_DROP if "&lt;Random enchantment&gt;" in row["tooltipHtml"] else POSSIBLE_DROP
        yield i, dict(kind="Drop", source=text, unconfirmed=True)


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
    if x == POSSIBLE_DROP:
        return "possibleDrop"
    if x == POSSIBLE_SUFFIX_DROP:
        return "possibleSuffixDrop"
    if isinstance(x, str):
        return json.dumps(x, ensure_ascii=False)
    if isinstance(x, bool):
        return str(x).lower()
    return str(x)


def generate(polestar, observations, cache, output):
    builds = [p for p in sorted((observations / "data/wowf").iterdir())
              if 70790 <= int(p.name.split(".")[-1]) <= 70938]
    items, tables, rows = acquire_items(polestar, cache)
    hotfixes = {}
    for build in builds:
        hotfixes.update(read_map(build, "item_hotfixes.enUS", "items"))
    for raw, response in hotfixes.items():
        if response["status"] in ("removed", "invalid"):
            items.pop(int(raw), None)
        elif response.get("name") and int(raw) in items:
            items[int(raw)].setdefault("name", response["name"])
    # Give unnamed common items the names actually seen on launch vendor lists.
    for build in builds:
        for seller in read_map(build, "vendors", "vendors").values():
            for listing in seller.get("entries", {}).values():
                if listing.get("itemId") in items and listing.get("name"):
                    items[listing["itemId"]].setdefault("name", listing["name"])
    routes = defaultdict(set)
    def add_routes(source):
        for i, route in source:
            if i in items and items[i].get("minLevel", 1) <= 60 and not BAD_NAME.search(items[i].get("name", "")):
                record = merged(items[i], i, route)
                if record:
                    routes[i].add(tuple(sorted(record.items())))
    for source in (quest_sources(builds, tables, items), dungeon_and_craft_sources(builds, tables, items, rows),
                   observed_boss_drops(builds, items), observed_creature_drops(builds, items),
                   container_routes(builds, items), vendor_routes(builds, items)):
        add_routes(source)
    world_ids = {i for i, variants in routes.items() if any(dict(v)["kind"] == "Drop" for v in variants)}
    add_routes(possible_world_drops(cache, rows, items, hotfixes, world_ids))
    header = ("-- Generated by tools/build_catalog.py; see DATA.md and licenses/.\n"
              "-- Data from Efficient Games (https://efficient.games), licensed under CC BY 4.0; modified.\n"
              "-- Includes ForeverLevelingBiS data (c) 2026 Thunder, MIT. Game facts (c) Blizzard.\n"
              "local _, A = ...\nA.Catalog = {}\n"
              f"local possibleDrop = {json.dumps(POSSIBLE_DROP)}\n"
              f"local possibleSuffixDrop = {json.dumps(POSSIBLE_SUFFIX_DROP)}\n"
              "local function add(item, routes)\n"
              "    for _, route in ipairs(routes) do\n"
              "        for k, v in pairs(item) do if route[k] == nil then route[k] = v end end\n"
              "        A.Catalog[#A.Catalog + 1] = route\n"
              "    end\nend\n")
    buf = [header]
    def lua_record(record):
        return "{" + ",".join(k + "=" + lua_scalar(v) for k, v in sorted(record.items())) + "}"
    counts, possible_counts, confirmed_ids = Counter(), Counter(), set()
    for i, variants in sorted(routes.items()):
        variants = [dict(t) for t in sorted(variants)]
        detailed_zones = {v["source"].split(" - ", 1)[0] for v in variants
                          if v["kind"] == "Dungeon" and " - " in v["source"]}
        variants = [v for v in variants if v["kind"] != "Dungeon" or v["source"] not in detailed_zones]
        fields = set.intersection(*[set(row.items()) for row in variants])
        item = dict(fields)
        # Keep source type/description with its route for easy auditing.
        shared = {k: v for k, v in item.items() if k not in ("kind", "source")}
        per_route = []
        for row in variants:
            if row.get("unconfirmed"):
                possible_counts[row["kind"]] += 1
            else:
                confirmed_ids.add(i)
                counts[row["kind"]] += 1
            per_route.append(lua_record({k: v for k, v in row.items() if k not in shared}))
        buf.append("add(" + lua_record(shared) + ",{" + ", ".join(per_route) + "})\n")
    output.write_text("".join(buf), encoding="utf-8", newline="\n")
    print(f"{len(confirmed_ids)} confirmed-source item IDs; {sum(counts.values())} routes: {dict(sorted(counts.items()))}")
    print(f"{len(routes) - len(confirmed_ids)} additional IDs from {sum(possible_counts.values())} opt-in routes; "
          f"{len(routes)} total unique item IDs")
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
