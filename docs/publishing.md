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
- **Phone:** in Studio, go to **Test → Device** and pick a phone. Check that the Sprint, Slide, Use and Gobble buttons and the HUD fit on screen.

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

The shop and Harvest Pass are already built. Each Robux item just needs to be created on the Creator Hub, with its id pasted into `Config.Robux` in [src/shared/Config.luau](../src/shared/Config.luau). Until then the item shows as **Coming soon**.

On create.roblox.com, open your experience and go to **Monetization**.

**Passes** (bought once, owned forever). For each one, click **Create a Pass**, add an image, name and description, then turn on **Item for Sale** and set the price:

| Pass | Goes in | Suggested price |
|---|---|---|
| Harvest Pass Premium | `PremiumPass` | 199 |
| Rainbow Turkey | `Skins.Rainbow` | 149 |
| Galaxy Turkey | `Skins.Galaxy` | 249 |
| Diamond Turkey | `Skins.Diamond` | 299 |

**Developer Products** (can be bought again and again). Create each one with a name, description, icon and price:

| Product | Goes in | Suggested price |
|---|---|---|
| 2x XP for 30 minutes | `XpBoosts[1].Id` | 29 |
| 2x XP for 2 hours | `XpBoosts[2].Id` | 79 |

Then:

1. Copy each id from the item's page, using **Copy Asset ID** or the number in the address bar, and paste it into Config.
2. Commit, then **File → Publish to Roblox** so the live game has the ids.
3. Test in Studio: buying shows a **test purchase** dialog and you aren't charged. Check that the skin unlocks, premium pays out the rewards you've already reached, and the boost timer appears.

For pass images, a screenshot of the skin's card in the shop works well.

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
