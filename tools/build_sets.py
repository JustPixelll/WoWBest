"""Extract numeric set facts from the pinned Forever edition of the item cache."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SHA256 = "86a387d5274635ebff1589b8702792fc8c0bfdb55df2ae29ec31a4c894f18e3a"
HEADER = re.compile(r'/forever/item-set=(\d+)/[^"]*"[^>]*>([^<]+)</a> \(\d+/\d+\)</span>(.*?)<div class="q0 indent">', re.S)
MEMBER = re.compile(r'<!--si[\d:]*--><a href="/forever/item=(\d+)/')
BONUS = re.compile(r'\((\d+)\) Set\s*:\s*<a href="/forever/spell=(\d+)/([^"]*)"[^>]*>(.*?)</a>', re.S)
SKILLS = {"Tailoring": 197, "Blacksmithing": 164, "Leatherworking": 165}
ATTR = {k.lower(): k.upper().replace(" ", "_") for k in
        ("Strength", "Agility", "Intellect", "Stamina", "Spirit", "Attack Power", "Armor")}
# Sources are listed in licenses/SET-DATA.txt. The cached membership blocks of
# these three sets have no linked effects. Preserve missing spell IDs as nil.
EXTRA = {
    520: [(2, "+200 Armor.", None), (3, "", "Spell targets lose 5 magical resistance."),
          (4, "", "10% lower chance for silences and interrupts to hit you."),
          (5, "Increases damage and healing done by magical spells and effects by up to 23.", None),
          (6, "", "15% less incoming damage while stunned.")],
    2135: [(2, "+100 Armor.", None), (3, "Increased Defense +5.", None),
           (4, "", "Blocking can heal for 14–23. Strongholds and cities double the heal."),
           (5, "", "Incoming damage can stack +1 stamina for 30 seconds, up to 20 stacks.")],
    2136: [(2, "", "Fire resistance +10."), (3, "+15 Stamina.", None),
           (4, "", "Sword skill +1."),
           (5, "", "Melee proc grants 2% critical strike for 20 seconds, doubled in swamps.")],
}
# Brief original fallbacks for early / commonly acquired conditional effects.
# The runtime prefers the current client's spell description.
LABELS = {
    14707: "Arcane resistance +5.", 1292025: "15 attack power against humanoids.",
    1292028: "Strikes from behind can cause a bleed.", 7534: "Dagger skill +1.",
    1291796: "Low-health damage can trigger health and mana recovery.", 1291807: "Melee hits can stun.",
    1321560: "Low mana can trigger a terrain-dependent mana return.",
    1321587: "Healing spells can add healing over time.",
    1324318: "Damaging spells can enable mana regeneration while casting.",
    1324323: "Damaging spells can summon an arcane elemental.",
    1293674: "Incoming damage can empower melee hits with holy damage.",
    1293670: "Low-health damage can trigger an absorb shield.",
    1317039: "Melee attacks can temporarily grant 50 strength.",
    1213289: "Targets dodge or parry attacks 2% less often.",
}


def stat(token):
    return "RESISTANCE0_NAME" if token == "ARMOR" else "ITEM_MOD_" + token + "_SHORT"


def model(text):
    """Only whole-line, unconditional effects with a matching unit enter the score."""
    number = r"(\d+)"
    single = (
        (r"\+(\d+) (Strength|Agility|Intellect|Stamina|Spirit|Attack Power|Armor)\.", "plus"),
        (r"Increased (Defense|Spirit) \+(\d+)\.?", "increased"),
        (rf"Restores {number} (mana|health) per 5 sec\.", "regen"),
        (rf"Increases damage and healing done by magical spells and effects by up to {number}\.", "universal"),
        (rf"Increases healing done by spells and effects by up to {number}\.", "heal"),
        (rf"Increases damage done by (Arcane|Fire|Frost|Holy|Nature|Shadow) spells and effects by up to {number}\.", "school"),
        (r"Improves your chance to hit by (\d+(?:\.\d+)?)%\.", "hit"),
        (r"Improves your chance to get a critical strike by (\d+(?:\.\d+)?)%\.", "crit"),
        (rf"Increases healing done by (?:spells and effects by )?up to {number} and damage done by (?:spells and effects by )?up to {number}(?: for all magical spells and effects)?\.", "mixed"),
    )
    for pattern, kind in single:
        match = re.fullmatch(pattern, text)
        if not match:
            continue
        args = match.groups()
        if kind == "plus":
            return {stat(ATTR[args[1].lower()]): int(args[0])}, f"{args[1]} +{args[0]}"
        if kind == "increased":
            key = "DEFENSE_SKILL" if args[0] == "Defense" else stat("SPIRIT")
            return {key: int(args[1])}, f"{args[0]} +{args[1]}"
        if kind == "regen":
            key = "MANA_REGENERATION" if args[1] == "mana" else "HEALTH_REGEN"
            return {stat(key): int(args[0])}, f"{args[0]} {args[1]} per 5 seconds"
        if kind in ("universal", "heal"):
            key = "SPELL_POWER" if kind == "universal" else "SPELL_HEALING_DONE"
            return {stat(key): int(args[0])}, ("Spell power" if kind == "universal" else "Healing") + f" +{args[0]}"
        if kind == "school":
            return {stat(args[0].upper() + "_SPELL_DAMAGE"): int(args[1])}, f"{args[0]} damage +{args[1]}"
        if kind == "mixed":
            return {stat("SPELL_HEALING_DONE"): int(args[0]), stat("SPELL_DAMAGE_DONE"): int(args[1])}, f"Healing +{args[0]}, spell damage +{args[1]}"
        return {kind.upper() + "_PERCENT": float(args[0])}, f"{kind.title()} chance +{float(args[0]):g}%"
    return None, None


def read_sets(raw):
    sets = {}
    # Use post-launch tooltip observations only. Full membership links are
    # required: some inherited placeholder sets list empty or invented items.
    for record in json.loads(raw):
        if record.get("itemExpansion") != "Forever":
            continue
        tip = record["tooltipHtml"]
        header = HEADER.search(tip)
        if not header:
            continue
        sid, name, gate = int(header[1]), html.unescape(header[2]), header[3]
        if record["lastUpdatedAt"] < "2026-11-04" and sid not in {1, 124}:
            continue  # the two prelaunch rows above were reconfirmed on live builds
        members = sorted({int(value) for value in MEMBER.findall(tip)})
        if not members or record["itemId"] not in members:
            continue
        bonuses = []
        for threshold, spell, slug, effect in BONUS.findall(tip):
            spell = int(spell)
            text = html.unescape(re.sub(r"<[^>]+>", "", effect))
            stats, label = model(text)
            if not label:
                label = LABELS.get(spell)
                if not label:
                    # ID and this short title identify the effect when a client's
                    # localized spell information is unavailable on first use.
                    label = slug.replace("-", " ").capitalize()
            bonuses.append((int(threshold), spell, label, stats))
        skill = None
        if gate:
            match = re.search(r'>([A-Za-z]+)</a> \((\d+)\)', gate)
            if not match or match[1] not in SKILLS:
                raise ValueError(f"Unrecognized activation gate on set {sid}: {gate}")
            skill = (SKILLS[match[1]], int(match[2]), match[1])
        candidate = (name, members, sorted(bonuses), skill)
        previous = sets.get(sid)
        if previous and previous != candidate:
            raise ValueError(f"Inconsistent data for set {sid}")
        sets[sid] = candidate
    for sid, effects in EXTRA.items():
        name, members, previous, gate = sets[sid]
        if previous:
            raise ValueError(f"Review manual supplement: cache now lists effects for set {sid}")
        bonuses = []
        for pieces, text, note in effects:
            stats, label = model(text)
            bonuses.append((pieces, None, note or label, stats))
        sets[sid] = (name, members, bonuses, gate)
    return sets


def dump(value):
    return json.dumps(value, ensure_ascii=False)


def write(sets, target):
    # Register grouped records once to keep the addon small. The output is
    # deterministic and entirely local to make it reviewable in version control.
    lines = ['-- Generated by tools/build_sets.py. See licenses/SET-DATA.txt.',
             'local _, A = ...', 'A.ItemSetIDs, A.SetThresholds, A.SetNames, A.SetSkills = {}, {}, {}, {}',
             'local function register(id, name, members, thresholds, skill)',
             '    A.SetNames[id], A.SetThresholds[id], A.SetSkills[id] = name, thresholds, skill',
             '    for _, itemID in ipairs(members) do A.ItemSetIDs[itemID] = id end', 'end', '']
    assigned = {}
    for sid, (name, members, bonuses, gate) in sorted(sets.items()):
        if not bonuses:
            continue
        for item in members:
            assert item not in assigned, (sid, item)
            assigned[item] = sid
        lines.append(f'register({sid}, {dump(name)}, {{{", ".join(map(str, members))}}}, {{')
        for pieces, spell, label, stats in bonuses:
            fields = [f"pieces={pieces}"]
            if spell:
                fields.append(f"spellID={spell}")
            fields.append(f"description={dump(label)}")
            if spell == 1292025:  # Forever Defias Leather: a conditional AP bonus
                stats = {stat("ATTACK_POWER"): 15}
                fields.append('targetType="Humanoid"')
            if stats:
                kv = ", ".join(f"{k}={v:g}" for k, v in sorted(stats.items()))
                fields.append(f"stats={{{kv}}}")
            lines.append("    {" + ", ".join(fields) + "},")
        gate_arg = f', {{id={gate[0]}, rank={gate[1]}, name={dump(gate[2])}}}' if gate else ''
        lines.append('}' + gate_arg + ')')
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")
    used = [bonuses for _, _, bonuses, _ in sets.values() if bonuses]
    print(f"{len(used)} sets, {len(assigned)} items, {sum(map(len, used))} effects, "
          f"{sum(bool(r[3]) or r[1] == 1292025 for rows in used for r in rows)} scored effects.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True, help="Pinned 'Forever Cache.json' file")
    args = parser.parse_args()
    data = args.cache.read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit("Unexpected cache version. See WoWBest/licenses/SET-DATA.txt.")
    write(read_sets(data), ROOT / "WoWBest" / "SetData.lua")
