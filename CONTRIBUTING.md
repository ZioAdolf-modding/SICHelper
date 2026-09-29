# Cum contribui

Mersi ca vrei sa ajuti. Cateva reguli simple:

- **Bug-uri si idei**: deschide un [issue](https://github.com/ZioAdolf-modding/SICHelper/issues). Daca e un
  crash, ataseaza `moonloader/moonloader.log` si `moonloader/SICHelper_trace_prev.txt`.
- **Texte de test, preturi, mesaje**: sunt in `moonloader/config/SICHelper_data.lua`. Un PR acolo e cel
  mai usor de acceptat. Nu schimba textele oficiale ale testelor fara acordul conducerii factiunii.
- **Departamente (PD / FBI / NG)**: textele, comenzile serverului, randurile din dialogurile `/ticket` /
  `/su` si pragurile de nivel / viteza sunt in `moonloader/config/SICHelper_pd.lua`; codul statiei e in
  `moonloader/SICHelper/pd.lua`. Pragurile trebuie sa urmeze regulamentul de pe rules.b-zone.ro.
- **Cod**: fisierul principal e `moonloader/SICHelper.lua`. Stilul: comentarii in romana fara
  diacritice, nume descriptive, fara biblioteci noi. Verifica sintaxa inainte de PR:
  `luajit -e "assert(loadfile('moonloader/SICHelper.lua')) assert(loadfile('moonloader/SICHelper/pd.lua'))"`.
- **Limita de 200 de variabile locale** a Lua e atinsa aproape complet: daca adaugi ceva, pune-l intr-un
  tabel existent (`K`, `State`, `Gen`, `Need`...) in loc de `local` nou. O factiune noua merge intr-un
  fisier separat, ca `moonloader/SICHelper/pd.lua`, care primeste de la scriptul principal ce foloseste.
- **Nu adauga** functii care joaca in locul jucatorului (auto-drive, auto-aim, farming) sau care ascund
  ceva de server. Un PR cu asa ceva nu intra.
- Prin PR accepti ca modificarea ta sa fie distribuita sub GPL-3.0-or-later, ca restul proiectului.

## Cum numerotam versiunile

`MAJOR.MINOR.PATCH`, in stil [SemVer](https://semver.org/lang/ro/), citit pe intelesul unui mod:

| Cifra | Cand creste | Exemplu |
|---|---|---|
| **PATCH** (1.6.**1**) | doar reparatii si corecturi de text; nimic nou, nimic mutat | crash la pornire, o poza intinsa, o greseala de scriere |
| **MINOR** (1.**7**.0) | functii noi, dar setarile si fisierele tale raman valabile | `/info`, `/notepad`, plata catre factiunea aliata |
| **MAJOR** (**2**.0.0) | doar cand cel care actualizeaza **trebuie sa faca ceva** | configul se reseteaza, fisiere redenumite, alta versiune de MoonLoader |

Reguli care tin lantul curat:

- un tag per lansare (`v1.7.0-beta`), niciodata refolosit; fiecare tag are un Release cu arhiva;
- `-beta` / `-rc.1` cat timp versiunea e in probe. La acelasi numar, versiunea finala e mai noua
  decat pre-lansarea: `1.7.0` bate `1.7.0-beta`, iar verificarea de versiune din helper stie asta;
- fisierul `VERSION` din radacina se schimba **odata cu Release-ul**, nu inainte: helperul il citeste
  si ar anunta o versiune care nu se poate descarca inca;
- fiecare lansare intra in `CHANGELOG.md`, la „Adaugat / Schimbat / Reparat";
- daca o versiune cere ceva de la utilizator (suprascrie un fisier, reseteaza o setare), scrie asta
  in **prima linie** a notelor de lansare, nu la subsol.
