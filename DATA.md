# WoWBest catalog

The November 14, 2026 snapshot targets World of Warcraft: Forever 1.60.1 and includes 3,299 distinct equipment IDs across 4,852 acquisition routes. Several routes can lead to the same item. The full generated catalog ships with the addon. A player never needs to fetch data, install Python or install another addon.

| Acquisition | Routes | Evidence and typical detail |
| --- | ---: | --- |
| Quest reward | 1,252 | Launch server reward ID, pick-one or fixed reward, minimum level, quest title, and available class, race and side requirements |
| Dungeon | 668 | Launch boss loot rolls, or Forever dungeon listings with a named boss or a corroborated location |
| Crafted | 688 | Recipe and creating profession, with required skill rank |
| World drop | 854 | An outdoor NPC that players looted the item from on a launch build |
| Vendor | 1,286 | Observed merchant, map location, position and reported prices where recorded |
| PvP | 104 | Observed battleground quartermaster merchandise with available reputation or rank requirements |

Quest, profession and NPC names in the route text are in English. The item name, link, tooltip, level, equipment position and usable-item checks come from the current client. Some item IDs have multiple valid sellers or bosses. A vendor price reflects an observed standing or discount, and a world-drop source identifies one observed creature that dropped the item.

## Inputs and attribution

| Source | Pinned version | What WoWBest uses |
| --- | --- | --- |
| [Efficient Games, EG Link observations](https://github.com/JIVESCORP/eg-link-output-wowf/tree/ea970da071079b32e56f349e09648ff0e314b351) | ea970da071079b32e56f349e09648ff0e314b351 | Launch builds 70790, 70840, 70862, 70888 and 70938. Equipment drops, boss encounters, merchants, quest offers and completions, reported rewards, recipe trainer lists, and latest invalid or removed item IDs. |
| [Polestar ItemDB](https://github.com/fitzforge/polestar/tree/19bd636e7d6f33231770f6029c76d2d4dfc63798/addon/Polestar_ItemDB) | 19bd636e7d6f33231770f6029c76d2d4dfc63798 | ForeverLevelingBiS v0.12.0-beta by Thunder supplies per-item Forever stat supplements, named quest / dungeon / craft routes, and quest restrictions. The Classic Era table supplies item-type hints for ordinary lower-quality items where a Forever observation establishes a route. |
| [Napalmsteak, WoW Classic Item Caches](https://github.com/Napalmsteak/WoW-Classic-Item-Caches/tree/eff4560809de2e852e9164183e3edf5a795edd20) | eff4560809de2e852e9164183e3edf5a795edd20 | Equipment IDs, numeric restrictions, location and boss identifiers extracted from the Forever item cache. Its original tooltips, icons and descriptive text are not included in the addon. |

Data from [Efficient Games](https://efficient.games), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). WoWBest filters and normalizes source records, combines the resulting facts with the other inputs, and generates its own route descriptions. The full license and Thunder's MIT notice are in the installable [licenses folder](WoWBest/licenses). World of Warcraft and game content belong to Blizzard Entertainment.

## Coverage and access

- **Quests.** A quest must have launch server reward data and an observed offer, a recorded turn-in, or a named matching route in ForeverLevelingBiS. Quests at level 50 or higher also need an observed offer or turn-in. The generator omits event, raid and profession quests with unmodeled gates. It includes the two verified weekly rare-fish equipment exchanges under the conditions below. It handles the minimum acceptance level, status of one-time rewards, reported class or race masks, and mutually exclusive choices in the same reward window. Some chains involve prerequisite quests, group kills, or permanent choices between separate quest lines. The catalog cannot establish every one of those conditions.
- **Dungeon access.** Original instances use published entry thresholds. The nine new instances use the lower end of their announced level ranges as a conservative planning threshold when no verified portal minimum is available. Certain named quests or bosses also require keys, a summon, a particular encounter, or a group. Published dungeon data can change with hotfixes. [Dungeon overview](https://www.wowhead.com/forever/guide/dungeons-overview-locations-details) · [Blizzard launch announcement](https://worldofwarcraft.blizzard.com/en-us/news/24315820)
- **Crafts.** A recipe must be reported by a launch trainer, or match another Forever crafting source at skill 225 or below. The latter rule excludes speculative high-end patterns, including some recipes available in play. Tradeable crafts can be commissioned or purchased from other players. A bind-on-pickup craft requires the character to know the recipe and meet its profession rank for the current set. A trainer-taught recipe may appear in optional paths before it is learned. The generator keeps the wearer requirement, recipe spell and rank, and personal crafting requirement separately. Five common items absent from the uncommon gear cache have documented Forever auction listings, including Copper Axe and Linen Belt. Current listings and prices vary. [Copper Axe](https://forevermastery.com/en/recipes/2738-copper-axe) · [Tradeable low-level weapons](https://everloot.app/tools/auctions?class=weapons&sort=market) · [Tradeable common armor](https://everloot.app/tools/auctions?class=armor&house=horde&quality=common&sub=cloth)
- **Other sources.** The catalog excludes unknown routes, future raid loot, raw Classic-only world-drop claims and items the latest hotfix data marked invalid or removed. Raid openings, holidays, newly discovered NPCs and future patches will require refreshed source data. The snapshot covers observed world drops and a selection of battleground vendors. An auction listing, a random suffix roll or access to a particular group cannot be guaranteed.

## Worked example for a level-19 Warrior

A level-19 Warrior on either faction can wear cloth headgear. The item level describes a piece's power. Apply the actual character-level requirement and the personal skill required to wear it. The goggles below have no explicit character-level requirement. A level-19 Warrior who already has Engineering 100 can wear Flying Tiger Goggles immediately after obtaining them. Reaching 150 opens the higher-stamina Green Tinted pair.

| Head item | Power and equip gate | Where to get it |
| --- | --- | --- |
| **Flying Tiger Goggles**, 4368 | Item level 20. 27 armor, +4 Stamina, +4 Spirit. Wearer needs Engineering **100**. | Buy an unbound pair, commission an engineer, or craft using 6 Light Leather and 2 Tigerseye. Recipe 3934, Engineering 100, taught by the trainers below. |
| **Shadow Goggles**, 4373 | Item level 24. 31 armor, +5 Intellect, +6 Spirit. Wearer needs Engineering **120**. | Buy or commission the goggles. Self-crafting requires Engineering 120 and Schematic: Shadow Goggles (4410), plus 4 Medium Leather and 2 Shadowgem. The Intellect does little for a Warrior. |
| **Green Tinted Goggles**, 4385 | Item level 30. 35 armor, +8 Stamina, +7 Spirit. Wearer needs Engineering **150**. | Buy or commission the goggles, or craft with 4 Medium Leather, 2 Moss Agate and 1 Flying Tiger Goggles. Recipe 3956, Engineering 150, taught by the trainers below. |
| **Taurajo Headband**, 279391 | 28 armor. Horde quest available from **level 18**. No profession requirement. | Speak to **Sulhasa** in southern Barrens (48, 78) for *Field to Clear* (98093). The launch reward window offers the headband or Beastculler's Knife. |
| **Lucky Fishing Hat**, 19972 | Item level 40. 43 armor, +15 Stamina, +5 Fishing. Wearer needs **Fishing 1**. Binds on pickup. | During the Stranglethorn Fishing Extravaganza, catch **Keefer's Angelfish** (19805) in a tournament school. Turn it in to **Fishbot 5000** at Booty Bay (27, 77) for *Rare Fish – Keefer's Angelfish* (8221). Both factions have this path. |

**Alliance** can train both Flying Tiger and Green Tinted recipes at **Lilliam Sparkspindle** in Stormwind (62, 31). **Horde** can visit **Nogg** in Orgrimmar (76, 25). The same trainers offered Journeyman Engineer at character level 10 and Engineering 50, which opens the path to skill 150. A crafter can supply a finished pair to a Warrior on either faction. The wearer still needs the skill. [Observed Stormwind trainer](https://github.com/JIVESCORP/eg-link-output-wowf/blob/ea970da071079b32e56f349e09648ff0e314b351/data/wowf/1.60.1.70938/trainers.json) · [Observed Orgrimmar trainer](https://github.com/JIVESCORP/eg-link-output-wowf/blob/ea970da071079b32e56f349e09648ff0e314b351/data/wowf/1.60.1.70862/trainers.json) · [Flying Tiger recipe](https://www.wowhead.com/forever/spell=3934) · [Green Tinted recipe](https://azeroth.wiki/forever/professions/engineering/green-tinted-goggles) · [Shadow schematic](https://raiddex.com/en/wow-forever/items/schematic-shadow-goggles)

The fishing hat can appear as an optional path without a fish. To include an unowned hat in the current set, WoWBest conservatively requires the fish in carried inventory, Fishing 1, and the active turn-in quest. The active-quest check is the addon's way to confirm the turn-in. Players can catch the fish before accepting the quest. Nat Pagle's Extreme Anglin' Boots use the same checks with Brownell's Blue Striped Racer and quest 8225. The tournament normally runs Sundays 14:00–16:00 realm time. Check your realm's calendar for changes. [Tournament timing](https://www.icy-veins.com/wow-forever/fishing/) · [Launch quest rewards and required fish](https://github.com/JIVESCORP/eg-link-output-wowf/blob/ea970da071079b32e56f349e09648ff0e314b351/data/wowf/1.60.1.70862/quests.enUS.json) · [Fishbot and Sulhasa in launch NPC observations](https://github.com/JIVESCORP/eg-link-output-wowf/blob/ea970da071079b32e56f349e09648ff0e314b351/data/wowf/1.60.1.70862/npcs.json) · [Field to Clear](https://www.wowhead.com/forever/quest=98093)

## Set data and scoring

The set index contains 1,577 member IDs across 274 sets, including sets that can enter through a character’s bags or a detailed Auction House search. A set entry supplies membership and threshold facts. A character still needs an eligible source for each individual piece. Of 780 threshold effects, 389 have numerical models. The others remain visible when activated even when their effect has no assigned score. [Set sources and rebuild instructions](WoWBest/licenses/SET-DATA.txt)

## Reproduce the catalog

Use **Python 3.10+** and Git. These commands can be run from the root of a checked-out WoWBest repository on Windows (PowerShell), macOS or Linux. Put the upstream checkouts outside the addon. They contain the source data for every build, so a full checkout of the first repository may be large.

```text
git clone --filter=blob:none --no-checkout https://github.com/JIVESCORP/eg-link-output-wowf.git ../wowbest-eg
git -C ../wowbest-eg sparse-checkout init --cone
git -C ../wowbest-eg sparse-checkout set data/wowf/1.60.1.70790 data/wowf/1.60.1.70840 data/wowf/1.60.1.70862 data/wowf/1.60.1.70888 data/wowf/1.60.1.70938
git -C ../wowbest-eg checkout ea970da071079b32e56f349e09648ff0e314b351
git clone --filter=blob:none --no-checkout https://github.com/fitzforge/polestar.git ../wowbest-polestar
git -C ../wowbest-polestar sparse-checkout init --cone
git -C ../wowbest-polestar sparse-checkout set addon/Polestar_ItemDB
git -C ../wowbest-polestar checkout 19bd636e7d6f33231770f6029c76d2d4dfc63798
git clone --filter=blob:none --no-checkout https://github.com/Napalmsteak/WoW-Classic-Item-Caches.git ../wowbest-cache
git -C ../wowbest-cache sparse-checkout init --no-cone
git -C ../wowbest-cache sparse-checkout set "/Forever Cache.json"
git -C ../wowbest-cache checkout eff4560809de2e852e9164183e3edf5a795edd20
python tools/build_catalog.py --polestar ../wowbest-polestar --observations ../wowbest-eg --cache ../wowbest-cache
```

The generator validates the three pinned commit IDs and writes `WoWBest/Catalog.lua`. The expected SHA-256 is `76c22b35e3f76d8e7be44dcff9f79c3dbc5845321ddcec440d487ca6ed2f6c9f`. To update the snapshot, review upstream changes, adjust the pins and launch-build cutoff, recheck current dungeon and raid access, regenerate, and run the regression tests before shipping.
