# Cum contribui

Mersi ca vrei sa ajuti. Cateva reguli simple:

- **Bug-uri si idei**: deschide un [issue](https://github.com/ZioAdolf-modding/SICHelper/issues). Daca e un
  crash, ataseaza `moonloader/moonloader.log` si `moonloader/SICHelper_trace_prev.txt`.
- **Texte de test, preturi, mesaje**: sunt in `moonloader/config/SICHelper_data.lua`. Un PR acolo e cel
  mai usor de acceptat. Nu schimba textele oficiale ale testelor fara acordul conducerii factiunii.
- **Cod**: fisierul principal e `moonloader/SICHelper.lua`. Stilul: comentarii in romana fara
  diacritice, nume descriptive, fara biblioteci noi. Verifica sintaxa inainte de PR:
  `luajit -e "assert(loadfile('moonloader/SICHelper.lua'))"`.
- **Limita de 200 de variabile locale** a Lua e atinsa aproape complet: daca adaugi ceva, pune-l intr-un
  tabel existent (`K`, `State`, `Gen`, `Need`...) in loc de `local` nou.
- **Nu adauga** functii care joaca in locul jucatorului (auto-drive, auto-aim, farming) sau care ascund
  ceva de server. Un PR cu asa ceva nu intra.
- Prin PR accepti ca modificarea ta sa fie distribuita sub GPL-3.0-or-later, ca restul proiectului.
