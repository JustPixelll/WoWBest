"""Extract numeric base-item facts from the pinned Forever cache (see DATA.md)."""
import argparse
from collections import defaultdict
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess

from build_catalog import PINS, ROOT

# A complete standalone sentence must match. The same formats drive the English
# live-tooltip parser, so random variants can use their own displayed numbers.
FORMATS = {
    "Equip: Increases damage and healing done by magical spells and effects by up to #.": ("shared",),
    "Equip: Increases healing done by up to # and damage done by up to # for all magical spells and effects.": ("heal", "sp"),
    "Equip: Increases healing done by magical spells and effects by up to #.": ("heal",),
    "Equip: Increases damage done by magical spells and effects by up to #.": ("sp",),
    "Equip: +# Attack Power.": ("ap",), "Equip: +# Ranged Attack Power.": ("rap",),
    "Equip: +# Attack Power against Humanoids.": ("humanoidAP",),
    "Equip: Improves your chance to hit by #%.": ("hit",),
    "Equip: Improves your chance to get a critical strike by #%.": ("crit",),
    "Equip: Increases your attack speed and casting speed by #%.": ("haste",),
    "Equip: Increased Defense +#.": ("defense",),
    "Equip: Increases your chance to Dodge an attack by #%.": ("dodge",),
    "Equip: Increases your chance to Parry an attack by #%.": ("parry",),
    "Equip: Increases your chance to Block attacks with a shield by #%.": ("block",),
    "Equip: Reduces chance to be Dodged or Parried by #%.": ("expertise",),
    "Equip: +# Weapon Damage.": ("flatWeapon",),
}
for school in ("Arcane", "Fire", "Frost", "Holy", "Nature", "Shadow"):
    FORMATS[f"Equip: Increases damage done by {school} spells and effects by up to #."] = ("sp" + school,)
for name, token in (("mana", "mpr"), ("health", "hpr")):
    for plus in ("+", ""):
        for prefix in ("", "Equip: "):
            FORMATS[f"{prefix}Restores {plus}# {name} per 5 sec."] = (token,)

PATTERNS = [(re.compile(re.escape(fmt).replace(r"\#", r"(\d[\d,]*(?:\.\d+)?)")), keys)
            for fmt, keys in FORMATS.items()]
PRIMARY = {"3": "agi", "4": "str", "5": "int", "6": "spi", "7": "sta", "50": "extraArmor"}


class PassiveLines(HTMLParser):
    """Top-level green numeric rows. Exclude linked ability and nested set text."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.parts = []
        self.lines = []
        self.linked = False
        self.triggered = False

    def handle_starttag(self, tag, attrs):
        if self.depth:
            if tag == "span":
                self.depth += 1
            if tag == "a":
                self.linked = True
        elif tag == "span" and dict(attrs).get("class") == "q2":
            self.depth = 1
            self.parts = []
            self.linked = False

    def handle_data(self, text):
        if self.depth:
            self.parts.append(text)

    def handle_endtag(self, tag):
        if self.depth and tag == "span":
            self.depth -= 1
            if not self.depth:
                line = "".join(self.parts).strip()
                if not self.linked:
                    self.lines.append(line)
                if line.startswith(("Use: ", "Chance on hit: ", "Equip: Chance on ")) or (
                    self.linked and line.startswith("Equip: ") and re.search(r"\b(?:a chance to|chance on)\b", line, re.I)
                ):
                    self.triggered = True


def facts(row):
    tip = row["tooltipHtml"]
    if not re.search(r"<!--scstart(?:2|4):", tip):
        return {}
    data = defaultdict(float)
    for stat, value in re.findall(r"<!--stat(\d+)-->([+-]\d+)", tip):
        if stat in PRIMARY:
            data[PRIMARY[stat]] += int(value)
    for token, pattern in (("armor", r"<!--amr-->(\d+) Armor"),
                           ("blockValue", r"<!--blk-->(\d+) Block")):
        match = re.search(pattern, tip)
        if match:
            data[token] = int(match[1])
    # A weapon may have multiple schools of damage. The displayed DPS uses
    # their combined range; never claim the first school is the full weapon.
    damage = re.findall(r"<!--dmg-->\s*(\d+)\s*-\s*(\d+)[^<]*Damage", tip)
    speed = re.search(r"<!--spd-->(\d+(?:\.\d+)?)", tip)
    dps = re.search(r"<!--dps-->\((\d+(?:\.\d+)?) damage per second\)", tip)
    if damage and speed and dps:
        attack_speed = float(speed[1])
        low, high = (sum(int(pair[i]) for pair in damage) for i in (0, 1))
        if attack_speed > 0 and abs((low + high) / (2 * attack_speed) - float(dps[1])) < .07:
            data.update(dmin=low, dmax=high, speed=round(attack_speed * 1000))
    parser = PassiveLines()
    parser.feed(tip.partition("<!--pvpEquip-->")[0])
    if parser.triggered:
        data["proc"] = 1
    for line in parser.lines:
        for pattern, keys in PATTERNS:
            match = pattern.fullmatch(line)
            if match:
                for key, value in zip(keys, match.groups()):
                    data[key] += float(value.replace(",", ""))
                break
    return dict(data)


def lua_pattern(fmt):
    # The supported English patterns are anchored. Numeric values use English
    # separators. A literal period or percent sign in an effect is significant.
    return "^" + "".join("([%d,]+%.?%d*)" if c == "#" else
                         "%" + c if c in "^$()%.[]*+-?" else c for c in fmt) + "$"


def render(cache):
    groups = defaultdict(list)
    for row in json.loads((cache / "Forever Cache.json").read_text(encoding="utf-8")):
        data = facts(row)
        if data:
            key = " ".join(k + format(v, "g") for k, v in sorted(data.items()))
            groups[key].append(row["itemId"])
    out = ["-- Generated by tools/build_tooltip_stats.py. Numeric item facts from the pinned Napalmsteak/WoW-Classic-Item-Caches Forever cache; see DATA.md.",
           "local _, A = ...", "A.PassiveTooltipRules = {"]
    for fmt, keys in FORMATS.items():
        out.append("    {" + ", ".join(json.dumps(s) for s in (lua_pattern(fmt), *keys)) + "},")
    out += ["}", "A.TooltipStatFallbacks = {}", "local base = A.TooltipStatFallbacks",
            "local function add(values, ids)", "    for _, id in ipairs(ids) do base[id] = values end", "end"]
    for key, ids in sorted(groups.items()):
        if len(ids) == 1:
            out.append(f"base[{ids[0]}] = {json.dumps(key)}")
        else:
            out.append(f"add({json.dumps(key)}, {{" + ",".join(map(str, sorted(ids))) + "})")
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--cache", required=True, type=Path)
    args = ap.parse_args()
    revision = subprocess.check_output(["git", "-C", args.cache, "rev-parse", "HEAD"], text=True).strip()
    if revision != PINS["cache"][1]:
        ap.error("Use the pinned cache revision " + PINS["cache"][1])
    (ROOT / "WoWBest/TooltipStats.lua").write_text(render(args.cache), encoding="utf-8", newline="\n")
