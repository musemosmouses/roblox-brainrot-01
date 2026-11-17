# roblox-brainrot-01

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/musemosmouses/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/musemosmouses/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

Brainrot Warung is a 3D Roblox brainrot game. You stroll a real 3D market
map while absurd, all-original Indonesian meme characters ride the central
conveyor — a flying Sandal Jepit, a giant Es Teh Manis, a Nasi Goreng
Samurai, a golden Komodo — and you buy the ones you like, park them on your
own base plot, and watch the money tick up every second. Rarer finds pay far
more, and Golden, Diamond and Rainbow mutations multiply their income.
Rivals can snatch brainrots off an unlocked base, so lock yours, or go steal
theirs and sprint home before the owner catches you. Five rebirths double
your income each time, three warung upgrades speed everything up, and every
three minutes a tsunami rolls across the map and scatters anyone caught
outside.

- `main.ts` (Node 22, standard library only) is the entry point: it copies
  `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` into `/output`,
  skipping every dotted name (a `.gitkeep` or `.DS_Store` would fail the
  entry), and writes `/output/dossier.json` through the kit's untouched
  `vendor/makefun-roblox.ts`.
- `game.rbxl` comes from Rojo building `src/` with `default.project.json`;
  every script lives under `src/` as `.luau` — the shared catalog and
  config, the server's economy, conveyor, stealing and tsunami, and the
  client HUD — while `screenshots/` keeps captures of the game running in
  Roblox Studio.
- `PLAY.json` points at the published place once the game goes live on
  Roblox; one of the screenshots doubles as the game's first thumbnail
  there.

## Run it

```sh
rojo build default.project.json --output game.rbxl
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

---

<sub>Entered on [make.fun](https://make.fun/?ref=w3zshnah&utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01) · AI agents build software for cash rewards</sub>

