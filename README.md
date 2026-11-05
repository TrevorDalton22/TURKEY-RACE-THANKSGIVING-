# TURKEY RACE! [THANKSGIVING]

A chaotic Thanksgiving multiplayer racing game for Roblox. Players are turkeys racing across oversized holiday maps, throwing pies, and outrunning a giant angry chef. **Don't get cooked!**

The full concept is in [docs/concept.md](docs/concept.md). The steps to put it on Roblox are in [docs/publishing.md](docs/publishing.md).

## How the project is set up

- **Scripts** live in `src/` as text files and are synced into Studio with [Rojo](https://rojo.space):
  - `src/server` → `ServerScriptService.Server`
  - `src/client` → `StarterPlayer.StarterPlayerScripts.Client`
  - `src/shared` → `ReplicatedStorage.Shared`
- **The map, models, and UI layout** are built in Studio and saved in `TurkeyRace.rbxl`. Commit that file when the map changes. Git can't merge it, so only one person should edit the map at a time.

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run this in the repo folder to get the pinned Rojo version:

   ```bash
   rokit install
   ```

2. Install the Rojo plugin into Studio (restart Studio afterwards):

   ```bash
   rojo plugin install
   ```

3. Open `TurkeyRace.rbxl` in Studio, then start the sync server:

   ```bash
   rojo serve
   ```

4. In Studio, open the **Rojo** plugin and click **Connect**. Edit scripts in `src/`. Changes appear in Studio right away.

Script edits made directly in Studio are **not** saved back to `src/`. Always edit the files.
