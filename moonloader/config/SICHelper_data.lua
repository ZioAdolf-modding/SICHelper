-- ============================================================
-- SICHelper - DATE EDITABILE (preturi, teste, raspunsuri, tutorial)
-- ============================================================
-- Acest fisier este citit de SICHelper.lua la pornire (/reloadall dupa ce il modifici).
-- Aici se schimba textele testelor, raspunsurile, preturile si tutorialul,
-- FARA sa se umble in scriptul principal.
--
-- Reguli:
--   * textele testelor se trimit exact asa cum sunt scrise aici, prefixate cu "/cw "
--   * "ro" / "en" = limba mesajului trimis candidatului
--   * la fly si sail textele depind de oras: LS / SF / LV
--   * "buttons" spune ce texte trimite fiecare buton din /sic, in ordine
--     ex. { {1, 2}, {3, 4}, {5} } => T1 trimite textele 1 si 2, T2 trimite 3 si 4, T3 trimite 5
--   * "delay" (optional, ms) = pauza intre textele trimise de acelasi buton
--   * "answers" = raspunsul asteptat la fiecare intrebare; se afiseaza DOAR instructorului, in chat
--   * preturile: minLevel = nivelul minim; low = min-9, mid = 10-49, high = 50+
-- ============================================================

local data = {}

-- ------------------------------------------------------------
-- PRETURI (topicul de pe forum "Preturi licente")
-- ------------------------------------------------------------
data.prices = {
    flying    = { minLevel = 3, low = 900,  mid = 1800, high = 3600 },
    sailing   = { minLevel = 3, low = 850,  mid = 1700, high = 3400 },
    fishing   = { minLevel = 1, low = 250,  mid = 500,  high = 1000 },
    weapons   = { minLevel = 5, low = 1000, mid = 2000, high = 4000 },
    materials = { minLevel = 3, low = 800,  mid = 1600, high = 3200 },
}

-- ------------------------------------------------------------
-- TESTE (textele sunt cele din SIHelper / procedura factiunii, neschimbate)
-- ------------------------------------------------------------
data.tests = {

    fly = {
        prefix = "T", city = true,
        buttons = { {1, 2}, {3, 4}, {5} },
        texts = {
            LS = {
                en = {
                    "Fly to SF/LV airport.",
                    "To start the engine use /engine.",
                    "If helicopter's HP goes under 950.0 you will fail the test.",
                    "You can verify the HP by typing [/dl].",
                    "Ok, now land and go back to LS Airport.",
                },
                ro = {
                    "Zboara catre aeroportul SF/LV.",
                    "Ca sa pornesti motorul trebuie sa folosesti comanda /engine.",
                    "Daca HP-ul elicopterului scade sub 950.0 esti picat.",
                    "Acesta poti verifica pe [/dl].",
                    "Ok, aterizeaza si intoarce-te inapoi la Airport LS.",
                },
            },
            SF = {
                en = {
                    "Fly to SF/LV/LS airport.",
                    "To start the engine use /engine.",
                    "If helicopter's HP goes under 950.0 you will fail the test.",
                    "You can verify the HP by typing [/dl].",
                    "Ok, now land and go back to SFSI HQ.",
                },
                ro = {
                    "Zboara catre aeroportul SF/LV/LS.",
                    "Ca sa pornesti motorul trebuie sa folosesti comanda /engine.",
                    "Daca HP-ul elicopterului scade sub 950.0 esti picat.",
                    "Acesta poti verifica pe [/dl].",
                    "Ok, aterizeaza si intoarce-te inapoi la SFSI HQ.",
                },
            },
            LV = {
                en = {
                    "Fly to SF/LV/LS airport.",
                    "To start the engine use /engine.",
                    "If helicopter's HP goes under 950.0 you will fail the test.",
                    "You can verify the HP by typing [/dl].",
                    "Ok, now land and go back to LV Abandoned Airport.",
                },
                ro = {
                    "Zboara catre aeroportul SF/LV/LS.",
                    "Ca sa pornesti motorul trebuie sa folosesti comanda /engine.",
                    "Daca HP-ul elicopterului scade sub 950.0 esti picat.",
                    "Acesta poti verifica pe [/dl].",
                    "Ok, aterizeaza si intoarcete inapoi la aeroportul abandonat LV.",
                },
            },
        },
    },

    sail = {
        prefix = "T", city = true,
        channel = "chat",   -- pe barca nu merge /cw ("trebuie sa fii intr-o masina"): textele pleaca in chatul normal
        buttons = { {1, 2}, {3} },
        texts = {
            LS = {
                en = {
                    "Go to Santa Maria Beach.",
                    "If the boat's HP goes below 950.0 you will fail. You can verify this on [/dl].",
                    "Okay, lets go back.",
                },
                ro = {
                    "Du-ma pana la Santa Maria Beach.",
                    "Daca HP-ul barcii scade sub 950.0 esti picat. Poti verifica asta cu [/dl].",
                    "Bun. Sa ne intoarcem.",
                },
            },
            SF = {
                en = {
                    "Go to Bayside Docks.",
                    "If the boat's HP goes below 950.0 you will fail. You can verify this on [/dl].",
                    "Okay, lets go back.",
                },
                ro = {
                    "Du-ma pana la Bayside Docks.",
                    "Daca HP-ul barcii scade sub 950.0 esti picat. Poti verifica asta cu [/dl].",
                    "Bun. Sa ne intoarcem.",
                },
            },
            LV = {
                en = {
                    "Go to Easter Bay Airport.",
                    "If the boat's HP goes below 950.0 you will fail. You can verify this on [/dl].",
                    "Okay, lets go back.",
                },
                ro = {
                    "Du-ma pana la Easter Bay Airport.",
                    "Daca HP-ul barcii scade sub 950.0 esti picat. Poti verifica asta cu [/dl].",
                    "Bun. Sa ne intoarcem.",
                },
            },
        },
    },

    fish = {
        prefix = "Q", city = false,
        buttons = { {1}, {2}, {3}, {4} },
        texts = {
            en = {
                "1. What is the command to start fishing?",
                "2. Where can you do the fishing job?",
                "3. Where you can sell the fishes you cought?",
                "4. What do you get if you do fishing without fishing license?",
            },
            ro = {
                "1. Cu ce comanda pescuiesti?",
                "2. Unde pescuiesti?",
                "3. Unde vinzi pestele?",
                "4. Ce primesti daca vei pescui fara licenta de fishing?",
            },
        },
        -- raspunsul asteptat la fiecare intrebare (Testlog); un raspuns poate fi si o lista de linii
        answers = {
            en = { "/work", "At the fish job.", "24/7", "Wanted 1" },
            ro = { "/work", "Unde gasesti job-ul fish.", "24/7", "Wanted 1" },
        },
    },

    weap = {
        prefix = "Q", city = false,
        buttons = { {1}, {2}, {3}, {4}, {5} },
        texts = {
            en = {
                "1. Give me the name of 5 weapons in GTA San Andreas",
                "2. What is the command to view safe zones?",
                "3. What you cannot do in safezones?",
                "4. State the full command used to purchase a weapon.",
                "5. Where can you buy the weapons?",
            },
            ro = {
                "1. Spune mi 5 arme din GTA San Andreas",
                "2. Care este comanda pentru a vedea zonele sigure?",
                "3. Ce nu ai voie sa faci in zonele sigure?",
                "4. Precizeaza comanda completa cu care achizitionezi o arma.",
                "5. De unde poti cumpara arme?",
            },
        },
        answers = {
            en = {
                -- lista de arme din GTA San Andreas (oricare 5 sunt bune), pe doua linii
                { "Pistols: Colt 45, Silenced Pistol, Desert Eagle | Shotgun, Sawn-off, Combat Shotgun | SMG: Uzi, Tec-9, MP5",
                  "AK-47, M4, Country Rifle, Sniper Rifle | RPG, Minigun, Flamethrower | Grenade, Molotov | Knife, Katana, Bat, Chainsaw" },
                "/safezones",
                "Drive-by, Deathmatch or to sell guns.",
                "/buygun <weapon> <ammo>",
                "Gun Shop.",
            },
            ro = {
                { "Pistoale: Colt 45, Silenced Pistol, Desert Eagle | Shotgun, Sawn-off, Combat Shotgun | SMG: Uzi, Tec-9, MP5",
                  "AK-47, M4, Country Rifle, Sniper Rifle | RPG, Minigun, Flamethrower | Grenade, Molotov | Knife, Katana, Bat, Chainsaw" },
                "/safezones",
                "Drive-by, Deathmatch sau sa vinzi arme.",
                "/buygun <weapon> <gloante>",
                "Gun Shop.",
            },
        },
    },

    mat = {
        prefix = "Q", city = false,
        buttons = { {1}, {2}, {3}, {4} },
        texts = {
            en = {
                "1. Which command do you use to get materials from material deposit?",
                "2. Which command do you use to sell weapons?",
                "3. Where you are cannot sell your weapons?.",
                "4. Tell me 5 Safezones",
            },
            ro = {
                "1. Cu ce comanda Cumperi Materiale ?",
                "2. Cu ce comanda Vinzi o Arma ?",
                "3. Unde nu ai voie sa Vinzi Arme ?",
                "4. Spune mi 5 safezone.",
            },
        },
        answers = {
            en = { "/getmaterials", "/sellgun", "In Safezone.", "Any safezone from [/safezones]." },
            ro = { "/getmaterials", "/sellgun", "In Safezone.", "Orice safezone din [/safezones]." },
        },
    },
}

-- ------------------------------------------------------------
-- SCREENSHOT-URI: ce sufix primeste fisierul, dupa ultima linie recunoscuta din chat
-- Cand apesi butonul de screenshot din /sic, helperul citeste chatul de jos in sus
-- si se opreste la PRIMA linie care contine unul dintre textele de mai jos.
-- Sufixul acelei intrari se pune la finalul numelui: SIC_Nume_Licenta_data_fannounce.png
-- "find" = bucati de text (nu conteaza literele mari/mici); adauga aici textele noi cand le afli.
-- ------------------------------------------------------------
data.screenshots = {
    { suffix = "fannounce",  find = { "is with me for" } },
    { suffix = "givelicense", find = { "acordat licenta de", "acordat permisul de port-arma", "you gave a" } },
    { suffix = "requestlicenses", find = { "i-ai solicitat licentele" } },
    { suffix = "id",          find = { "| level:", "| nivel:" } },
    { suffix = "needlicense", find = { "/accept needlicense" } },
    { suffix = "sxwas",       find = { "acceptat cineva pe", "has anyone accepted" } },
    -- de adaugat cand stim textul exact de pe server: startlesson, stoplesson, intrebarile trimise pe /cw
}

-- ------------------------------------------------------------
-- ERORI DE LA SERVER aratate ca notificare pe ecran (rosu, 6 secunde)
-- Orice linie din chat care contine unul dintre textele de mai jos (litere mari/mici nu conteaza).
-- Adauga aici textele exacte pe masura ce le afli.
-- ------------------------------------------------------------
data.notify_errors = {
    "nu exista cereri", "nu sunt cereri", "nu exista nicio cerere", "nu ai nicio cerere",
    "there are no requests", "no pending requests",
    "nu esti la datorie", "you are not on duty",
    "nu are nevoie de licent", "already has", "detine deja",
}

-- ------------------------------------------------------------
-- "CEREREA A FOST PRELUATA DE ALTCINEVA": liniile serverului care anunta ca un alt instructor a acceptat
-- un /needlicense. Pattern-uri Lua cu doua capturi: (1) instructorul, (2) jucatorul care ceruse.
-- Daca formatul serverului e altul, pune-l aici (helperul noteaza in SICHelper_trace.txt liniile cu "accept").
-- ------------------------------------------------------------
-- comenzile trimise inainte de /accept needlicense, cand ai un checkpoint activ (feature "Sterge
-- checkpoint-ul la accept"). Scoate una daca serverul raspunde cu eroare la ea.
data.clear_checkpoint = { "/cancel find", "/killcp" }

-- ------------------------------------------------------------
-- RANGURILE FACTIUNILOR (numarul din /id -> numele rangului)
-- Serverul numeroteaza de la 7 (liderul) pana la 0; rangul 0 e cel care trebuie sa dea
-- testul ca sa intre in factiune. Factiunile care nu au nume proprii de ranguri
-- (PD / FBI / National Guard, primaria, mafiile si gangurile) folosesc "Rang N".
-- Prefixul orasului (LS / SF / LV) vine din numele factiunii, nu de aici.
-- ------------------------------------------------------------
data.rank_generic = "Rang %d"
data.rank_leader  = "Rang 7 (Lider)"
data.rank_zero    = "Rang 0 (da testul de intrare)"

-- ------------------------------------------------------------
-- ETICHETELE din fereastra /info ("notitele mele despre el"). Schimba-le cum vrei:
-- apar ca butoane, iar ce bifezi se salveaza in config/SICHelper_players.lua, pe nume de jucator.
-- ------------------------------------------------------------
data.player_tags = { "posthunter", "baiat de treaba", "cere des", "atent", "de evitat" }

-- ------------------------------------------------------------
-- FACTIUNEA ALIATA: cui dai banii inapoi pe licente.
-- Cheia de sus e factiunea ta, iar inauntru orasul (la factiunile care au orase).
-- Gol = nu ai aliat. Aliatul se poate alege si din /sih -> Features, fara sa umbli aici.
-- Exemplu: SF School Instructors sunt aliati cu Paramedics, deci banii pe licenta se intorc.
-- ------------------------------------------------------------
data.allies = {
    si = { SF = "paramedics", LS = "", LV = "" },
}

data.ranks = {
    si = {
        [7] = "Boss", [6] = "Under Boss", [5] = "Manager", [4] = "Supervisor",
        [3] = "Senior Instructor", [2] = "Instructor", [1] = "Trainee",
    },
    taxi = {
        [7] = "Company Owner", [6] = "Company Manager", [5] = "Shift Supervisor",
        [4] = "Dispatcher", [3] = "Cabbie", [2] = "Taxi Rookie", [1] = "Trainee",
    },
    paramedics = {
        [7] = "Chief Paramedic", [6] = "Assistant Chief Paramedic", [5] = "Paramedic Field Chief",
        [4] = "Paramedic Ambulance Commander", [3] = "Paramedic in Charge", [2] = "Paramedic",
        [1] = "Candidate Paramedic",
    },
    news = {
        [7] = "Network Director", [6] = "Network Producer", [5] = "Network Editor",
        [4] = "Network Anchor", [3] = "Local Editor", [2] = "Local Reporter", [1] = "Intern",
    },
    tow = {
        [7] = "Tow Company Owner", [6] = "Under Boss", [5] = "Manager", [4] = "Supervisor",
        [3] = "Senior Mechanic", [2] = "Mechanic", [1] = "Trainee",
    },
}

-- liniile prin care serverul iti ofera o licenta (pentru /giveme: helperul raspunde cu /accept license)
data.license_offered = {
    "oferit Licenta de", "oferit Permisul de port%-arma", "offered you a",
}

data.accepted_by = {
    -- formatul real al serverului: "** LV Manager [PW]slytherin a acceptat solicitarea de instructor a lui Nume."
    "(%S+) a acceptat solicitarea de instructor a lui (.+)%.",
    "(%S+) accepted the instructor request of (.+)%.",
    "^%*?%s*(%S+) a acceptat cererea lui (%S+)",
    "^%*?%s*(%S+) a preluat cererea lui (%S+)",
    "^%*?%s*(%S+) accepted (%S+)'s request",
    "^%*?%s*(%S+) has accepted the request of (%S+)",
}

-- ------------------------------------------------------------
-- MESAJE CATRE CANDIDAT (limba = "Limba mesajelor" din /sih)
-- %s = numele jucatorului. Se trimit cu:
--   sms   automat, pe /sms, dupa un /accept needlicense reusit (feature "SMS la accept")
--   salut /salut <id>  pe /w, cand va vedeti
--   pa    /pa <id>     pe /w, la despartire
--   need  /need <id>   pe /w, ca sa intrebi un jucator daca are nevoie de licente
--   ok    /ok <id>     pe /w, la finalul testului, inainte de /givelicense
-- ------------------------------------------------------------
data.messages = {
    ro = {
        sms   = "Salut! Ajung imediat la tine. Daca vrei sa ne vedem intr-un loc anume, spune-mi!",
        salut = "Salut, %s! Arata-mi te rog licentele si spune-mi de ce ai nevoie.",
        pa    = "Mersi! Ne vedem pe joc, %s!",
        need  = "Salut, %s! Ai nevoie de renew sau ai licentele expirate?",
        ok    = "Felicitari, %s, ai trecut! Iti dau licenta acum.",
    },
    en = {
        sms   = "Hi! I'm on my way to you. If you'd rather meet somewhere specific, let me know!",
        salut = "Hi, %s! Please show me your licenses and tell me what you need.",
        pa    = "Thanks! See you around, %s!",
        need  = "Hi, %s! Do you need a renew or are your licenses expired?",
        ok    = "Congratulations, %s, you passed! Giving you the license now.",
    },
}

-- ------------------------------------------------------------
-- TUTORIAL pentru instructori (afisat in /sih -> Tutorial)
-- fiecare sectiune: title + lines; liniile care incep cu "-" sunt pasi
-- ------------------------------------------------------------
data.tutorial = {
    ro = {
        {
            title = "Cum decurge o licenta",
            lines = {
                "- Jucatorul da /needlicense; il accepti din /sic sau cu bind-ul. In acel moment devine candidatul tau si primeste automat un /sms ca ajungi la el.",
                "- Cand va vedeti: /salut (pe /w, ii cere licentele). La final: /pa. Pe strada, /need <id> intreaba pe cineva daca are nevoie de licente.",
                "- /accept needlicense <id> (bind sau /sic), apoi /requestlicenses <id> ca sa vezi ce licente vrea.",
                "- Anunta pe /f cu /withme <id> <licente>: helperul da /id (screenshot!) si scrie mesajul pe /f.",
                "- Nivel 50+: nu se da test, doar /givelicense; jucatorul plateste integral si conteaza la raport.",
                "- Nivel sub 50: faci testul din /sic; la final Give license (a trecut) sau Failed / stoplesson (a picat).",
                "- Adminii nu platesc licente, nu dau teste si NU conteaza la raportul de activitate.",
            },
        },
        {
            title = "Flying (nivel minim 3)",
            lines = {
                "SF: du candidatul la SFSI HQ. LS: la Los Santos Airport. LV: la Las Venturas Abandoned Airport.",
                "- Ii ceri sa zboare la unul dintre aeroporturi (LV Abandoned, LV, LS sau SF - nu cel de plecare).",
                "- Ii spui sa aterizeze si sa opreasca motorul.",
                "- Dupa oprire, decoleaza si se intoarce la punctul de plecare, unde parcheaza cat mai bine.",
                "- Sub 950 HP la elicopter = picat. Altfel a trecut.",
                "Preturi: 3-9 $900 | 10-49 $1.800 | 50+ $3.600",
            },
        },
        {
            title = "Sailing (nivel minim 3)",
            lines = {
                "SF: plecare din West Docks (San Fierro) -> Bayside Docks (stanga sus pe harta) -> inapoi.",
                "LS: plecare din Playa Del Seville -> Santa Maria Beach (langa far) -> inapoi.",
                "LV: plecare din Red County -> Easter Bay Airport (fostul HQ National Guard) -> inapoi.",
                "- Sub 950 HP la barca = picat. Altfel a trecut.",
                "Preturi: 3-9 $850 | 10-49 $1.700 | 50+ $3.400",
            },
        },
        {
            title = "Fishing (nivel minim 1)",
            lines = {
                "- Pui cele 4 intrebari din /sic (Q1-Q4).",
                "- Daca nu raspunde sau greseste una, a picat. Altfel a trecut.",
                "Preturi: 1-9 $250 | 10-49 $500 | 50+ $1.000",
            },
        },
        {
            title = "Materials (nivel minim 3)",
            lines = {
                "- Pui cele 4 intrebari din /sic (Q1-Q4).",
                "- Daca nu raspunde sau greseste una, a picat. Altfel a trecut.",
                "Preturi: 3-9 $800 | 10-49 $1.600 | 50+ $3.200",
            },
        },
        {
            title = "Weapons (nivel minim 5)",
            lines = {
                "- Pui cele 5 intrebari din /sic (Q1-Q5).",
                "- Daca nu raspunde sau greseste una, a picat. Altfel a trecut.",
                "Preturi: 5-9 $1.000 | 10-49 $2.000 | 50+ $4.000",
            },
        },
    },
    en = {
        {
            title = "How a license goes",
            lines = {
                "- The player types /needlicense; you accept from /sic or with the bind. At that moment they become your candidate and automatically get a /sms that you are on your way.",
                "- When you meet: /salut (on /w, asks for the licenses). At the end: /pa. On the street, /need <id> asks someone whether they need licenses.",
                "- /accept needlicense <id> (bind or /sic), then /requestlicenses <id> to see which licenses they want.",
                "- Announce on /f with /withme <id> <licenses>: the helper runs /id (screenshot!) and writes the /f message.",
                "- Level 50+: no test, just /givelicense; the player pays in full and it counts for your report.",
                "- Below 50: run the test from /sic; at the end Give license (passed) or Failed / stoplesson (failed).",
                "- Admins do not pay, do not take tests and do NOT count for the activity report.",
            },
        },
        {
            title = "Flying (min level 3)",
            lines = {
                "SF: take the client to SFSI HQ. LS: Los Santos Airport. LV: Las Venturas Abandoned Airport.",
                "- Ask them to fly to one of the airports (LV Abandoned, LV, LS or SF - not the starting one).",
                "- Tell them to land and stop the engine.",
                "- Once stopped, take off and fly back to the starting point and park sensibly.",
                "- Under 950 HP on the helicopter = failed. Otherwise passed.",
                "Prices: 3-9 $900 | 10-49 $1.800 | 50+ $3.600",
            },
        },
        {
            title = "Sailing (min level 3)",
            lines = {
                "SF: start at West Docks (San Fierro) -> Bayside Docks (top left of the map) -> back.",
                "LS: start at Playa Del Seville -> Santa Maria Beach (near the lighthouse) -> back.",
                "LV: start at Red County -> Easter Bay Airport (former National Guard HQ) -> back.",
                "- Under 950 HP on the boat = failed. Otherwise passed.",
                "Prices: 3-9 $850 | 10-49 $1.700 | 50+ $3.400",
            },
        },
        {
            title = "Fishing (min level 1)",
            lines = {
                "- Ask the 4 questions from /sic (Q1-Q4).",
                "- If they fail to reply or get one wrong, they fail. Otherwise they pass.",
                "Prices: 1-9 $250 | 10-49 $500 | 50+ $1.000",
            },
        },
        {
            title = "Materials (min level 3)",
            lines = {
                "- Ask the 4 questions from /sic (Q1-Q4).",
                "- If they fail to reply or get one wrong, they fail. Otherwise they pass.",
                "Prices: 3-9 $800 | 10-49 $1.600 | 50+ $3.200",
            },
        },
        {
            title = "Weapons (min level 5)",
            lines = {
                "- Ask the 5 questions from /sic (Q1-Q5).",
                "- If they fail to reply or get one wrong, they fail. Otherwise they pass.",
                "Prices: 5-9 $1.000 | 10-49 $2.000 | 50+ $4.000",
            },
        },
    },
}

return data
