# Short: de la /needlicense la /givelicense (60 s)

Animatie 2D, vertical 1080x1920, 30 fps, cu muzica si efecte sonore generate de la zero.
Fisierul final: `sichelper-short.mp4`.

Povestea: [XO]Stroe (nivel 54) da `/needlicense` → [XO]ZioAdolf primeste cartonasul, accepta cu o tasta
(SMS automat) → montaj „Jarvis” cu ferestrele helperului → drumul pe harta, cu randul din legenda
„Distanta pana la [XO]Stroe” → `/salut`, `/rl` → helperul citeste licentele (5/5 expirate) → `/withme`
(rosu = expirata) → „Toate licentele” din tabul 50+: lantul de `/givelicense`, una dupa fiecare accept.

Textele din chat, cartonas, legenda, `/withme` si `/sic` sunt cele din `moonloader/SICHelper.lua`
si `config/SICHelper_data.lua`.

## Cum se reface

```sh
./fetch-fonts.sh                      # fonturile (nu sunt in repo)
pip install numpy scipy imageio-ffmpeg
node render.cjs --cues                # momentele pentru sunet -> out/cues.json
python3 audio.py                      # muzica + efecte -> out/audio.wav
node render.cjs                       # cadrele + sunetul -> out/sichelper-short.mp4
```

- `node render.cjs --stills 6.5,20,45` scrie cadre PNG in `out/stills/` (pentru verificari rapide).
- `index.html?preview` (servit prin HTTP, de ex. `npx http-server` din radacina repo-ului) are un
  cursor de timp pentru previzualizare in browser.
- Randarea foloseste Playwright (Chromium) si ffmpeg-ul din `imageio-ffmpeg` (sau variabila `FFMPEG`).

## Structura

| Fisier | Ce contine |
|---|---|
| `src/core.js` | constante, easing, text, iconite, efecte |
| `src/ui.js` | interfata helperului refacuta: cartonas, legenda, bara de iconite, `/withme`, `/sic`, `/info`, raport, dovezi, chat si dialog SA-MP |
| `src/world.js` | personajele (desenate, cu contur), strada, sediul SI, masina, harta, fundalul „Jarvis” |
| `src/scenes.js` | scenariul: momentele cheie (`T`), scenele, subtitrarile, indiciile de sunet |
| `audio.py` | sinteza muzicii (120 BPM, La minor) si a efectelor, pe momentele din `out/cues.json` |
| `render.cjs` | Chromium headless → JPEG → ffmpeg (H.264 + AAC) |

Personajele sunt desenate de la zero dupa skinurile din joc (ZioAdolf: Ryder; Stroe: costum cu
cravata rosie); pozele skinurilor nu sunt incluse. Fonturi: Inter, Rajdhani, Anton, Arimo,
JetBrains Mono (Google Fonts, SIL OFL / Apache 2.0) si Font Awesome Free 6 (SIL OFL 1.1).
