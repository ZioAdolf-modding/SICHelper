-- ============================================================
-- SICHelper - DATE PENTRU DEPARTAMENTE (Police Department / FBI / National Guard)
-- ============================================================
-- Citit de moonloader/SICHelper/pd.lua la pornire (Ctrl+R dupa ce il modifici).
-- Tot ce tine de server sta aici: comenzile, textele trimise, randurile din dialogurile
-- /ticket si /su, pragurile de nivel si de viteza. Pentru alt server schimbi doar fisierul asta.
--
-- Textele folosesc nume intre acolade, nu %s / %d:
--   {name} numele suspectului   {id} id-ul lui     {level} nivelul    {zone} zona radarului
--   {speed} viteza prinsa       {limit} limita     {over} km/h peste limita
--   {hours} "o ora" / "2 ore"   {city} LS/SF/LV    {wanted} nivelul de wanted
-- Codurile de culoare SA:MP ({FF0000}) raman neatinse.
-- Un text poate fi un singur sir (acelasi in orice limba) sau { ro = "...", en = "..." }.
--
-- Surse:
--   * rules.b-zone.ro -> Regulament departamente si Regulament PD (citite in septembrie 2026);
--   * PDHelper V7.5 by TheTom: comenzile serverului si pozitia randurilor in dialogurile
--     /ticket si /su (folosite in joc pana in decembrie 2024).
-- Ce e marcat "DE VERIFICAT" nu a putut fi confirmat: verifica in joc si corecteaza aici.
-- ============================================================

local pd = {}

-- ------------------------------------------------------------
-- GENERAL
-- ------------------------------------------------------------
-- comenzile helperului care deschid statia (prima e cea afisata peste tot)
pd.commands = { "pdc", "pds" }
-- factiunile din /sih pentru care se foloseste interfata de departament (statia, scurtaturile, bara)
pd.factions = { "pd", "fbi", "ng" }
-- scurtaturile din PDHelper (/aa, /nos, /nec, /sl, /mm...). Merg doar cand factiunea ta e una de mai sus;
-- altfel comanda pleaca neschimbata la server, ca si cum helperul n-ar exista.
pd.shortcuts = true
-- dialogurile /ticket si /su: "press" = helperul alege randul si apasa butonul,
-- "select" = doar il selecteaza (tu apesi Enter), "off" = nu atinge dialogul
pd.dialog_pick = "press"

-- ------------------------------------------------------------
-- COMENZILE SERVERULUI
-- ------------------------------------------------------------
pd.cmd = {
    id         = "/id {id}",
    ticket     = "/ticket {id}",
    license    = "/confiscate {id} drivinglic {n}",   -- {n} = numarul de ore
    seize      = "/confiscate {id} {item}",            -- {item} = weapons / drugs / materials
    su         = "/su {id}",
    frisk      = "/frisk {id}",
    cuff       = "/cuff {id}",
    uncuff     = "/uncuff {id}",
    arrest     = "/arrest {id}",
    eject      = "/eject {id}",
    find       = "/find {id}",
    cancelfind = "/cancel find",
    startradar = "/startradar {limit}",
    stopradar  = "/stopradar",
    reqlic     = "/requestlicenses {id}",
    tazer      = "/tazer",
    wanted     = "/wanted",
    nearwanted = "/nearwanted",
    ms         = "/ms",                                 -- somatia serverului, pe jucatorul pe care ai /find
    duty       = { "/pin", "/duty", "/heal" },          -- butonul Duty (in ordine)
}

-- mesajele serverului la /duty (DE VERIFICAT pentru departamente; cele de instructor sunt deja in helper)
pd.duty_on  = { "You are now on duty", "Esti acum la datorie", "Esti acum on duty" }
pd.duty_off = { "You are now off duty", "Nu mai esti la datorie", "Esti acum off duty" }

-- ------------------------------------------------------------
-- NIVELURI (Regulament PD: "Depasirea limitei de viteza")
--   1-3  doar avertisment, fara sanctiune
--   4-7  aleg intre amenda si suspendarea permisului
--   8+   amenda si suspendarea permisului
-- PDHelper V7.5 folosea 1-4 / 5-7 / 8+; regulamentul actual spune 1-3 / 4-7 / 8+.
-- ------------------------------------------------------------
local WARN_MAX, CHOOSE_MAX = 3, 7
pd.levels = { warn_max = WARN_MAX, choose_max = CHOOSE_MAX }

-- ce se intampla dupa nivel. "act" poate fi:
--   warn  doar avertisment            fine   amenda (/ticket)          lic  permisul suspendat
--   seize confiscare (/confiscate)     a+b    ambele                    a|b  jucatorul alege
-- "max" = pana la ce nivel se aplica randul; ultimul rand nu are "max".
pd.brackets = {
    fine       = { { max = WARN_MAX, act = "warn" }, { act = "fine" } },
    tiered     = { { max = WARN_MAX, act = "warn" }, { max = CHOOSE_MAX, act = "fine|lic" }, { act = "fine+lic" } },
    seize      = { { act = "seize" } },
    seize_fine = { { act = "seize+fine" } },
    -- folosire materiale: ca in PDHelper (DE VERIFICAT in regulament)
    mats_use   = { { max = WARN_MAX, act = "warn" }, { max = CHOOSE_MAX, act = "fine|seize" }, { max = 19, act = "seize" }, { act = "seize+fine" } },
}

-- ------------------------------------------------------------
-- VITEZA SI RADAR
-- ------------------------------------------------------------
pd.speed = {
    limits = { 100, 130, 160 },   -- oras / in afara oraselor / autostrada
    -- "over" = de la cati km/h peste limita se aplica treapta (1-2 km/h peste limita nu se sanctioneaza)
    tiers = {
        { over = 3,   rule = "fine",   ticket = "speed",
          label = { ro = "Viteza: sub 50 peste", en = "Speeding: under +50" },
          phrase = { ro = "sub 50 km/h", en = "under 50 km/h" } },
        { over = 50,  rule = "tiered", ticket = "speed50", hours = 1,
          label = { ro = "Viteza: peste 50", en = "Speeding: over +50" },
          phrase = { ro = "peste 50 km/h", en = "over 50 km/h" } },
        { over = 100, rule = "tiered", ticket = "speed50", hours = 2,
          label = { ro = "Viteza: peste 100", en = "Speeding: over +100" },
          phrase = { ro = "peste 100 km/h", en = "over 100 km/h" } },
    },
    say_radar  = { ro = "Salut {name}! Radarul te-a prins cu {speed} km/h in zona {zone}, limita fiind {limit} km/h.",
                   en = "Hi {name}! The radar caught you at {speed} km/h in {zone}, the limit is {limit} km/h." },
    say_manual = { ro = "Salut {name}! Ai depasit limita de viteza cu {phrase} in zona {zone} (limita {limit} km/h).",
                   en = "Hi {name}! You broke the speed limit by {phrase} in {zone} (limit {limit} km/h)." },
}

pd.radar = {
    -- linia serverului cand cineva trece prin radar; capturi: nume, id, nivel, viteza, limita
    catch = {
        "(%S+) %[ID:(%d+), L:(%d+)%] is driving with (%d+) km/h, limit: (%d+) km/h",
        "(%S+) %[ID:(%d+), N:(%d+)%] conduce cu (%d+) km/h, limita: (%d+) km/h",
    },
    ask_times   = 3,     -- de cate ori intrebi pe /d (regulament: 3)
    ask_gap     = 10,    -- secunde minime intre doua intrebari (regulament: 10)
    permit_wait = 60,    -- fara raspuns la cererea de acord: poti pune radarul dupa atatea secunde
    refused_wait = 300,  -- refuzat (motiv valid): astepti atatea secunde pana la o noua cerere
    keep = 8,            -- cati jucatori prinsi raman in lista
    repeat_suffix = " x{n}",   -- a doua / a treia intrebare: "... x2", "... x3"
    say = {
        free   = "/d Este libera zona de radar {zone}?",
        permit = "/d {city}PD, imi permiteti sa amplasez radar in zona {zone}?",
        start  = "/d Pun radar in zona {zone}.",
        resume = "/d Reiau radarul din zona {zone}.",
    },
}

-- ------------------------------------------------------------
-- RANDURILE DIN DIALOGUL /ticket
-- index = pozitia randului (de la 0), ca in PDHelper V7.5
-- find  = bucati de text care confirma randul (inceput de cuvant, fara litere mari/mici)
-- avoid = daca randul contine asa ceva, nu e cel bun
-- Helperul alege: randul de la "index" daca se potriveste cu "find"; altfel primul rand care se
-- potriveste; altfel "index". Randul ales se scrie in chat, ca sa vezi ce a apasat.
-- ------------------------------------------------------------
pd.ticket = {
    lines = {
        parking    = { index = 0,  find = { "parcare", "parcat", "parking", "parked" } },
        wrongway   = { index = 1,  find = { "contrasens", "contra-sens", "neregulamentar", "wrong", "reckless" } },
        hydraulics = { index = 3,  find = { "hidraul", "hydraul" } },
        nos        = { index = 4,  find = { "nos", "nitro" } },
        materials  = { index = 5,  find = { "material" } },
        lights     = { index = 6,  find = { "farur", "headlight", "lights" } },
        speed      = { index = 7,  find = { "vitez", "speed" }, avoid = { "50", "100" } },
        speed50    = { index = 8,  find = { "vitez", "speed" } },
        walk       = { index = 10, find = { "carosabil", "roadway", "pieton", "pedestrian" } },
        alcohol    = { index = 11, find = { "alcool", "alcohol" } },
    },
}

-- ------------------------------------------------------------
-- MOTIVELE DE WANTED (/su), in ordinea din statie
-- needs = "somatie": regulamentul cere 3 somatii in maxim 5 minute si 30 s de asteptare inainte
--         "frisk":   drogurile se sanctioneaza doar cu dovada din /frisk
-- Daca motivul nu e indeplinit, primul click te avertizeaza; al doilea (in 4 s) trimite oricum.
-- shortcut = comanda scurta din PDHelper
-- ------------------------------------------------------------
pd.su = {
    { id = "nec",   index = 2,  find = { "neconform", "disob", "ordin" }, needs = "somatie", shortcut = "nec",
      label = { ro = "Neconformare (W2)", en = "Disobeying orders (W2)" } },
    { id = "run",   index = 12, find = { "runner", "fug", "evad", "escap" }, shortcut = "run",
      label = { ro = "Runner", en = "Runner" } },
    { id = "cop",   index = 6,  find = { "atac", "attack", "agres" }, shortcut = "cat",
      label = { ro = "Atac politist (W3)", en = "Attacking an officer (W3)" } },
    { id = "drugs", index = 5,  find = { "drog", "drug" }, needs = "frisk", shortcut = "wdr",
      label = { ro = "Droguri (W3)", en = "Drugs (W3)" } },
    { id = "notp",  index = 7,  find = { "neplat", "amenz", "unpaid", "not paying" }, shortcut = "notp",
      label = { ro = "Neplata amenzii", en = "Unpaid fine" } },
    { id = "comp",  index = 13, find = { "complic", "accomplice" }, shortcut = "comp",
      label = { ro = "Complice", en = "Accomplice" } },
    { id = "nef",   index = 1,  find = { "nefondat", "unfounded" }, shortcut = "nef",
      label = { ro = "Apel nefondat", en = "Unfounded call" } },
    -- fara index cunoscut: helperul cauta randul dupa text; daca nu il gaseste, il alegi tu
    { id = "gov",   find = { "guvern", "government" },
      label = { ro = "Teren guvernamental (W2)", en = "Governmental area (W2)" } },
}

-- ------------------------------------------------------------
-- ABATERILE (butoanele din tab-urile Rutier si Control)
-- rule    = randul din pd.brackets     ticket = randul din pd.ticket.lines
-- hours   = orele de permis            item   = ce se confisca (/confiscate)
-- then_su = motivul de wanted propus dupa (un buton, nu automat)
-- say     = prima linie spusa jucatorului; urmeaza linia potrivita din pd.outcome
-- outcome = inlocuieste linia din pd.outcome pentru abaterea asta
-- ------------------------------------------------------------
pd.offences = {
    -- rutier ("speed" e tratata separat, dupa treptele de mai sus)
    { id = "lights", group = "road", rule = "fine", ticket = "lights", shortcut = "faruri",
      label = { ro = "Faruri stinse", en = "Headlights off" },
      say = { ro = "Salut {name}! Ai uitat sa iti aprinzi farurile.", en = "Hi {name}! You forgot to turn on your headlights." } },
    { id = "walk", group = "road", rule = "fine", ticket = "walk", shortcut = "car",
      label = { ro = "Mers pe carosabil", en = "Walking on the road" },
      say = { ro = "Salut {name}! Ai fost surprins(a) mergand pe carosabil.", en = "Hi {name}! You were caught walking on the roadway." } },
    { id = "alc15", group = "road", rule = "fine", ticket = "alcohol", shortcut = "alc15",
      label = { ro = "Alcoolemie peste 1.5", en = "Alcohol over 1.5" },
      say = { ro = "Salut {name}! Ai fost surprins(a) conducand cu o alcoolemie mai mare de 1.5.", en = "Hi {name}! You were caught driving with a blood alcohol level over 1.5." } },
    { id = "alc30", group = "road", rule = "tiered", hours = 1, ticket = "alcohol", shortcut = "alc30",
      label = { ro = "Alcoolemie peste 3.0", en = "Alcohol over 3.0" },
      say = { ro = "Salut {name}! Ai fost surprins(a) conducand cu o alcoolemie mai mare de 3.0.", en = "Hi {name}! You were caught driving with a blood alcohol level over 3.0." } },
    { id = "nos", group = "road", rule = "tiered", hours = 1, ticket = "nos", shortcut = "nos",
      label = { ro = "NOS pe drum public", en = "NOS on a public road" },
      say = { ro = "Salut {name}! Ai fost surprins(a) conducand un vehicul folosind NOS.", en = "Hi {name}! You were caught using NOS on a public road." } },
    { id = "wrongway", group = "road", rule = "tiered", hours = 1, ticket = "wrongway", shortcut = "con",
      label = { ro = "Contrasens / neregulamentar", en = "Wrong way / reckless" },
      say = { ro = "Salut {name}! Ai fost surprins(a) conducand neregulamentar.", en = "Hi {name}! You were caught driving recklessly." } },
    { id = "parking", group = "road", rule = "tiered", hours = 1, ticket = "parking", shortcut = "parc",
      label = { ro = "Parcare ilegala", en = "Illegal parking" },
      say = { ro = "Salut {name}! Ai fost surprins(a) parcand neregulamentar.", en = "Hi {name}! You were caught parking illegally." } },
    { id = "hydraulics", group = "road", rule = "tiered", hours = 1, ticket = "hydraulics", shortcut = "hidra",
      label = { ro = "Hidraulice pe drum public", en = "Hydraulics on a public road" },
      say = { ro = "Salut {name}! Ai fost surprins(a) folosind hidraulice pe drumul public.", en = "Hi {name}! You were caught using hydraulics on a public road." } },

    -- control (dupa /frisk)
    { id = "weapons", group = "frisk", rule = "seize", item = "weapons", shortcut = "arme",
      label = { ro = "Arme la vedere", en = "Weapons in sight" },
      say = { ro = "Salut {name}! Ai fost surprins(a) cu armele la vedere.", en = "Hi {name}! You were caught with your weapons in sight." } },
    { id = "drugs", group = "frisk", rule = "seize", item = "drugs", then_su = "drugs", needs = "frisk", shortcut = "dr",
      label = { ro = "Posesie droguri", en = "Drug possession" },
      say = { ro = "Salut {name}! Ai fost surprins(a) detinand droguri.", en = "Hi {name}! You were caught carrying drugs." },
      outcome = { seize = { ro = "Ti le voi confisca si vei primi Wanted 3.", en = "I'll confiscate them and you'll get Wanted 3." } } },
    { id = "drugs_use", group = "frisk", rule = "seize", item = "drugs", then_su = "drugs", shortcut = "cdr",
      label = { ro = "Consum droguri", en = "Drug use" },
      say = { ro = "Salut {name}! Ai fost surprins(a) consumand droguri.", en = "Hi {name}! You were caught using drugs." },
      outcome = { seize = { ro = "Ti le voi confisca si vei primi Wanted 3.", en = "I'll confiscate them and you'll get Wanted 3." } } },
    { id = "mats_nolic", group = "frisk", rule = "seize_fine", item = "materials", ticket = "materials", shortcut = "matslic",
      label = { ro = "Materiale fara licenta", en = "Materials, no license" },
      say = { ro = "Salut {name}! Ai fost surprins(a) detinand materiale fara licenta.", en = "Hi {name}! You were caught carrying materials without a license." } },
    { id = "mats_use", group = "frisk", rule = "mats_use", item = "materials", ticket = "materials", shortcut = "mats",
      label = { ro = "Folosire materiale", en = "Using materials" },
      say = { ro = "Salut {name}! Ai fost surprins(a) folosind materiale.", en = "Hi {name}! You were caught using materials." } },
}

-- a doua linie, dupa ce se hotaraste (nivelul decide "act")
pd.outcome = {
    warn           = { ro = "De data asta primesti doar un avertisment (nivel {level}). Fii atent(a)!",
                       en = "This time it's only a warning (level {level}). Be careful!" },
    fine           = { ro = "Iti voi acorda o amenda.", en = "I'll give you a ticket." },
    lic            = { ro = "Iti voi suspenda permisul de conducere {hours}.", en = "I'll suspend your driving license for {hours}." },
    ["fine+lic"]   = { ro = "Iti voi suspenda permisul {hours} si vei primi o amenda.", en = "I'll suspend your license for {hours} and give you a ticket." },
    ["fine|lic"]   = { ro = "Doresti amenda sau suspendarea permisului {hours}?", en = "Do you want a ticket or your license suspended for {hours}?" },
    seize          = { ro = "Ti le voi confisca.", en = "I'll confiscate them." },
    ["seize+fine"] = { ro = "Ti le voi confisca si vei primi o amenda.", en = "I'll confiscate them and give you a ticket." },
    ["fine|seize"] = { ro = "Doresti amenda sau sa ti le confisc?", en = "Do you want a ticket, or should I confiscate them?" },
}
-- raspunsul dupa ce jucatorul a ales (butoanele din statie)
pd.picked = {
    fine  = { ro = "Bine, primesti amenda.", en = "Alright, you get the ticket." },
    lic   = { ro = "Bine, iti suspend permisul {hours}.", en = "Alright, I'm suspending your license for {hours}." },
    seize = { ro = "Bine, ti le confisc.", en = "Alright, I'm confiscating them." },
}
pd.hours = {
    ro = { [1] = "o ora", other = "{n} ore" },
    en = { [1] = "1 hour", other = "{n} hours" },
}

-- ------------------------------------------------------------
-- ALTE TEXTE
-- ------------------------------------------------------------
pd.say = {
    -- somatia pe /m (megafon); regulament: 3 somatii in maxim 5 minute, apoi 30 s de asteptare
    somatie = { ro = "/m {name}, esti urmarit de politie! Trage pe dreapta imediat!",
                en = "/m {name}, police! Pull over immediately!" },
    control = { ro = "Salut {name}! Acesta este un control de rutina.", en = "Hi {name}! This is a routine check." },
    gov = {
        ro = { "{name}, te rog sa parasesti teritoriul guvernamental!", "Risti sa primesti Wanted 2 - 'Patrundere teren guvernamental'." },
        en = { "{name}, please leave the governmental area!", "You risk getting Wanted 2 - 'Governmental area'." },
    },
    -- pe /d (chatul departamentelor)
    nefondat = "/d Ii voi da nefondat lui {name}.",
    custody  = "/d Am in custodie pe {name} (ID {id}), wanted {wanted}, zona {zone}.",
    afk      = "/d {name} este AFK, peste 3 minute ii voi da kill.",
    patrol   = "/d {city}PD, imi permiteti sa patrulez in orasul vostru?",
}
pd.somatie_window = 300   -- secunde: cele 3 somatii trebuie sa intre in acest interval
pd.somatie_wait   = 30    -- secunde de asteptat dupa ultima somatie, inainte de wanted
pd.frisk_valid    = 600   -- secunde cat conteaza un /frisk ca dovada pentru droguri

-- ------------------------------------------------------------
-- ZONE (pozitii din PDHelper V7.5; raza in metri, doar pe orizontala)
-- arrest_points: butonul Arrest se aprinde cand esti aici (nu aresteaza singur)
-- gates: butonul / tasta "Poarta" trimite comanda cand esti langa
-- ------------------------------------------------------------
pd.arrest_points = {
    { x = 1559.17,  y = -1695.34, r = 5, label = "LSPD" },
    { x = 1569.34,  y = -1646.90, r = 5, label = "LSPD" },
    { x = -1589.47, y = 707.37,   r = 5, label = "SFPD" },
    { x = -1681.89, y = 705.94,   r = 5, label = "SFPD" },
    { x = -1719.54, y = 1018.72,  r = 5, label = "SF" },
    { x = 2283.13,  y = 2429.36,  r = 5, label = "LVPD" },
    { x = 2338.13,  y = 2474.54,  r = 5, label = "LVPD" },
    { x = 186.46,   y = 1931.22,  r = 5, label = "Jail" },
}
pd.gates = {
    { x = 1779.03, y = -1581.22, r = 5, cmd = "/opengate 2", label = "Poarta 2" },
    { x = 1768.05, y = -1581.73, r = 5, cmd = "/opengate 1", label = "Poarta 1" },
    { x = 135.20,  y = 1935.06,  r = 5, cmd = "/exit",  label = "NG - iesire" },
    { x = 135.03,  y = 1947.28,  r = 5, cmd = "/enter", label = "NG - intrare" },
    { x = 280.97,  y = 1821.35,  r = 5, cmd = "/exit",  label = "NG - iesire" },
    { x = 290.11,  y = 1821.76,  r = 5, cmd = "/enter", label = "NG - intrare" },
}

-- etichetele din /info (notitele tale despre jucator) cand esti la un departament
pd.player_tags = { "recidivist", "fuge des", "agresiv", "cooperant", "de urmarit" }

-- ------------------------------------------------------------
-- REGULI SCURTE, afisate in statie (rezumat din regulament, nu inlocuieste regulamentul)
-- ------------------------------------------------------------
pd.rules = {
    ro = {
        road = {
            "Nivel 1-3: doar avertisment. 4-7: alege amenda sau permisul. 8+: amenda si permis.",
            "Sub 50 km/h peste limita: doar amenda, de la nivel 4. 1-2 km/h peste limita nu se sanctioneaza.",
            "Controalele de rutina (oprirea vehiculelor) se fac doar cu masina departamentului.",
        },
        wanted = {
            "Neconformare: 3 somatii in maxim 5 minute, apoi minim 30 s de asteptare.",
            "Droguri: doar cu dovada din /frisk sau mesajul de consum langa tine.",
            "Clear doar cu motiv anuntat pe /d; nu dai clear la W5 pentru uciderea unui politist.",
        },
        control = {
            "Echipa rutiera nu da /confiscate pe droguri, arme sau materiale cand face /frisk pentru alcoolemie.",
            "Suspect prins: /cuff, apoi il duci imediat la cea mai apropiata sectie.",
            "Rank sub 4 si suspect W3+ predat: /cuff, apoi anunti pe /d ID-ul, wanted-ul si zona.",
        },
        radar = {
            "Inainte: 3 intrebari pe /d, la minim 10 s, daca zona e libera.",
            "In alt oras: acordul unui rank 4+ de acolo; fara raspuns, dupa 1 minut; refuzat, astepti 5 minute.",
            "Doar parcat regulamentar (niciodata din mers), anunti pe /d cand il pui si cand il reiei, fara AFK cu el pornit.",
        },
    },
    en = {
        road = {
            "Level 1-3: warning only. 4-7: they choose ticket or license. 8+: ticket and license.",
            "Under 50 km/h over the limit: ticket only, from level 4. 1-2 km/h over the limit is not sanctioned.",
            "Routine traffic checks are done only with a department vehicle.",
        },
        wanted = {
            "Disobeying: 3 summons within 5 minutes, then wait at least 30 s.",
            "Drugs: only with evidence from /frisk or the drug-use message near you.",
            "Clear only with a reason announced on /d; never clear a W5 for killing an officer.",
        },
        control = {
            "The road team does not /confiscate drugs, weapons or materials while using /frisk for alcohol.",
            "Suspect caught: /cuff, then take them straight to the nearest station.",
            "Rank under 4 and a W3+ suspect surrenders: /cuff, then announce ID, wanted and zone on /d.",
        },
        radar = {
            "Before: ask 3 times on /d, at least 10 s apart, whether the zone is free.",
            "Another city: approval from a rank 4+ there; no answer, after 1 minute; refused, wait 5 minutes.",
            "Only parked properly (never while driving), announce on /d when you set and resume it, no AFK with it on.",
        },
    },
}

return pd
