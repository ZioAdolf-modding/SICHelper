# SICHelper — pentru staff si conducerea factiunii

Documentul asta e scris ca sa poata fi verificat, nu ca sa convinga. Tot codul e in repo, intr-un
singur fisier (`moonloader/SICHelper.lua`), si poate fi citit linie cu linie.

## Ce este

Un **CMD helper**: scrie comenzi in chat in locul instructorului, ca sa nu le tasteze manual la fiecare
test. Acelasi lucru pe care il facea SIHelper 1.2.2 (by AdeM), folosit in factiune pana acum.

Tehnic: script **Lua** pentru MoonLoader (nu `.asi`, nu injector, nu DLL propriu). Interfata e
desenata cu mimgui (ImGui). Nu are componente compilate scrise de mine — singurele `.dll` din arhiva
sunt bibliotecile publice mimgui si iconv, aceleasi pe care le foloseste orice script MoonLoader.

## Ce trimite catre server

Tot ce trimite pleaca prin chatul normal (`sampSendChat`), exact cum ar scrie jucatorul:

| Cand | Ce trimite |
|---|---|
| apesi butonul Accept / bind / `/acc` | `/accept needlicense <id>` |
| dupa un accept reusit (optional, se poate opri) | `/sms <id> <text din fisierul de date>` |
| la un `/needlicense` primit, daca nu stim nivelul | `/id <id>` (raspunsul serverului e ascuns din chatul tau, nu si de server) |
| butonul RL / `/rl` | `/requestlicenses <id>` |
| Start lesson / `/sw` etc. | `/startlesson <id> <licenta>` |
| butoanele T1..T3 / Q1..Q5 | `/cw <textul oficial al testului>` (la Sailing, in chatul normal) |
| Give license / `/gw` etc. | `/givelicense <id> <licenta>` |
| Failed / `/sl` / automat dupa acceptarea licentei | `/stoplesson <id>` |
| `/withme` | `/id <id>`, apoi anuntul pe `/f` |
| `/sxwas` | intrebarea pe `/sx` |
| `/salut`, `/pa`, `/need`, `/ok` | `/w <id> <text>` |
| `/giveme` (licentele pentru tine) | `/givelicense <id-ul tau> <licenta>`, apoi `/accept license <id-ul tau>` |
| cu un checkpoint activ, inainte de accept | `/cancel find`, `/killcp` (optional) |
| Repair / refill | `/switchjob`, `/repair`, `/refill`, `/switchjob` |
| FVR | anunt pe `/f` si `/sx`, apoi `/fvr` |

Textele nu sunt „inventate" de script: stau in `moonloader/config/SICHelper_data.lua`, un fisier
de date pe care oricine il poate citi si edita. Testele sunt cele oficiale, preluate din helperul lui
AdeM, ca sa nu se schimbe continutul examinarii.

Intre comenzi exista o pauza reglabila (implicit ~1 secunda) ca sa nu se trimita mai multe pe frame.

## Ce citeste din joc

- **chatul serverului** — ca sa stie cand cineva a dat `/needlicense`, cand a acceptat licenta, cand
  esti on/off duty, ce nivel are jucatorul (din raspunsul la `/id`);
- **numele si id-urile** jucatorilor conectati, prin SAMPFUNCS (acelasi lucru pe care il vezi in `/id`
  sau in scoreboard);
- **HP-ul vehiculului candidatului**, doar in timpul unei lectii de Flying sau Sailing, doar pentru
  jucatorul cu care faci lectia, ca sa te anunte cand a scazut sub 950 (conditia de picare). E singura
  citire din memoria jocului si se poate opri din `/sih` → Features → „HP vehicul live";
- **pozitia ta si a candidatului** (pentru distanta afisata in HUD) si checkpoint-ul pus de server.

## Ce NU face

- nu joaca singur: nu exista auto-drive, auto-aim, auto-farm, macro de miscare, teleport, spawn,
  money hack sau modificari ale jocului;
- nu trimite nimic fara o actiune a ta, cu trei exceptii, toate pornite tot de actiunea ta si toate
  oprite dintr-un comutator: `/stoplesson` dupa ce candidatul accepta licenta, `/sms`-ul de confirmare
  dupa accept si `/id`-ul care afla nivelul;
- nu modifica pachetele catre server si nu ascunde nimic de server;
- nu trimite date nicaieri in afara jocului: nu are conexiuni la internet, nu are telemetrie, nu
  citeste fisiere din afara folderului jocului;
- singurul lucru ascuns din interfata ta este mesajul de distanta al serverului, cat timp helperul
  afiseaza aceeasi distanta in HUD-ul lui (`/sih` → Features → „Ascunde distanta serverului").

## Ce scrie pe disc

- `moonloader/config/SIC_Helper.ini` — setarile tale;
- `moonloader/SICHelper_trace.txt` (si `_prev.txt`) — o urma de diagnostic: ce comenzi a trimis, ce
  ferestre s-au deschis, cand a pierdut focusul jocul. E doar pentru depanare si poate fi citita;
- redenumeste screenshot-urile facute cu butonul din `/sic`, in acelasi folder in care le pune SA:MP.

## Verificare rapida

- tot codul: `moonloader/SICHelper.lua`, cu comentarii in romana;
- ce trimite: cauta in fisier `Queue.push` si `sampSendChat` — fiecare comanda trimisa trece pe acolo;
- ce citeste din memorie: cauta `readMemory` — apare in doua linii alaturate, la HP-ul vehiculului;
- fara retea: cauta `http`, `socket`, `require("socket")` — nu exista.

Daca vreti o functie oprita implicit sau scoasa cu totul pentru instructori, spuneti-mi care si o fac;
fiecare automatizare are deja un comutator ON/OFF in `/sih` → Features.

Contact: **ZioAdolf** — Discord `vlandrewz`.
