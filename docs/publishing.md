# Publishing checklist

Thanksgiving is **Thursday, November 26, 2026**. Publish privately first, test with friends, then go public a week or so before the holiday.

## 1. Publish from Studio

1. **File → Publish to Roblox As… → Create new experience.**
2. Name: `TURKEY RACE! [THANKSGIVING]`
3. Paste the description from [Store page text](#store-page-text) below.
4. Genre: Racing (it may be listed under Sports & Racing).
5. Devices: **Computer, Phone, Tablet**. Leave Console off until you've tried it with a controller.

## 2. Game Settings (Studio: Home → Game Settings)

- **Security → Enable Studio Access to API Services: on.** Feathers, Wins and skins can then save while you test in Studio.
- **Places → the place → Max Players: 8.** A race holds 8 turkeys, so anyone over 8 would sit in the lobby.
- **Avatar:** R15 and R6 both work, since every avatar gets the turkey suit.
- **Permissions:** keep it **Private** until the tests below pass.

## 3. Test the published game

- **Saving:** join from the Roblox website (not Studio). Finish a race, leave, rejoin: your feathers should still be there.
- **Wins board:** the lobby board should say **"All servers"**. In Studio it says "This server".
- **Multiplayer:** in Studio, go to **Test → Clients and Servers**, pick 3 players and press Start. Race once and check the places, results and the chef.
- **Phone:** in Studio, go to **Test → Device** and pick a phone. Check that the big Sprint, Slide, Use and Gobble buttons sit around the jump button without covering it, that holding Sprint gallops, and that the HUD and shop fit on screen.

## 4. Creator Hub (create.roblox.com → your experience)

- **Icon:** 512×512. A close-up of a turkey works best at small sizes.
- **Thumbnails:** 1920×1080, up to 10. Good shots:
  - turkeys lined up in the oven with the burners glowing
  - the chef on his cake stand with a frying pan in mid-air
  - the restaurant kitchen from the butcher-block counter
  - pumpkins rolling down Pumpkin Hill, with the house behind
  - the dining room with the chandelier and the table from above
- **Maturity & Compliance questionnaire:** required before going public. Answer it honestly. The frying-pan bonk and getting "cooked" are cartoon slapstick with no blood.
- When everything above checks out: **Permissions → Public.**

## 5. Robux items

The shop, Harvest Pass and everything they sell are already built. Each Robux item just needs to be created on Roblox, with its id pasted into `ROBUX_IDS` at the top of [src/shared/Config.luau](../src/shared/Config.luau). Until then the item shows as **Coming soon**.

**An item's id only works in the experience it was created in.** So each item is created twice: on the private work copy (GameId 10774869273), where Studio's test purchases are free, and on the real game (GameId 10774782857) when it's published. `ROBUX_IDS` has a set for each, and the game picks the right one by itself.

On create.roblox.com, open the experience and go to **Monetization**. Icons for every item are in [assets/ui/export/items](../assets/ui/export/items) (made by `assets/ui/build_ui_art.py`).

**Passes** (bought once, owned forever). For each one, click **Create a Pass**, add the icon, name and description, then turn on **Item for Sale** and set the price:

| Pass | Icon | Goes in | Price |
|---|---|---|---|
| Harvest Pass Premium | `premium_pass.png` | `PremiumPass` | 199 |
| VIP: 2x Feathers from every race, a VIP tag in chat and over your turkey, a golden trail | `vip.png` | `VipPass` | 299 |
| Rainbow Turkey | `skin_rainbow.png` | `Skins.Rainbow` | 149 |
| Galaxy Turkey | `skin_galaxy.png` | `Skins.Galaxy` | 249 |
| Diamond Turkey | `skin_diamond.png` | `Skins.Diamond` | 299 |

**Developer Products** (can be bought again and again). Create each one with a name, description, icon and price:

| Product | Icon | Goes in | Price |
|---|---|---|---|
| 2x XP for 30 minutes | `xp_30m.png` | `XpBoosts[1]` | 29 |
| 2x XP for 2 hours | `xp_2h.png` | `XpBoosts[2]` | 79 |
| 300 Feathers | `feathers_300.png` | `FeatherPacks[1]` | 25 |
| 1,000 Feathers | `feathers_1000.png` | `FeatherPacks[2]` | 75 |
| 3,000 Feathers | `feathers_3000.png` | `FeatherPacks[3]` | 199 |
| Power-Up Starter: 5 races start with a power-up in hand | `starter_5.png` | `Starters[1]` | 39 |
| Power-Up Starter: 15 races | `starter_15.png` | `Starters[2]` | 99 |
| Feast Frenzy: 2x race Feathers for everyone in the server for 15 minutes | `feast_frenzy.png` | `FeastFrenzy` | 99 |
| Harvest Bundle: Chef Turkey, 1,000 Feathers and 5 Starters (750 Feathers instead of the skin if owned) | `harvest_bundle.png` | `HarvestBundle` | 119 |

A Power-Up Starter never hands out the Drumstick Dash, so nobody buys speed, and only fills an empty slot at GO.

Then:

1. Copy each id from the item's page, using **Copy Asset ID** or the number in the address bar, and paste it into that experience's set in `ROBUX_IDS`.
2. Commit, then **File → Publish to Roblox** so the live game has the ids.
3. Test in Studio: buying shows a **test purchase** dialog and you aren't charged. Check that the skin unlocks, premium pays out the rewards you've already reached, the boost timer appears, Feather packs add Feathers, VIP shows its tag and trail and doubles a race's Feathers, and a starter puts a power-up in your slot at GO.

Claude can create the items itself if the Studio Assistant has the Open Cloud permissions `game-pass:write` and `developer-product:write` (Assistant → MCP Permissions).

The prices are suggestions; change them on the Creator Hub any time and the shop shows the new price automatically. To change what the pass gives, edit [src/shared/Season.luau](../src/shared/Season.luau). Changing its `Id` starts a new season, which resets everyone's pass progress; levels and skins are kept. A new season also needs a new Premium pass id, or last season's buyers get the new premium track free.

## 6. After publishing

- Push updates live with **File → Publish to Roblox** (Alt+P).
- Keep `TurkeyRace.rbxl` current with **File → Save to File** before committing map changes.

## Store page text

**Name:** TURKEY RACE! [THANKSGIVING]

**Description:**

```
🦃 DON'T GET COOKED! 🦃
Race up to 8 turkeys through a giant house, grab silly food power-ups, and dodge the tomatoes, pies and frying pans the angry chef hurls from the middle of the room!

🏁 3 MAPS
• Thanksgiving Dinner Dash: race around the table in a grand dining room
• Pumpkin Patch Panic: dodge pumpkins rolling down the hill in the backyard garden
• Escape the Oven: burst out of the oven and across a restaurant kitchen's red-hot burners

🍗 6 POWER-UPS
Drumstick Dash • Pie Launcher • Butter Slide • Gobble Bomb • Potato Shield • Corn Tornado

🔥 2 MODES
Race to the finish, or Elimination where the last turkey gets COOKED!

🍂 Earn Feathers and XP, level up, and unlock 16 turkey skins, from Common to Mythic!

🎟️ HARVEST PASS: 30 tiers of rewards, with exclusive skins on the free and premium tracks

🏆 Climb the global Wins board!

🎮 CONTROLS
Shift: sprint • Space: jump (again to flap) • Q: belly slide • E: use power-up • G: gobble
```
