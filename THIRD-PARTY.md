# Biblioteci si materiale terte

SICHelper (codul scris de mine) e sub [GPL-3.0-or-later](LICENSE). Componentele de mai jos **nu**
sunt scrise de mine: raman ale autorilor lor si isi pastreaza licentele proprii. Sunt livrate
impreuna cu helperul pentru ca fara ele scriptul nu porneste.

*SICHelper itself is under GPL-3.0-or-later. The components below are not mine: they belong to their
authors and keep their own licenses. They ship with the helper because it does not run without them.*

| Componenta | Autor | Licenta | Unde |
|---|---|---|---|
| mimgui | FYP | MIT | `moonloader/lib/mimgui/` |
| cimgui + Dear ImGui (`cimguidx9.dll`) | cimgui contributors; Omar Cornut | MIT | `moonloader/lib/mimgui/cimguidx9.dll` |
| SAMP.Lua (`samp.events`, `samp.raknet`) | FYP @ BlastHack Team | MIT | `moonloader/lib/samp/` |
| `encoding`, `vkeys`, `windows` | BlastHack Team | MIT | `moonloader/lib/` |
| lua-iconv + GNU libiconv (`iconv.dll`) | Alexandre Erwin Ittner; Free Software Foundation | MIT; LGPL | `moonloader/lib/iconv.dll` si `moonloader/lib/iconv/` (textul licentei: `COPYING-libiconv`) |
| Font Awesome 6 Free (Solid) | Fonticons, Inc. | font: SIL OFL 1.1 · iconite: CC BY 4.0 · cod: MIT — <https://fontawesome.com/license/free> | `moonloader/lib/fAwesome6_solid.lua` (fontul e incorporat in fisier, ca TTF comprimat) |

MIT si LGPL sunt compatibile cu GPL-3.0, deci pachetul se poate distribui ca intreg. Fontul si
iconitele Font Awesome sunt opere separate, distribuite alaturi de cod, cu licentele lor.

## Ce am modificat din ele

- `moonloader/lib/fAwesome6_solid.lua` — intervalele de glife sunt tinute in viata (imgui pastreaza
  doar un pointer, iar eliberarea lor crapa jocul la reconstruirea atlasului de fonturi), plus
  `InitBig(fontsize)`, care incarca acelasi font separat, la alta marime.
- `moonloader/lib/mimgui/init.lua` — cursorul nu se mai comuta cand fereastra jocului nu e in fata
  (alt-tab cu o fereastra deschisa crapa jocul).

Fiecare fisier modificat spune asta si in antet.

## Continut, nu cod

- Textele oficiale ale testelor si numele scurtaturilor de comenzi (`/acc`, `/rl`, `/gw` ...) provin
  din **SIHelper 1.2.2 by AdeM** si din procedura factiunii School Instructors. Nu sunt creatia mea;
  sunt pastrate ca sa nu se schimbe obiceiurile instructorilor. Vezi „Credite" din README.
- **Pozele de skin** pentru fereastra `/info` nu sunt incluse in acest repo si nu sunt ale mele.
  Helperul functioneaza si fara ele (arata silueta si numarul skin-ului).
- Numele **SICHelper** si logo-ul **ZA** nu sunt acoperite de licenta codului: vezi
  [TRADEMARK.md](TRADEMARK.md).
