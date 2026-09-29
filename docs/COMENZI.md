# Comenzi

Toate comenzile sunt ale helperului (client-side): nu exista pe server, sunt inregistrate de script.
Ce ajunge la server sunt comenzile din coloana „trimite".

## De baza

| Comanda | Ce face | Trimite |
|---|---|---|
| `/sic` | fereastra de teste (taburi pe licente + 50+); la departamente, statia PD | — |
| `/sih` | setari: limba, factiune, feature-uri, bind-uri, tutorial | — |
| `/withme <id> <1-6>` | anunta candidatul pe `/f`, cu subtotal si bonus AR | `/id`, apoi `/f ...` |
| `/withme` | deschide fereastra (alegi id + licente) | — |
| `/sxwas <id>` | intreaba pe `/sx` daca l-a acceptat deja cineva | `/sx ...` |
| `/siccand <id>` | seteaza manual candidatul | — |
| `/sicraport` | fereastra de raport (bare de progres, contoarele sesiunii) | — |
| `/notepad` (`/note`, `/notite`) | notitele tale, pe foldere: le trimiti in chat sau le copiezi | textul notitei, daca apesi „trimite" |
| `/info <id\|nume>` | buletinul jucatorului: nivel, factiune + rang, licente, notitele tale | `/id` (ascuns) |
| `/sicinfo [id]` | acelasi, dar mereu al helperului (fara id: candidatul / cel mai apropiat) | `/id` (ascuns) |
| `/sicreset` | readuce ferestrele si HUD-urile la pozitia implicita | — |
| `/sicpay` | trimite acum platile catre aliati care asteptau `/pin` | `/pay ...` |
| `/sicwizard` | redeschide ghidul de pornire | — |
| `/ffvr` / `/sfvr` | porneste / opreste FVR | `/f`, `/sx`, `/fvr` |

## Mesaje catre candidat (pe `/w`)

| Comanda | Text (editabil in `config/SICHelper_data.lua`) |
|---|---|
| `/salut <id>` | salut + „arata-mi licentele" |
| `/pa <id>` | la revedere |
| `/need <id>` | „ai nevoie de renew / licente expirate?" |
| `/ok <id>` | „felicitari, ai trecut" |

Fara id, merg la candidat (`/need`: la cel mai apropiat jucator). Limba urmeaza limba candidatului.

## Scurtaturi (din SIHelper by AdeM, aceleasi nume)

| Comanda | Trimite |
|---|---|
| `/acc [id]` | `/accept needlicense` (fara id: ultimul `/needlicense`) |
| `/rl [id]` | `/requestlicenses` |
| `/sl [id]` | `/stoplesson` |
| `/gw` `/gm` `/gs` `/gf` `/gfl` `[id]` | `/givelicense` Weapon / Materials / Sailing / Fishing / Flying |
| `/sw` `/sm` `/ss` `/sf` `/sfl` `[id]` | `/startlesson` pe aceleasi licente |
| `/w1`..`/w5`, `/m1`..`/m4`, `/f1`..`/f4` | textele testelor Weapons / Materials / Fishing |
| `/lsfl1`..`3`, `/lvfl1`..`3`, `/sffl1`..`3` | task-urile Flying pe oras |
| `/lss1`..`2`, `/lvs1`..`2`, `/sfs1`..`2` | task-urile Sailing pe oras |
| `/ccc` | curata chatul (30 de linii goale) |
| `/sicneed 0-3` | diagnostic: cat de mult prelucreaza helperul un `/needlicense` |

Scurtaturile generale (`/m`, `/cm`, `/sv`, `/sj`, `/ha`, `/ra`...) sunt oprite implicit:
`/sih` → Features → Aspect → „Comenzi scurte generale (by AdeM)".

## Departamente (PD / FBI / NG)

Merg cand factiunea din `/sih` e Police Department, FBI sau National Guard (sau un click pe
**Departamente**, sus in `/sih` → General → Interfata). Atunci si `/sic` deschide statia PD. La alte factiuni, scurtaturile de mai jos pleaca neschimbate
la server. Fara id, lucreaza pe suspectul din statie; nivelul se afla singur cu `/id`.

| Comanda | Ce face | Trimite |
|---|---|---|
| `/pdc [id]` (`/pds`) | statia de control; cu id, il face suspect | `/id <id>` pentru nivel |
| `/pdh` | setarile (aceeasi fereastra ca `/sih`) | — |
| `/san <id>` | deschide statia pe jucator | `/id` |
| `/sl [id]` / `/last` | viteza ultimului prins de radar (sau a unuia din lista) / lista | textul + `/ticket` / `/confiscate` dupa nivel |
| `/aa` `/aa50` `/aa100 [id]` | viteza, manual: sub 50 / peste 50 / peste 100 | idem |
| `/faruri` `/car` `/alc15` `/alc30` `/nos` `/con` `/parc` `/hidra [id]` | abaterile rutiere | idem |
| `/arme` `/dr` `/cdr` `/matslic` `/mats [id]` | arme, droguri (posesie / consum), materiale | textul + `/confiscate` (+ `/ticket`) |
| `/nec` `/run` `/cat` `/wdr` `/notp` `/comp` `/nef [id]` | wanted: neconformare, runner, atac, droguri, neplata, complice, nefondat | `/su <id>` + randul din dialog |
| `/mm [id]` | somatie (se numara, 3 in 5 minute) | `/m ...` |
| `/cl [id]` | control de rutina | textul + `/frisk <id>` |
| `/tg [id]` | avertisment: teren guvernamental | doua linii in chat |
| `// [id]` | nefondat pe `/d` | `/d ...` |
| `/ll` / `/potls` `/potlv` `/potsf` | zona de radar libera? / acord pentru alt oras (x2, x3) | `/d ...` |
| `/patls` `/patlv` `/patsf` | patrulare in alt oras | `/d ...` |
| `/sto` / `/sta [limita]` | opreste / porneste (reia) radarul | `/stopradar`, `/startradar`, `/d ...` |
| `/afk [id]` / `/stopafk` | cu id: anunta pe `/d` si numara 3 minute; fara id: 30 s | `/d ...` |
| `/hdt` / `/dt` | duty | `/pin`, `/duty`, `/heal` / `/pin`, `/duty` |

Taste (`/sih` → Bind-uri → Departamente): statia, radarul (porneste / opreste + find / reia), suspect =
cel mai apropiat, somatie, `/ms`, control, cuff, arrest, tazer, `/wanted`, `/nearwanted`, poarta.
