"""Audit the shipped catalog. Run from any directory with Python 3.10+ and Lua.

    python tools/audit_catalog.py
    python tools/audit_catalog.py --level 19 --faction Horde --class-id 1 --race-id 2
    python tools/audit_catalog.py --cache ../wowbest-cache --missing-out missing.csv

Counts describe the static catalog before live proficiency, quest state, skills,
source settings, ownership and group access. A tooltip without a catalog route
is a research lead. It does not establish availability on a live realm.
"""
import argparse
from collections import Counter, defaultdict
import csv
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
CLASS_IDS = (1, 2, 3, 4, 5, 7, 8, 9, 11)
RACE_BITS = {**{n: n - 1 for n in range(1, 9)}, 95: 32, 96: 33}
SLOTS = {
    1: "Head", 2: "Neck", 3: "Shoulder", 16: "Back", 5: "Chest", 20: "Chest", 9: "Wrist",
    10: "Hands", 6: "Waist", 7: "Legs", 8: "Feet", 11: "Ring", 12: "Trinket", 13: "1H",
    21: "Main-hand", 22: "Off-hand weapon", 17: "2H", 14: "Shield", 23: "Held item",
    15: "Ranged", 25: "Ranged", 26: "Ranged", 28: "Relic",
}
SLOT_NAMES = list(dict.fromkeys(SLOTS.values()))
SOURCE_NAMES = {"Drop": "World drops", "Quest": "Quests", "Crafted": "Crafted gear",
                "Dungeon": "Dungeons", "Vendor": "Vendors", "PvP": "PvP", "Auction": "Auction House"}


@dataclass(frozen=True)
class Route:
    id: int
    kind: str
    slot: str
    minimum: int
    maximum: int
    faction: str
    class_mask: int
    race_mask: int
    unconfirmed: bool = False


def load_catalog(path, lua):
    # Let Lua execute the actual shipped representation, including shared
    # defaults and alternative routes. The exported fields contain no free text.
    script = """
local A = {}
assert(loadfile(arg[1]))("WoWBest", A)
for _, row in ipairs(A.Catalog) do
    print(table.concat({row.id, row.kind, row.invType, row.minLevel, row.maxLevel or 60,
        row.faction or "", row.classMask or 0, row.raceMask or 0, row.unconfirmed and 1 or 0}, "\\t"))
end
"""
    with tempfile.TemporaryDirectory() as temp:
        script_file = Path(temp) / "read_catalog.lua"
        script_file.write_text(script, encoding="utf-8")
        output = subprocess.check_output([lua, str(script_file), str(path)], text=True)
    rows = []
    for line in output.splitlines():
        ident, kind, inv_type, lo, hi, faction, classes, races, unconfirmed = line.split("\t")
        rows.append(Route(int(ident), kind, SLOTS[int(inv_type)], int(lo), int(hi),
                          faction, int(classes), int(races), unconfirmed == "1"))
    return rows


def matches_mask(mask, bit):
    return bit is None or mask in (0, -1) or bool(mask & (1 << bit))


def by_level(rows, faction=None, class_id=None, race_id=None, include_unconfirmed=False):
    class_bit = None if class_id is None else class_id - 1
    race_bit = RACE_BITS.get(race_id)
    levels = {level: defaultdict(set) for level in range(1, 61)}
    for row in rows:
        if (row.unconfirmed and not include_unconfirmed) or (row.faction and faction and row.faction != faction):
            continue
        if not (matches_mask(row.class_mask, class_bit) and matches_mask(row.race_mask, race_bit)):
            continue
        for level in range(max(1, row.minimum), min(row.maximum, 60) + 1):
            levels[level][row.slot].add(row.id)
    return levels


def compare_cache(cache, catalog_ids):
    from build_catalog import BAD_NAME, from_tooltip

    if cache.is_dir():
        cache = cache / "Forever Cache.json"
    with cache.open(encoding="utf-8") as stream:
        upstream = json.load(stream)
    groups = defaultdict(set)
    missing = {}
    for row in upstream:
        item = from_tooltip(row)
        if (not item or item["invType"] not in SLOTS or item["minLevel"] > 60
                or item["classID"] not in (2, 4) or (item["classID"], item["subclassID"]) == (4, 5)
                or BAD_NAME.search(row["name"])):
            continue
        ident = row["itemId"]
        labels = sorted(set(row.get("sourceTypes") or ["Unspecified"]))
        for label in labels:
            groups[label].add(ident)
        if ident not in catalog_ids:
            missing[ident] = (ident, row["name"], item["minLevel"], SLOTS[item["invType"]], ", ".join(labels))
    return groups, missing


def write_report(path, rows, groups, catalog_path):
    levels = by_level(rows)
    with_leads = by_level(rows, include_unconfirmed=True)
    all_ids = {r.id for r in rows}
    supported = {r.id for r in rows if not r.unconfirmed}
    cache_ids = set().union(*groups.values())
    counts = {n: len(set().union(*slots.values())) for n, slots in levels.items()}
    totals = {n: len(set().union(*slots.values())) for n, slots in with_leads.items()}
    lines = [
        "# Gear coverage by level", "",
        f"WoWBest has **{len(supported):,} items with supported Forever routes**. Turning on **Include "
        f"unconfirmed sources** adds {len(all_ids - supported):,} distinct items with historical acquisition "
        f"leads, for {len(all_ids):,} total. At level 19 these counts are **{counts[19]:,} supported** "
        f"and **{totals[19]:,} including leads**. At level 60 they are **{counts[60]:,}** and "
        f"**{totals[60]:,}**. Each ID counts once at a level where any route meets its recorded level requirements.", "",
        "The totals span every class, race, faction and specialization. In game, your character’s proficiencies, "
        "quest history, professional skills, reputation, source filters and equipment slots determine which "
        "pieces enter the rankings. Your bags and live Auction House results can add more candidates.", "",
        "| Level | Supported | Including leads | Level | Supported | Including leads |",
        "| ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for n in range(1, 31):
        cells = [f"{level} | {counts[level]:,} | {totals[level]:,}" for level in (n, n + 30)]
        lines.append("| " + " | ".join(cells) + " |")
    lines += ["", "## Acquisition routes", "", "| Source | Supported routes | Supported items | Optional leads |",
              "| --- | ---: | ---: | ---: |"]
    for kind in sorted({r.kind for r in rows}):
        matching = [r.id for r in rows if r.kind == kind and not r.unconfirmed]
        optional = sum(r.kind == kind and r.unconfirmed for r in rows)
        lines.append(f"| {SOURCE_NAMES.get(kind, kind)} | {len(matching):,} | {len(set(matching)):,} | {optional:,} |")
    lines += [
        "", "## Comparison with the Forever item cache", "",
        f"The pinned Forever tooltip cache contains {len(cache_ids):,} level 1–60 equipment IDs with a "
        f"recognized slot after filtering cosmetics and explicitly marked test items. WoWBest includes "
        f"{len(cache_ids & supported):,} of these via supported routes and {len((cache_ids & all_ids) - supported):,} "
        f"more via optional leads. Other inputs supply {len(all_ids - cache_ids):,} additional IDs. "
        f"The remaining {len(cache_ids - all_ids):,} cache IDs have no packaged route. The game client "
        "can contain unreleased, obsolete and test equipment. A cached tooltip alone cannot establish how or "
        "whether a character can obtain an item. Look up an item by name or ID in the "
        "[unmapped items CSV](coverage/unmapped-items.csv).", "",
        "The source labels below come from the cache. An item can have several labels. A match counts any "
        "packaged route for that item.", "",
        "| Cache source label | Cache IDs | Supported | Lead only | No catalog route |", "| --- | ---: | ---: | ---: | ---: |",
    ]
    for label, ids in sorted(groups.items()):
        lines.append(f"| {label} | {len(ids):,} | {len(ids & supported):,} | {len((ids & all_ids) - supported):,} | {len(ids - all_ids):,} |")
    lines += [
        "", "## Reproduce this report", "",
        "Use Python 3.10 or newer, Lua 5.1 (or texlua) and the pinned tooltip cache checkout "
        "listed in [DATA.md](DATA.md).", "", "```sh",
        "python tools/audit_catalog.py --cache ../wowbest-cache --report-out COVERAGE.md --missing-out coverage/unmapped-items.csv",
        "```", "",
        "For a one-level breakdown by equipment slot, use `--level 19`. Add `--include-unconfirmed` to "
        "include optional leads in that breakdown.", "",
        f"Packaged Catalog.lua SHA-256: `{hashlib.sha256(catalog_path.read_bytes()).hexdigest()}`.", "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--catalog", type=Path, default=ROOT / "WoWBest/Catalog.lua")
    parser.add_argument("--lua", help="Lua interpreter (default: lua5.1, lua or texlua on PATH)")
    parser.add_argument("--level", type=int, choices=range(1, 61), metavar="1-60", help="show one level")
    parser.add_argument("--faction", choices=["Alliance", "Horde"])
    parser.add_argument("--class-id", choices=CLASS_IDS, type=int, help="apply explicit class masks")
    parser.add_argument("--race-id", choices=RACE_BITS, type=int, help="apply explicit race masks")
    parser.add_argument("--include-unconfirmed", action="store_true", help="include optional leads in the level table")
    parser.add_argument("--cache", type=Path, help="pinned Forever tooltip cache checkout or JSON file")
    parser.add_argument("--missing-out", type=Path, help="write unmatched tooltip IDs to a CSV for investigation")
    parser.add_argument("--report-out", type=Path, help="write the full level 1–60 Markdown coverage report")
    args = parser.parse_args()
    if (args.missing_out or args.report_out) and not args.cache:
        parser.error("--missing-out and --report-out require --cache")
    lua = args.lua or next((p for name in ("lua5.1", "lua", "texlua") if (p := shutil.which(name))), None)
    if not lua:
        parser.error("Lua is required to load the packaged catalog. Supply --lua /path/to/lua.")
    rows = load_catalog(args.catalog, lua)
    ids = {row.id for row in rows}
    supported_ids = {row.id for row in rows if not row.unconfirmed}
    print(f"Catalog: {len(supported_ids):,} supported items, {len(ids - supported_ids):,} additional optional "
          f"items, {len(ids):,} total and {len(rows):,} acquisition routes.")
    print("Acquisition\tSupported routes\tSupported items\tOptional leads")
    kinds = Counter(row.kind for row in rows)
    for kind, count in sorted(kinds.items()):
        supported = [r.id for r in rows if r.kind == kind and not r.unconfirmed]
        print(kind, len(supported), len(set(supported)), count - len(supported), sep="\t")
    levels = by_level(rows, args.faction, args.class_id, args.race_id, args.include_unconfirmed)
    print("\nDistinct items with a level-appropriate route. Includes conditional routes. "
          "Class/race selections apply explicit masks only; proficiency and personal access are checked in game. "
          + ("Optional historical leads included." if args.include_unconfirmed else "Supported routes only."))
    print("Level", "All", *SLOT_NAMES, sep="\t")
    for level in ([args.level] if args.level else levels):
        slots = levels[level]
        print(level, len(set().union(*slots.values())), *(len(slots[s]) for s in SLOT_NAMES), sep="\t")
    if args.cache:
        groups, missing = compare_cache(args.cache, ids)
        cached = set().union(*groups.values())
        print(f"\nFull cache comparison: {len(cached):,} level 1-60 gear IDs with recognized slots, "
              f"{len(cached & ids):,} in catalog, {len(missing):,} absent. "
              f"The catalog includes {len(ids - cached):,} additional IDs.")
        print("Cache source labels overlap. Presence means any catalog route; missing items can be unavailable.")
        print("Cache label", "Cache IDs", "In catalog", "Absent", sep="\t")
        for label, group in sorted(groups.items()):
            print(label, len(group), len(group & ids), len(group - ids), sep="\t")
        if args.report_out:
            write_report(args.report_out, rows, groups, args.catalog)
        if args.missing_out:
            args.missing_out.parent.mkdir(parents=True, exist_ok=True)
            with args.missing_out.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.writer(stream, lineterminator="\n")
                writer.writerow(("id", "name", "minimum_equip_level", "slot", "cache_source_labels"))
                writer.writerows(sorted(missing.values(), key=lambda r: (r[2], r[3], r[1].casefold(), r[0])))


if __name__ == "__main__":
    main()
