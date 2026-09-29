# SICHelper — pentru staff si conducerea factiunii

Documentul asta e scris ca sa poata fi verificat, nu ca sa convinga. Tot codul e in repo si poate fi
citit linie cu linie: `moonloader/SICHelper.lua` (helperul) si `moonloader/SICHelper/pd.lua` (partea
pentru departamente). Textele si comenzile trimise stau in fisierele de date din `moonloader/config/`.

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
| FVR | anunt pe `/f` si `/sx` (la departamente pe `/r` si `/d`), apoi `/fvr` |

### Departamente (PD / FBI / NG), statia `/pdc`

| Cand | Ce trimite |
|---|---|
| alegi un suspect al carui nivel nu e cunoscut | `/id <id>` (raspunsul ramane in chat: e si dovada nivelului) |
| un buton / o scurtatura de sanctiune | linia catre jucator (textul din `config/SICHelper_pd.lua`), apoi, dupa nivel: nimic (avertisment), `/ticket <id>`, `/confiscate <id> drivinglic <ore>` sau `/confiscate <id> <obiect>` |
| nivel 4-7, dupa ce jucatorul alege | varianta aleasa, dintr-un buton apasat de politist |
| butoanele de wanted / `/nec`, `/run`... | `/su <id>` |
| dupa `/ticket` sau `/su` trimis de tine | alege randul potrivit in dialogul serverului si apasa butonul (se poate lasa doar selectat sau opri) |
| somatie / control / teren guvernamental | `/m ...` / textul + `/frisk <id>` / doua linii in chat |
| radar | `/d` (zona libera? / acord / pornire / reluare), `/startradar`, `/stopradar`, `/find`, `/cancel find` |
| cuff / arrest / eject / find | `/cuff`, `/uncuff`, `/arrest`, `/eject`, `/find <id>` |
| duty, patrulare, AFK, nefondat, custodie | `/pin`, `/duty`, `/heal`; linii pe `/d` |

Statia **nu aresteaza, nu da cuff si nu da frisk singura**: nu exista arest automat cand intri intr-o
zona de arrest (butonul doar se aprinde), nici frisk pe toti din jur. Verificarile de regulament (3
somatii in 5 minute si 30 s de asteptare inainte de neconformare, `/frisk` inainte de droguri, 3
intrebari pe `/d` la minim 10 s inainte de radar, radarul doar cu masina oprita) avertizeaza; al doilea
click, in 4 secunde, trimite oricum, pe raspunderea politistului.

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
- **pozitia ta si a candidatului** (pentru distanta afisata in HUD) si checkpoint-ul pus de server;
- la departamente: **linia radarului** (numele, id-ul, nivelul, viteza, limita), **pozitia jucatorilor
  din jur** (lista din statie, cel mai apropiat) si **modelul vehiculului** in care e suspectul, doar
  pentru jucatorii streamati langa tine (aceeasi citire ca in `/info`); textul si pozitia randurilor din
  dialogurile `/ticket` si `/su`, dupa ce le-ai deschis tu.

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
- ce trimite statia PD: cauta `Queue.push` si `PD.say` in `moonloader/SICHelper/pd.lua`;
- ce citeste din memorie: cauta `readMemory` — HP-ul vehiculului candidatului si, in `/info` (folosit si
  de statia PD), skin-ul si vehiculul unui jucator streamat langa tine;
- retea: singura conexiune e verificarea de versiune (fisierul `VERSION` de pe GitHub), care se opreste
  din Features; cauta `downloadUrlToFile` — nu exista altele (`socket`, `http`).

Daca vreti o functie oprita implicit sau scoasa cu totul pentru instructori, spuneti-mi care si o fac;
fiecare automatizare are deja un comutator ON/OFF in `/sih` → Features.

Contact: **ZioAdolf** — Discord `vlandrewz`.
