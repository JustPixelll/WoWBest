# WoWBest

WoWBest finds a gear set to work toward **at your character’s current level** in World of Warcraft: Forever. Type **`/wowbest`** to see the recommended items, their sources and which two pieces can actually be worn together.

**[Download WoWBest 1.2 for Forever](https://github.com/JustPixelll/WoWBest/raw/refs/heads/main/downloads/WoWBest.zip)** · [Gear data and coverage](DATA.md)

**Already have WoWBest?** Exit the game, extract the download, and replace the `WoWBest` folder in `_forever_\Interface\AddOns`. Start Forever, open `/wowbest`, and click a slot. Existing character preferences carry over.

## Install on Windows

1. Exit WoW completely. In **Battle.net**, select **World of Warcraft**, choose **World of Warcraft: Forever**, then use the gear beside **Play** and choose **Show in Explorer**.
2. Open the **`_forever_`** directory, then **`Interface\AddOns`**. If Explorer already shows the contents of `_forever_`, go straight to `Interface\AddOns`. Create `Interface` or `AddOns` if missing. A typical full path is `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns`.
3. Download **WoWBest.zip** from the link above. Right-click it, select **Extract All**, and extract into the **`AddOns`** directory. The archive already contains a folder called **WoWBest**.
4. Check that **`_forever_\Interface\AddOns\WoWBest\WoWBest.toc`** exists. The Lua files should sit beside the TOC. If you used GitHub’s green **Code → Download ZIP** instead, extract that archive separately and copy the **inner `WoWBest` folder containing the TOC** into AddOns.
5. Launch Forever. At character selection, click **AddOns**, enable **WoWBest** for your character, enter the world, and type **`/wowbest`** or **`/wbest`**. The addon is standalone. The installation does not require an addon manager, Python, an API key or a companion app.

On **macOS**, follow the same steps in Finder. A standard destination is `/Applications/World of Warcraft/_forever_/Interface/AddOns/`. Unzip the download and copy the resulting `WoWBest` folder there.

### Optional Windows PowerShell installation

Set the first line to the **actual Forever folder you found in Battle.net**. This downloads the packaged addon and writes its files directly into AddOns.

```powershell
$foreverDir = 'C:\Program Files (x86)\World of Warcraft\_forever_'
if (!(Test-Path -LiteralPath $foreverDir -PathType Container)) {
    throw "Set the first line to your actual _forever_ folder."
}
$addonsDir = Join-Path $foreverDir 'Interface\AddOns'
$zipPath = Join-Path $env:TEMP 'WoWBest-addon.zip'
New-Item -ItemType Directory -Force -Path $addonsDir | Out-Null
Invoke-WebRequest -ErrorAction Stop -Uri 'https://github.com/JustPixelll/WoWBest/raw/refs/heads/main/downloads/WoWBest.zip' -OutFile $zipPath
Expand-Archive -LiteralPath $zipPath -DestinationPath $addonsDir -Force -ErrorAction Stop
Get-Item -LiteralPath (Join-Path $addonsDir 'WoWBest\WoWBest.toc')
```

## Your first gear plan

- Open the window **outside combat**. The first scan asks the game client for item details in batches. Once the eligible-item count appears, click any slot, including an empty one.
- Check **Spec**. **Auto** reads points spent in your active talent trees. With no clear winner it shows the class leveling **Default**. Pick a profile manually for a hybrid build, for **Feral (Bear)** versus **Feral (Cat)**, or for a planned respec. A manual choice is saved for this character. Select **Auto (active talents)** to follow talents again.
- Read **main hand and off hand together**. A two-hander occupies both. A one-hander can be paired with a usable shield or held item. A second weapon requires learned dual wield. Protection profiles plan around a shield. Rings, trinkets and quest choices are also solved together.
- **Ranked gear** shows up to 15 distinct choices, five per page. The addon finds the best complete outfit that contains each choice in the selected slot. A difference of **−3 points** means the best outfit using that choice gives up three weighted points against the overall recommendation. Tied scores can occur. Each entry shows which other slots change, how its stats score, and which set thresholds you gain or lose. The points use the selected profile’s stat weights.
- **Paths to unlock** lists relevant profession and event options, with the missing skill, recipe or turn-in when known. These are kept out of the equipped-today ranking until their requirements are met.
- Hover an item for its game tooltip. Its row tells you where to go next, for example a dungeon and boss, quest, profession and skill, vendor or named world drop. An item you already have can appear as **Currently equipped** or **In your bags**. The planner recognizes exact owned variants, including random suffixes.
- At an auctioneer, manually search for a piece of gear and open its detailed auction results to include observed buyout listings in the plan. Auction candidates are temporary and limited to the searches you perform during that visit. Check the actual listing before buying.
- The window refreshes as your level, equipment, talents, skills and quest state change. **Refresh** repeats the lookup, including skipped item requests. Close the window or press Escape when finished. You equip the items yourself.

### Choose acquisition methods

Open **`/wowbest` → Sources**. Uncheck the activities you want to skip, then click **Apply**. Your selection is saved for the current character and applies to the recommended outfit, slot alternatives and unlock paths. All eight methods start enabled: Dungeons, Quests, Crafting, World drops, Vendors, PvP, Auction House and Events.

- **Skipping dungeons?** Turn off **Dungeons** and leave **Quests** on. Open-world quest rewards stay in the plan. Quest routes marked as requiring a dungeon are excluded.
- **An item has several sources?** Any enabled, eligible route can still qualify it. For example, if you disable **Crafting**, an actual buyout you inspect at the Auction House can still qualify, subject to the gear’s wearer requirements.
- **Only use what you have?** Click **Owned only → Apply** to plan with wearable gear you have equipped or in your bags. **Select all → Apply** restores every method.
- Event quest rewards need **Events** and **Quests**. Dedicated battleground quartermasters are grouped under **PvP**. **Vendors** covers ordinary merchants.

### Example: a level-19 warrior’s head slot

Click **Head → Paths to unlock** if you have yet to train Engineering. **Flying Tiger Goggles** require Engineering **100** to wear and grant **27 armor, +4 Stamina and +4 Spirit**. **Green Tinted Goggles** require **150** and grant **35 armor, +8 Stamina and +7 Spirit**. Both can be worn at level 19. Their item levels (20 and 30) describe the equipment. The wearer needs Engineering even when someone else crafts the goggles. [Flying Tiger Goggles](https://azeroth.wiki/forever/professions/engineering/flying-tiger-goggles) · [Green Tinted Goggles](https://azeroth.wiki/forever/professions/engineering/green-tinted-goggles)

Engineering trainers **Lilliam Sparkspindle** in Stormwind and **Nogg** in Orgrimmar teach the recipes. One pair of Green Tinted Goggles uses **one Flying Tiger Goggles, four Medium Leather and two Moss Agate**. Once you meet the wearer requirement, open **Head → Ranked gear** to compare them against the other options available to your particular warrior. [Catalog sources](DATA.md)

### Armor sets

The bundled set data covers 274 sets and 780 threshold effects. Of these, 389 have numerical models. Gear from your bags and auction searches uses the same set data as catalog gear. The total includes modeled bonuses from distinct pieces of a set. A weaker-looking item can win when it activates a threshold. The detail view shows which bonuses disappear or appear if you take the runner-up. Unscored effects are labeled so you can judge their value for the encounter. **General PvE** is the default target. Choose **Humanoids** to include the verified +15 attack power against Humanoids from three pieces of Defias Leather. The four-piece positional bleed is displayed as an unscored effect because its uptime depends on how often you attack from behind. [Defias Leather in Forever](https://foreverdb.net/set/161)

## What “best” means here

The solver maximizes the total score for the selected profile across compatible items. It weights primary stats, relevant secondary stats, defenses, weapon DPS and selected Forever trinket effects. A spec that gains more from a one-hander **plus** a shield or off-hand can choose that pair even if the two-hander is individually stronger.

The game client supplies item stats and checks wearability, including your trained proficiencies. Acquisition checks include recorded level, faction, class, race, one-time quest choices, and known profession, reputation and PvP requirements. You may still need a party, a quest chain, an attunement, materials or currency. It shows routes to pursue, without assuming you have cleared a dungeon or can afford an item. Your equipped gear and carried bags enter the comparison even when an item has no catalog route.

Rankings are an estimate for a general PvE build. Encounter-specific caps, rotations, group buffs, many use/proc effects, and unmodeled conditional set effects can change an individual recommendation. An empty slot means there was no legal, positively scored candidate for that slot or its group. The bundled catalog is a dated snapshot with documented gaps in world drops, endgame sources, rare variants and special-event gear. See [DATA.md](DATA.md) for coverage, source builds and reproduction steps.

## Updating or troubleshooting

| Symptom | What to check |
| --- | --- |
| WoWBest is missing from AddOns | Exit the game. Confirm the exact `_forever_\Interface\AddOns\WoWBest\WoWBest.toc` path. An extra `WoWBest-main` or `WoWBest` directory prevents discovery. Restart the Forever client. |
| The addon is listed but the slash command is unknown | Enable WoWBest for this character at the character screen and re-enter. Verify that all files named in the TOC were extracted. |
| It is marked out of date | This build targets Forever interface **16001**. In chat, `/dump select(4, GetBuildInfo())` prints your client's interface number. Download the latest compatible WoWBest build after a game update. |
| A weapon or quest reward you expected is missing | Verify trained weapon skill, character level, build, faction and quest completion. For a completed one-time quest, the reward you kept can still enter through bags or equipped gear. Bank items enter after you move them into your bags. |
| Some items could not be verified | Leave combat, wait for item data to load, then click **Refresh**. The addon skips unresolved candidates. Missing or incompletely modeled sources can also leave a slot empty. |
| A stronger-looking item loses | Compare the full hand pair or both rings/trinkets. Check the selected spec and the item's proc/set text. The tooltip gives the model assumptions for supported trinkets. |
| A Lua error appears | Run `/console scriptErrors 1`, then `/reload` and reopen the window. Report the **first** error, your class, spec, level and `/dump GetBuildInfo()` in [GitHub Issues](https://github.com/JustPixelll/WoWBest/issues). Use `/console scriptErrors 0` afterward if preferred. |

To **update**, close WoW and replace the installed `WoWBest` folder with the folder from the new ZIP. Character settings are kept separately in WoW’s `WTF` directory. To **uninstall**, close WoW and remove the installed `WoWBest` folder from AddOns.

## Development and verification

The addon targets the Lua 5.1-compatible Forever client. From the repository root, run the Lua files in `tests/` with Lua 5.1. They cover incompatible hand pairs, uniqueness across slots, competing quest choices, character requirements, async item lookups, talent detection, click-through slot rankings, Engineering headgear, set thresholds, and modeled item effects. A randomized test compares the optimizer against an exhaustive search. The suite uses game API fixtures. A live character remains the final check for a particular client build.

```powershell
Get-ChildItem tests -Filter *.lua | ForEach-Object { lua $_.FullName; if ($LASTEXITCODE) { throw "Failed: $($_.Name)" } }
```
