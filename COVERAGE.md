# Gear coverage by level

WoWBest has **4,733 items with supported Forever routes**. Turning on **Include unconfirmed sources** adds 2,209 distinct items with historical acquisition leads, for 6,942 total. At level 19 these counts are **1,577 supported** and **1,840 including leads**. At level 60 they are **4,733** and **6,942**. Each ID counts once at a level where any route meets its recorded level requirements.

The totals span every class, race, faction and specialization. In game, your character’s proficiencies, quest history, professional skills, reputation, source filters and equipment slots determine which pieces enter the rankings. Your bags and live Auction House results can add more candidates.

| Level | Supported | Including leads | Level | Supported | Including leads |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 180 | 180 | 31 | 2,584 | 3,357 |
| 2 | 234 | 234 | 32 | 2,650 | 3,470 |
| 3 | 279 | 279 | 33 | 2,684 | 3,549 |
| 4 | 354 | 354 | 34 | 2,717 | 3,632 |
| 5 | 485 | 488 | 35 | 2,833 | 3,800 |
| 6 | 572 | 584 | 36 | 2,882 | 3,904 |
| 7 | 654 | 670 | 37 | 2,929 | 3,999 |
| 8 | 699 | 723 | 38 | 3,013 | 4,135 |
| 9 | 760 | 790 | 39 | 3,044 | 4,218 |
| 10 | 899 | 941 | 40 | 3,188 | 4,481 |
| 11 | 938 | 993 | 41 | 3,211 | 4,568 |
| 12 | 1,018 | 1,094 | 42 | 3,257 | 4,674 |
| 13 | 1,109 | 1,197 | 43 | 3,282 | 4,759 |
| 14 | 1,157 | 1,271 | 44 | 3,313 | 4,850 |
| 15 | 1,288 | 1,434 | 45 | 3,449 | 5,050 |
| 16 | 1,342 | 1,517 | 46 | 3,478 | 5,136 |
| 17 | 1,461 | 1,663 | 47 | 3,547 | 5,255 |
| 18 | 1,530 | 1,761 | 48 | 3,657 | 5,416 |
| 19 | 1,577 | 1,840 | 49 | 3,698 | 5,509 |
| 20 | 1,727 | 2,023 | 50 | 3,850 | 5,711 |
| 21 | 1,776 | 2,109 | 51 | 3,880 | 5,792 |
| 22 | 1,877 | 2,254 | 52 | 3,954 | 5,919 |
| 23 | 1,926 | 2,345 | 53 | 4,028 | 6,039 |
| 24 | 1,990 | 2,449 | 54 | 4,151 | 6,212 |
| 25 | 2,088 | 2,588 | 55 | 4,234 | 6,334 |
| 26 | 2,139 | 2,689 | 56 | 4,333 | 6,472 |
| 27 | 2,163 | 2,761 | 57 | 4,396 | 6,573 |
| 28 | 2,275 | 2,912 | 58 | 4,503 | 6,697 |
| 29 | 2,336 | 3,015 | 59 | 4,504 | 6,711 |
| 30 | 2,547 | 3,271 | 60 | 4,733 | 6,942 |

## Acquisition routes

| Source | Supported routes | Supported items | Optional leads |
| --- | ---: | ---: | ---: |
| Crafted gear | 1,282 | 1,282 | 0 |
| World drops | 997 | 415 | 2,218 |
| Dungeons | 759 | 658 | 0 |
| PvP | 217 | 217 | 0 |
| Quests | 1,927 | 1,789 | 0 |
| Vendors | 1,319 | 374 | 0 |

## Comparison with the Forever item cache

The pinned Forever tooltip cache contains 10,192 level 1–60 equipment IDs with a recognized slot after filtering cosmetics and explicitly marked test items. WoWBest includes 3,865 of these via supported routes and 2,209 more via optional leads. Other inputs supply 868 additional IDs. The remaining 4,118 cache IDs have no packaged route. The game client can contain unreleased, obsolete and test equipment. A cached tooltip alone cannot establish how or whether a character can obtain an item. Look up an item by name or ID in the [unmapped items CSV](coverage/unmapped-items.csv).

The source labels below come from the cache. An item can have several labels. A match counts any packaged route for that item.

| Cache source label | Cache IDs | Supported | Lead only | No catalog route |
| --- | ---: | ---: | ---: | ---: |
| Crafted | 1,310 | 1,275 | 0 | 35 |
| Drop | 3,308 | 205 | 2,209 | 894 |
| Dungeon | 665 | 663 | 0 | 2 |
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

Packaged Catalog.lua SHA-256: `cab24c068dec9d8878c2653e2ba7346c47729f4efbbfbde8a50a8acafcba8f99`.
