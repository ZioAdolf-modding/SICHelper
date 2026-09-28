# Changelog

Formatul: [Keep a Changelog](https://keepachangelog.com/ro/1.1.0/); versionare [SemVer](https://semver.org/lang/ro/).

## [Nepublicat]

### Adaugat
- **Factiune aliata**: cand dai o licenta unui membru al factiunii aliate, helperul ii trimite
  pretul inapoi cu `/pay`, imediat ce jucatorul accepta licenta. Factiunea lui se afla din
  raspunsul la `/id` (pe care helperul il citea oricum), iar suma e pretul din fisierul de date,
  la nivelul lui, fara bonusul AR - acela vine de la factiune, nu din buzunarul jucatorului.
  Aliatul implicit e in `config/SICHelper_data.lua` (`data.allies`; SF School Instructors ->
  Paramedics) si se poate schimba din `/sih` -> Features. Oprit din start.
  Daca nu ti-ai deblocat banii cu `/pin`, plata asteapta, te anunta pe ecran si pleaca singura
  imediat ce dai `/pin`; `/sicpay` o trimite pe loc.


## [1.6.0-beta] — 2026-09-28

### Adaugat
- **`/info <id>`** (si `/sicinfo`, sau o tasta): buletinul jucatorului intr-o singura fereastra care se
  schimba - nivel, ping, FPS, factiunea cu numele rangului, licentele din ultimul `/requestlicenses`,
  distanta si vehiculul daca e langa tine, limba, si istoricul licentelor date de tine.
  In josul ferestrei scrii **notitele tale despre el** (etichete gata facute plus text liber); se
  salveaza in `config/SICHelper_players.lua`, pe nume de jucator. Etichetele se schimba din fisierul
  de date (`data.player_tags`). Fara argumente, `/info` pleaca la server, ca inainte.
  Daca pui un pachet de poze in `moonloader/resource/skins/<id>.png`, apare si skin-ul.
  Raspunsul la `/id` se citeste pe segmente, nu dupa pozitie: ultimul segment poate fi
  `Onyx Skin: 289` / `Diamond Skin: 289` in loc de factiune. Acela e id-ul skin-ului (il folosim
  pentru poza, si pentru jucatorii care nu sunt langa tine), iar factiunea ramane goala.
- **Reseteaza aranjamentul** (`/sih` -> General -> Ferestre, sau `/sicreset`): readuce toate ferestrele
  si panourile de pe ecran la pozitia si marimea implicita.
- **Verificare de versiune**: la pornire compara versiunea cu cea de pe sursa oficiala si, daca e una
  mai noua, scrie o linie in chat si in `/sih`. Nu trimite nimic despre tine si se opreste din
  Features -> „Verifica versiunea".
- **Ghid de pornire** in 4 pasi la prima instalare (limba, factiunea si orasul, trei taste, apoi ce
  faci la prima licenta). Se redeschide din `/sih` -> General sau cu `/sicwizard`.

### Reparat
- Crash la pornire pe modpack-urile care au deja o versiune mai veche a fisierului
  `lib/fAwesome6_solid.lua`: cautarea unui nume de iconita inexistent intra, in acel fisier, in
  recursie infinita si omora scriptul inainte sa porneasca (`Script died due to an error`, cu zeci
  de linii `in function '__index'`). Acum fiecare citire din fontul de iconite trece prin `pcall`:
  ce lipseste devine text gol, helperul porneste normal si te anunta o singura data in chat sa
  suprascrii fisierul de font cu cel din arhiva.
- Poza de skin din `/info` isi pastreaza proportiile (sursele sunt 165x300): nu mai e intinsa in patrat.



## [1.5.0-beta] — 2026-09-28

### Adaugat
- `/notepad` (`/note`, `/notite`): notitele tale, organizate pe foldere. Fiecare notita se poate
  trimite in chat exact cum e scrisa (text sau comanda) sau copia in clipboard; dublu-click o
  modifica. Se salveaza in `moonloader/config/SICHelper_notes.lua` si se deschide si din
  `/sih` -> General -> „Notitele mele", din bara de iconite sau de pe o tasta.
  La prima pornire aduce notitele din scriptul `Notepad.lua` (`config/Notepad.ini`), daca exista.
- `/notepad`: click in afara ferestrei o inchide (ce era in editare se salveaza), iar dublu-click pe un
  folder il redenumeste pe loc. ESC renunta la editare, nu inchide fereastra.
- Numele rangurilor pentru fiecare factiune, in fisierul de date (`data.ranks`): numarul din `/id`
  devine numele rangului. Serverul numeroteaza de la 7 (lider) la 0; rangul 0 e cel care trebuie sa
  dea testul de intrare. Factiunile fara nume proprii (PD / FBI / NG, primaria, mafii, ganguri)
  ramin pe „Rang N".

### Reparat
- Randul cu distanta nu mai ramane pe ecran: click pe el il inchide, checkpoint-ul dispare singur
  sub 8 metri sau dupa 15 minute.
- `/giveme` functioneaza pe propriul id (`sampIsPlayerConnected` e fals pentru tine).


## [1.4.0-beta] — 2026-09-26

Prima versiune publica (beta).

### Adaugat
- `/sih` reorganizat: sectiuni pliabile cu rezumat, cautare peste toate setarile din toate taburile,
  sectiunea „Tastele mele" cu adaugare de bind pe loc.
- Bara de iconite pe ecran (/sic, /withme, /raport, /sih, DUTY), mutabila, verticala sau orizontala.
- Legenda bind-urilor pe ecran, redimensionabila, cu distanta pana la checkpoint si pana la candidat.
- Mesaje gata scrise catre candidat: `/salut`, `/pa`, `/need`, `/ok` (pe `/w`) si `/sms` de confirmare
  dupa accept; limba (RO / EN) detectata din cererea jucatorului.
- Scurtaturile din SIHelper by AdeM: `/acc`, `/rl`, `/sl`, `/gw`, `/gm`, `/gs`, `/gf`, `/gfl`, `/sw`,
  `/sm`, `/ss`, `/sf`, `/sfl`, `/w1..`, `/m1..`, `/f1..`, `/lsfl1..`, `/ccc` si scurtaturile generale.
- Butonul RL in `/sic`, „inchide tot" in capul ferestrelor, tooltip pe fiecare buton care trimite ceva.
- Teme de culori pe categorii de factiuni; interfata se scaleaza dupa rezolutie.
- Cererile de `/needlicense` primite cat jocul e in bara se arata la revenire (maximum 5 minute).

### Schimbat
- Nivelul jucatorilor se afla prin `/id` (raspuns ascuns), nu din scoreboard.
- Textele testului de Sailing pleaca in chatul normal, nu pe `/cw`.
- Raportul creste cand trimiti licenta, nu cand o accepta jucatorul.

### Reparat
- Crash-ul la `/needlicense` (citirea scorului din scoreboard pentru jucatori nestreamati).
- Crash-ul la deschiderea listei de bind-uri (stiva imgui).
- Liniile lungi de chat, taiate acum la limita clientului (144 de caractere).
