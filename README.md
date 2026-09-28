# SICHelper

CMD helper pentru **School Instructors** pe B-Zone RPG (SA:MP). Scris in Lua, pentru MoonLoader.
Deocamdata acopera doar aceasta factiune; celelalte se adauga treptat.

**Versiune:** 1.6.0-beta · **Autor:** ZioAdolf (Discord: `vlandrewz`) · **Licenta:** GPL-3.0-or-later

> **Sursa oficiala: <https://github.com/ZioAdolf-modding/SICHelper>**
> Orice alta copie, arhiva sau build de pe alt site, Discord sau canal nu este oficiala si nu e
> sustinuta de mine. Daca nu ai luat-o din Releases-ul de mai sus, nu e versiunea mea.

---

## Ce face

- **`/sic`** — fereastra de teste: taburi pentru Flying, Sailing, Fishing, Weapons, Materials si 50+.
  Trimite textele oficiale ale testelor pe `/cw` (Sailing: in chatul normal, ca nu esti intr-un vehicul),
  iti arata doar tie raspunsurile corecte, pune `/pagesize 30` la testele cu intrebari si da `/dl` cand e cazul.
- **`/needlicense`** — mesaj clar in chat + notificare pe ecran, cu nivelul luat printr-un `/id` ascuns si
  limba (RO / EN) detectata din cerere. Cererile primite cat ai jocul in bara se arata cand revii.
- **Dupa accept** — jucatorul devine candidatul tau si primeste un `/sms` de confirmare.
- **`/giveme`** — licentele pentru tine (renew): trimite `/givelicense` pe id-ul tau si accepta singur ce ofera serverul.
- **`/withme`** — anunt pe `/f` in formatul factiunii, cu subtotalul licentelor si bonusul AR.
- **`/notepad`** — notitele tale, pe foldere: le trimiti in chat exact cum sunt scrise (text sau comanda)
- **`/info <id>`** — buletinul jucatorului: nivel, ping, FPS, factiunea cu numele rangului, licentele,
  distanta si vehiculul, plus notitele tale despre el (etichete si text liber, salvate pe nume).
  sau le copiezi. Se deschid si din `/sih`, de pe bara de iconite sau de pe o tasta.
- **50+** — licentele pleaca una cate una, fiecare dupa ce a fost acceptata cea dinainte.
- **Pe ecran** — bara de iconite, legenda bind-urilor, distanta pana la checkpoint / candidat,
  raportul saptamanal cat esti on duty, panoul de dovezi (checklist).
- **Altele** — stoplesson automat, repair/refill silentios, redenumirea screenshot-urilor,
  teme de culori pe factiune, interfata care se scaleaza dupa rezolutie.

Lista completa de comenzi e in joc: `/sih` → General → **Comenzi**, si in [docs/COMENZI.md](docs/COMENZI.md).

## Instalare

Ai nevoie de runtime-ul standard pentru orice script `.lua` (nu e inclus in repo):

| Componenta | Versiune testata |
|---|---|
| SA-MP | 0.3.7-R1 |
| GTA San Andreas | 1.0 US |
| ASI Loader | orice (`vorbisFile.dll` / `dinput8.dll`) |
| [SAMPFUNCS](https://www.blast.hk/threads/17/) | 5.4 |
| [MoonLoader](https://www.blast.hk/threads/13305/) | 026.5-beta |

CLEO nu e necesar.

1. Descarca arhiva din [Releases](https://github.com/ZioAdolf-modding/SICHelper/releases).
2. Trage folderul `moonloader` peste folderul jocului si **suprascrie cand te intreaba** - inclusiv
   `moonloader/lib/fAwesome6_solid.lua`, care trebuie sa fie cel din arhiva (iconitele mari).
3. In joc: **Ctrl + R** (reincarca scripturile) sau reporneste jocul.
4. `/sih` → General → alege-ti factiunea si orasul.

Configul se creeaza singur: `moonloader/config/SIC_Helper.ini`.

## Alte factiuni

**Deocamdata helperul e facut pentru School Instructors.** Comenzile, testele, preturile si
procedurile din el sunt ale acestei factiuni. Celelalte se adauga treptat, una cate una.

Terenul e insa pregatit: interfata nu e legata de o anume factiune (o alegi din `/sih` — toate cele
de pe rpg.b-zone.ro sunt in lista, cu culorile si numele rangurilor lor), iar textele, preturile si
mesajele stau in `moonloader/config/SICHelper_data.lua` — un fisier de date, nu cod. Ce lipseste
pentru o alta factiune sunt comenzile si procedura ei specifica.

Vrei factiunea ta la rand? Deschide un [issue](https://github.com/ZioAdolf-modding/SICHelper/issues)
sau scrie-mi pe Discord, cu comenzile si procedura voastra — asa ajunge mai repede pe lista.

## Ce nu face (pentru staff)

Pe scurt: helperul **scrie comenzi in locul tau**, nimic mai mult. Detaliat, in
[docs/PENTRU-STAFF.md](docs/PENTRU-STAFF.md):

- nu joaca singur si nu face nimic fara o comanda sau o apasare de-a ta (singurele lucruri automate sunt
  `/stoplesson` dupa acceptarea licentei, `/sms`-ul de confirmare dupa accept si `/id`-ul folosit ca sa
  afle nivelul — toate pornite din actiunea ta si toate se pot opri din `/sih` → Features);
- nu citeste si nu modifica memoria altor jucatori in afara unui singur caz: HP-ul vehiculului
  candidatului in timpul lectiilor practice, ca sa stii cand a picat testul;
- nu ascunde nimic de server: fiecare comanda pleaca prin chatul normal, exact cum ai scrie-o tu;
- nu are auto-aim, auto-drive, teleport, spawn, money hack sau orice alta functie de trisare;
- singurul lucru ascuns vizual este mesajul de distanta al serverului, cat timp helperul afiseaza
  aceeasi informatie in HUD-ul lui (se poate opri).

## Licenta

[GPL-3.0-or-later](LICENSE). Pe scurt: poti folosi, studia, modifica si redistribui codul, dar
**orice versiune modificata pe care o distribui trebuie sa ramana deschisa, sub aceeasi licenta, si
sa pastreze creditele**. Vezi si [TRADEMARK.md](TRADEMARK.md) pentru nume si logo.

## Credite

- **AdeM** — SIHelper 1.2.2, helperul folosit pana acum in factiune. Textele oficiale ale testelor sunt
  cele din helperul lui, iar scurtaturile (`/acc`, `/rl`, `/sl`, `/gw`, `/gm`, `/gs`, `/gf`, `/gfl`,
  `/sw`, `/sm`, `/ss`, `/sf`, `/sfl`, `/w1..`, `/m1..`, `/f1..`, `/lsfl1..`, `/ccc` si scurtaturile
  generale) pastreaza aceleasi nume ca la el. SICHelper e scris de la zero, pe structura de comenzi cu
  care instructorii erau deja obisnuiti.
- **urShadow** — [mimgui](https://github.com/THE-FYP/SAMP.Lua) si `samp.events`.
- **FYP** — MoonLoader si ML-ReloadAll.
- **FlaCode & Cosmo** — HassleHUD (inspiratie pentru HUD).

Bibliotecile din `moonloader/lib/` sunt ale autorilor lor si isi pastreaza licentele proprii:
lista completa, cu autori si licente, e in [THIRD-PARTY.md](THIRD-PARTY.md).
