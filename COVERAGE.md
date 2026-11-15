# Gear coverage by level

WoWBest has **4,732 items with supported Forever routes**. Turning on **Include unconfirmed sources** adds 2,209 distinct items with historical acquisition leads, for 6,941 total. At level 19 these counts are **1,577 supported** and **1,840 including leads**. At level 60 they are **4,732** and **6,941**. Each ID counts once at a level where any route meets its recorded level requirements.

The totals span every class, race, faction and specialization. In game, your character’s proficiencies, quest history, professional skills, reputation, source filters and equipment slots determine which pieces enter the rankings. Your bags and live Auction House results can add more candidates.

| Level | Supported | Including leads | Level | Supported | Including leads |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 180 | 180 | 31 | 2,582 | 3,355 |
| 2 | 234 | 234 | 32 | 2,648 | 3,468 |
| 3 | 279 | 279 | 33 | 2,682 | 3,547 |
| 4 | 354 | 354 | 34 | 2,715 | 3,630 |
| 5 | 485 | 488 | 35 | 2,831 | 3,798 |
| 6 | 572 | 584 | 36 | 2,880 | 3,902 |
| 7 | 654 | 670 | 37 | 2,928 | 3,998 |
| 8 | 699 | 723 | 38 | 3,012 | 4,134 |
| 9 | 760 | 790 | 39 | 3,043 | 4,217 |
| 10 | 899 | 941 | 40 | 3,187 | 4,480 |
| 11 | 938 | 993 | 41 | 3,210 | 4,567 |
| 12 | 1,018 | 1,094 | 42 | 3,256 | 4,673 |
| 13 | 1,109 | 1,197 | 43 | 3,281 | 4,758 |
| 14 | 1,157 | 1,271 | 44 | 3,312 | 4,849 |
| 15 | 1,288 | 1,434 | 45 | 3,448 | 5,049 |
| 16 | 1,342 | 1,517 | 46 | 3,477 | 5,135 |
| 17 | 1,461 | 1,663 | 47 | 3,546 | 5,254 |
| 18 | 1,530 | 1,761 | 48 | 3,656 | 5,415 |
| 19 | 1,577 | 1,840 | 49 | 3,697 | 5,508 |
| 20 | 1,727 | 2,023 | 50 | 3,849 | 5,710 |
| 21 | 1,776 | 2,109 | 51 | 3,879 | 5,791 |
| 22 | 1,877 | 2,254 | 52 | 3,953 | 5,918 |
| 23 | 1,926 | 2,345 | 53 | 4,027 | 6,038 |
| 24 | 1,990 | 2,449 | 54 | 4,150 | 6,211 |
| 25 | 2,088 | 2,588 | 55 | 4,233 | 6,333 |
| 26 | 2,139 | 2,689 | 56 | 4,332 | 6,471 |
| 27 | 2,163 | 2,761 | 57 | 4,395 | 6,572 |
| 28 | 2,275 | 2,912 | 58 | 4,502 | 6,696 |
| 29 | 2,336 | 3,015 | 59 | 4,503 | 6,710 |
| 30 | 2,545 | 3,269 | 60 | 4,732 | 6,941 |

## Acquisition routes

| Source | Supported routes | Supported items | Optional leads |
| --- | ---: | ---: | ---: |
| Crafted gear | 1,282 | 1,282 | 0 |
| World drops | 997 | 415 | 2,218 |
| Dungeons | 747 | 656 | 0 |
| PvP | 217 | 217 | 0 |
| Quests | 1,927 | 1,789 | 0 |
| Vendors | 1,319 | 374 | 0 |

## Comparison with the Forever item cache

The pinned Forever tooltip cache contains 10,192 level 1–60 equipment IDs with a recognized slot after filtering cosmetics and explicitly marked test items. WoWBest includes 3,864 of these via supported routes and 2,209 more via optional leads. Other inputs supply 868 additional IDs. The remaining 4,119 cache IDs have no packaged route. The game client can contain unreleased, obsolete and test equipment. A cached tooltip alone cannot establish how or whether a character can obtain an item. Look up an item by name or ID in the [unmapped items CSV](coverage/unmapped-items.csv).

The source labels below come from the cache. An item can have several labels. A match counts any packaged route for that item.

| Cache source label | Cache IDs | Supported | Lead only | No catalog route |
| --- | ---: | ---: | ---: | ---: |
| Crafted | 1,310 | 1,275 | 0 | 35 |
| Drop | 3,308 | 205 | 2,209 | 894 |
| Dungeon | 665 | 662 | 0 | 3 |
| Other | 1,835 | 362 | 0 | 1,473 |
| PvP | 353 | 122 | 0 | 231 |
| Quest | 1,599 | 1,138 | 0 | 461 |
| Vendor | 1,743 | 288 | 0 | 1,455 |

## Reproduce this report

Use Python 3.10 or newer, Lua 5.1 (or texlua) and the pinned tooltip cache checkout listed in [DATA.md](DATA.md).

```sh
python tools/audit_catalog.py --cache ../wowbest-cache --report-out COVERAGE.md --missing-out coverage/unmapped-items.csv
```

For a one-level breakdown by equipment slot, use `--level 19`. Add `--include-unconfirmed` to include optional leads in that breakdown.

Packaged Catalog.lua SHA-256: `1c1c45fdf88d1e6a82ddaa337edbd3268d6ef4fc30386fbb423ec8e91c16350a`.
