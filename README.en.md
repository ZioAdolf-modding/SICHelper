# SICHelper

CMD helper for B-Zone RPG (SA:MP), written in Lua, for MoonLoader. It covers **School Instructors**
and the **departments** (Police Department, FBI, National Guard); other factions will be added gradually.
The interface switches in one click, from `/sih` (or `/pdh`) → General → Interface.

**Version:** 1.6.0-beta · **Author:** ZioAdolf (Discord: `vlandrewz`) · **License:** GPL-3.0-or-later

> **Official source: <https://github.com/ZioAdolf-modding/SICHelper>**
> Any other copy, archive or build from another site, Discord or channel is not official and is not
> supported by me. If you did not get it from the Releases above, it is not my version.

---

## What it does

- **`/sic`** — test window: tabs for Flying, Sailing, Fishing, Weapons, Materials and 50+.
  Sends the official test texts on `/cw` (Sailing: in normal chat, since you are not in a vehicle),
  shows the correct answers to you only, sets `/pagesize 30` for the question tests and sends `/dl`
  when a text mentions it.
- **`/needlicense`** — a clear chat line + an on-screen notification, with the level fetched through a
  hidden `/id` and the language (RO / EN) detected from the request. Requests that arrive while the
  game is in the background are shown when you come back.
- **After accepting** — the player becomes your candidate and receives a confirmation `/sms`.
- **`/giveme`** — licenses for yourself (renew): sends `/givelicense` on your own id and accepts what the server offers.
- **`/withme`** — the `/f` announcement in the faction format, with the license subtotal and the AR bonus.
- **`/notepad`** — your notes, in folders: send them to chat exactly as written (text or command) or copy
- **Allied faction** — a license given to a member of the allied faction is paid back automatically
  with `/pay`, as soon as the player accepts it (SF School Instructors are allied with Paramedics).
  If your money is still locked, the payment waits and goes out the moment you type `/pin`.
- **`/info <id>`** — the player card: level, ping, FPS, faction with the rank name, licenses, distance
  and vehicle, plus your own notes about them (tags and free text, saved per name).
  them. Also opens from `/sih`, from the icon bar or from a key.
- **50+** — licenses go out one by one, each after the previous one has been accepted.
- **On screen** — icon bar, bind legend, distance to the checkpoint / candidate, the weekly report while
  on duty, the proof checklist.
- **Other** — automatic stoplesson, silent repair/refill, screenshot renaming, colour themes per
  faction, an interface that scales with your resolution.

### For the departments (PD / FBI / NG)

- **`/pdc`** — the control station: pick the **suspect** (from the radar, by ID, the nearest one or the
  list of players around you), the helper gets their level with `/id`, and each button does one action,
  matched to the level and the rules. Tabs: Traffic, Wanted, Search, Radar, Dispatch.
- **Sanctions by level** — 1-3 warning only, 4-7 they choose (ticket or license: the buttons show up in
  the station once they answer), 8+ ticket and license. What you say to the player and the commands
  (`/ticket`, `/confiscate`) are shown in the tooltip before you click.
- **Radar** — zone and limit, "Zone free?" 3 times on `/d` (at least 10 s apart), approval for another
  city, start only with the car stopped, one button that starts / stops + `/find` on the one caught /
  resumes. Everyone caught goes into a list, with speed, limit and the sanction that fits.
- **Wanted (`/su`)** — disobeying, runner, attacking an officer, drugs, unpaid fine, accomplice,
  unfounded call. The helper counts the summons (3 within 5 minutes, then 30 s) and remembers the
  `/frisk` for drugs; if a rule is not met it warns you, and a second click sends anyway.
- **The `/ticket` and `/su` dialogs** — the right line is picked by its text (or position) and written in
  chat; it can be set to select only, or turned off.
- **The PDHelper shortcuts** — `/aa`, `/nos`, `/con`, `/parc`, `/nec`, `/run`, `/mm`, `/cl`, `/sl`,
  `/ll`, `/potls`, `/afk`, `/hdt`... with the same names.
- Everything server-specific (commands, texts, dialog lines, thresholds) lives in
  `moonloader/config/SICHelper_pd.lua`, so it can be changed without code (or used on another server).

The full command list is in game: `/sih` → General → **Commands**, and in [docs/COMENZI.md](docs/COMENZI.md).

## Install

You need the standard runtime for any `.lua` script (not included in the repo):

| Component | Tested version |
|---|---|
| SA-MP | 0.3.7-R1 |
| GTA San Andreas | 1.0 US |
| ASI Loader | any (`vorbisFile.dll` / `dinput8.dll`) |
| [SAMPFUNCS](https://www.blast.hk/threads/17/) | 5.4 |
| [MoonLoader](https://www.blast.hk/threads/13305/) | 026.5-beta |

CLEO is not required.

1. Download the archive from [Releases](https://github.com/ZioAdolf-modding/SICHelper/releases).
2. Drag the `moonloader` folder over your game folder and **overwrite when asked** - including
   `moonloader/lib/fAwesome6_solid.lua`, which must be the one from the archive (the large icons).
3. In game: **Ctrl + R** (reloads the scripts) or restart the game.
4. `/sih` → General → pick your faction and city (or, under Interface, one click on School Instructors /
   Departments).

If you used PDHelper (CLEO), remove `PDHelperV7.5.cs` from the `cleo` folder: it has the same commands.

The config file is created automatically: `moonloader/config/SIC_Helper.ini`.

## Other factions

**For now the helper is built for School Instructors and the departments (PD / FBI / NG).** The other
factions will be added gradually, one at a time. The interface follows the faction picked in `/sih`:
the station in the icon bar (`/sic` or `/pdc`), the short commands, the binds, the tutorial and the colours.

The groundwork is there, though: the interface is not tied to any one faction (you pick yours in
`/sih` — every faction on rpg.b-zone.ro is in the list, with its colours and rank names), and the
texts, prices and messages live in `moonloader/config/SICHelper_data.lua` — a data file, not code.
What is missing for another faction are its own commands and procedure.

Want your faction next? Open an [issue](https://github.com/ZioAdolf-modding/SICHelper/issues) or
message me on Discord with your commands and procedure — that moves it up the list.

## What it does not do (for staff)

Short version: the helper **types commands for you**, nothing more. In detail, in
[docs/FOR-STAFF.md](docs/FOR-STAFF.md):

- it does not play by itself and does nothing without a command or a key press of yours (the only
  automatic actions are `/stoplesson` after the license is accepted, the confirmation `/sms` after your
  accept, and the `/id` used to read the level — all started by your own action and all can be turned
  off in `/sih` → Features);
- it does not read or modify other players' memory except in one case: the candidate's vehicle health
  during practical lessons, so you know when they failed the test;
- it hides nothing from the server: every command goes through normal chat, exactly as you would type it;
- for the departments it never arrests, cuffs or frisks by itself: every command comes from a click or a
  key; the only thing done without a click is picking the line in the `/ticket` / `/su` dialog that
  your own click opened (can be turned off);
- no auto-aim, auto-drive, teleport, spawn, money hack or any other cheat;
- the only thing hidden visually is the server's distance message, while the helper shows the same
  information in its own HUD (this can be turned off).

## License

[GPL-3.0-or-later](LICENSE). In short: you may use, study, modify and redistribute the code, but
**any modified version you distribute must stay open, under the same license, and keep the credits**.
See also [TRADEMARK.md](TRADEMARK.md) for the name and logo.

## Credits

- **AdeM** — SIHelper 1.2.2, the helper the faction has used until now. The official test texts are the
  ones from his helper, and the shortcuts (`/acc`, `/rl`, `/sl`, `/gw`, `/gm`, `/gs`, `/gf`, `/gfl`,
  `/sw`, `/sm`, `/ss`, `/sf`, `/sfl`, `/w1..`, `/m1..`, `/f1..`, `/lsfl1..`, `/ccc` and the general
  shortcuts) keep the same names as in his. SICHelper is written from scratch, on the command structure
  the instructors were already used to.
- **TheTom** — PDHelper V7.5, the helper the departments have been using. The shortcuts (`/aa`, `/nos`,
  `/nec`, `/mm`, `/sl`, `/ll`, `/potls`, `/afk`, `/hdt`...), the texts said to players and the position
  of the lines in the `/ticket` and `/su` dialogs come from his helper. The `/pdc` station is written
  from scratch.
- **urShadow** — [mimgui](https://github.com/THE-FYP/SAMP.Lua) and `samp.events`.
- **FYP** — MoonLoader and ML-ReloadAll.
- **FlaCode & Cosmo** — HassleHUD (HUD inspiration).

The libraries in `moonloader/lib/` belong to their authors and keep their own licenses: the full
list, with authors and licenses, is in [THIRD-PARTY.md](THIRD-PARTY.md).
