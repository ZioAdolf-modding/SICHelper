# SICHelper — for staff and faction leadership

This document is written to be verified, not to convince. The whole code is in the repo, in a single
file (`moonloader/SICHelper.lua`), and can be read line by line.

## What it is

A **CMD helper**: it types commands in chat for the instructor, so they are not typed by hand at every
test. The same thing SIHelper 1.2.2 (by AdeM) did — the helper the faction has been using until now.

Technically: a **Lua** script for MoonLoader (not an `.asi`, not an injector, no DLL of my own). The
interface is drawn with mimgui (ImGui). It has no compiled components written by me — the only `.dll`
files in the archive are the public mimgui and iconv libraries, the same ones any MoonLoader script uses.

## What it sends to the server

Everything it sends goes through normal chat (`sampSendChat`), exactly as the player would type it:

| When | What it sends |
|---|---|
| Accept button / bind / `/acc` | `/accept needlicense <id>` |
| after a successful accept (optional, can be turned off) | `/sms <id> <text from the data file>` |
| on an incoming `/needlicense`, if the level is unknown | `/id <id>` (the server's reply is hidden from your chat, not from the server) |
| RL button / `/rl` | `/requestlicenses <id>` |
| Start lesson / `/sw` etc. | `/startlesson <id> <license>` |
| T1..T3 / Q1..Q5 buttons | `/cw <the official test text>` (for Sailing, in normal chat) |
| Give license / `/gw` etc. | `/givelicense <id> <license>` |
| Failed / `/sl` / automatically after the license is accepted | `/stoplesson <id>` |
| `/withme` | `/id <id>`, then the announcement on `/f` |
| `/sxwas` | the question on `/sx` |
| `/salut`, `/pa`, `/need`, `/ok` | `/w <id> <text>` |
| `/giveme` (licenses for yourself) | `/givelicense <your own id> <license>`, then `/accept license <your own id>` |
| with an active checkpoint, before an accept | `/cancel find`, `/killcp` (optional) |
| Repair / refill | `/switchjob`, `/repair`, `/refill`, `/switchjob` |
| FVR | announcement on `/f` and `/sx`, then `/fvr` |

The texts are not invented by the script: they live in `moonloader/config/SICHelper_data.lua`, a data
file anyone can read and edit. The tests are the official ones, taken from AdeM's helper, so the
content of the examination does not change.

There is an adjustable delay between commands (about 1 second by default) so nothing is sent in bursts.

## What it reads from the game

- **the server chat** — to know when someone used `/needlicense`, when a license was accepted, whether
  you are on/off duty, what level a player is (from the `/id` reply);
- **names and ids** of connected players, through SAMPFUNCS (the same thing you see in `/id` or in the
  scoreboard);
- **the candidate's vehicle health**, only during a Flying or Sailing lesson, only for the player you
  are testing, to tell you when it dropped below 950 (the failing condition). This is the only read
  from game memory and it can be turned off in `/sih` → Features → "HP vehicul live";
- **your position and the candidate's** (for the distance shown in the HUD) and the checkpoint set by
  the server.

## What it does NOT do

- it does not play by itself: no auto-drive, auto-aim, auto-farm, movement macro, teleport, spawn,
  money hack or any game modification;
- it sends nothing without an action of yours, with three exceptions, all started by your own action
  and all behind a switch: `/stoplesson` after the candidate accepts the license, the confirmation
  `/sms` after your accept, and the `/id` that reads the level;
- it does not modify packets to the server and hides nothing from the server;
- it sends no data anywhere outside the game: no internet connections, no telemetry, it reads no files
  outside the game folder;
- the only thing hidden from your own interface is the server's distance message, while the helper
  shows the same distance in its own HUD (`/sih` → Features → "Ascunde distanta serverului").

## What it writes to disk

- `moonloader/config/SIC_Helper.ini` — your settings;
- `moonloader/SICHelper_trace.txt` (and `_prev.txt`) — a diagnostic trace: which commands it sent,
  which windows opened, when the game lost focus. It is for debugging only and can be read;
- it renames the screenshots taken with the button in `/sic`, in the same folder where SA:MP puts them.

## Quick verification

- the whole code: `moonloader/SICHelper.lua` (comments are in Romanian);
- what it sends: search the file for `Queue.push` and `sampSendChat` — every command goes through there;
- what it reads from memory: search for `readMemory` — it appears in two adjacent lines, at the
  vehicle health;
- no network: search for `http`, `socket`, `require("socket")` — they do not exist.

If you want a feature off by default or removed entirely for instructors, tell me which one and I will
do it; every automation already has an ON/OFF switch in `/sih` → Features.

Contact: **ZioAdolf** — Discord `vlandrewz`.
