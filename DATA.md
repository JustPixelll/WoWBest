# WoWBest catalog

The November 14, 2026 snapshot targets World of Warcraft: Forever 1.60.1 and includes 3,299 distinct equipment IDs across 4,852 acquisition routes. Several routes can lead to the same item. The full generated catalog ships with the addon. A player never needs to fetch data, install Python or install another addon.

| Acquisition | Routes | Evidence and typical detail |
| --- | ---: | --- |
| Quest reward | 1,250 | Launch server reward ID, pick-one or fixed reward, minimum level, quest title, and available class, race and side requirements |
| Dungeon | 669 | Launch boss loot rolls, or Forever dungeon listings with a named boss or a corroborated location |
| Crafted | 688 | Recipe and creating profession, with required skill rank |
| World drop | 854 | An outdoor NPC that players looted the item from on a launch build |
| Vendor | 1,287 | Observed merchant, map location, position and reported prices where recorded |
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

- **Quests.** A quest must have launch server reward data and an observed offer, a recorded turn-in, or a named matching route in ForeverLevelingBiS. Quests at level 50 or higher also need an observed offer or turn-in. The generator omits known event, raid and profession quest categories with unmodeled gates. It handles the minimum acceptance level, status of one-time rewards, reported class or race masks, and mutually exclusive choices in the same reward window. Some chains involve prerequisite quests, group kills, or permanent choices between separate quest lines. The catalog cannot establish every one of those conditions.
- **Dungeon access.** Original instances use published entry thresholds. The nine new instances use the lower end of their announced level ranges as a conservative planning threshold when no verified portal minimum is available. Certain named quests or bosses also require keys, a summon, a particular encounter, or a group. Published dungeon data can change with hotfixes. [Dungeon overview](https://www.wowhead.com/forever/guide/dungeons-overview-locations-details) · [Blizzard launch announcement](https://worldofwarcraft.blizzard.com/en-us/news/24315820)
- **Crafts.** A recipe must be reported by a launch trainer, or match another Forever crafting source at skill 225 or below. The latter rule excludes speculative high-end patterns, including some recipes available in play. Tradeable crafts can be commissioned or purchased from other players. A known bind-on-pickup craft has a personal profession gate. Specialized recipes and the present supply of reagents are not exhaustively modeled.
- **Other sources.** The catalog excludes unknown routes, future raid loot, raw Classic-only world-drop claims and items the latest hotfix data marked invalid or removed. Raid openings, holidays, newly discovered NPCs and future patches will require refreshed source data. The snapshot covers observed world drops and a selection of battleground vendors. An auction listing, a random suffix roll or access to a particular group cannot be guaranteed.

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

The generator validates the three pinned commit IDs and writes `WoWBest/Catalog.lua`. The expected SHA-256 is `cd29538366c593ea2f9872bcddfe31e584572c49a3a87f6cf27085ba1961409b`. To update the snapshot, review upstream changes, adjust the pins and launch-build cutoff, recheck current dungeon and raid access, regenerate, and run the regression tests before shipping.
