-- ============================================================
-- SICHelper - CMD helper pentru School Instructors si departamente (B-Zone RPG / SA:MP)
-- Copyright (C) 2026 ZioAdolf (Discord: vlandrewz)
--
-- Sursa oficiala: https://github.com/ZioAdolf-modding/SICHelper
-- Orice copie de altundeva nu e oficiala.
--
-- Programul e liber: il poti redistribui si/sau modifica in termenii licentei
-- GNU General Public License, versiunea 3 sau (la alegerea ta) oricare versiune
-- ulterioara, publicata de Free Software Foundation. Vine FARA NICIO GARANTIE.
-- Vezi fisierul LICENSE sau <https://www.gnu.org/licenses/>.
--
-- Numele "SICHelper" si logo-ul ZA nu sunt acoperite de licenta codului (vezi TRADEMARK.md).
-- Comenzile scurte si textele oficiale ale testelor provin din SIHelper 1.2.2 by AdeM.
-- ============================================================

script_name("SICHelper")
local VERSION = "1.6.0-beta"
script_version(VERSION)
script_description("CMD Helper B-Zone - School Instructors (/sic) si departamente PD / FBI / NG (/pdc), /sih, bind-uri")

-- ============================================================
-- REQUIRES
-- ============================================================
local imgui    = require "lib.mimgui"
local encoding = require "lib.encoding"
local inicfg   = require "inicfg"
local vkeys    = require "vkeys"
local sampev   = require "samp.events"
local ffi      = require "ffi"
local bit      = require "bit"
local fa       = require "fAwesome6_solid"

encoding.default = "CP1251"
local u8 = encoding.UTF8
local new = imgui.new

-- imgui.Text* sunt in stil printf: un "%" din text ar disparea, asa ca il dublam
local function esc(s) return (tostring(s):gsub("%%", "%%%%")) end
local function TX(s)       imgui.Text(esc(s)) end
local function TC(col, s)  imgui.TextColored(col, esc(s)) end
local function TW(s)       imgui.TextWrapped(esc(s)) end
local function TIP(s)      imgui.SetTooltip(esc(s)) end

-- ============================================================
-- CONSTANTE
-- ============================================================
-- constantele stau intr-o singura tabela: Lua permite cel mult 200 de variabile locale intr-un fisier
local K = {}

-- Fontul de iconite: unele modpack-uri vin cu o versiune mai veche a fisierului
-- lib/fAwesome6_solid.lua, in care cautarea unui nume inexistent intra in recursie infinita
-- (__index face "return t[i]") si omoara scriptul inainte sa apuce sa porneasca.
-- Trecem fiecare citire prin pcall si o retinem: ce lipseste devine text gol, iar helperul
-- merge mai departe, doar fara acea iconita.
K.faLib = fa
fa = setmetatable({}, {
    __index = function(t, key)
        local ok, v = pcall(function() return K.faLib[key] end)
        if not ok or v == nil then v = "" end
        rawset(t, key, v)
        return v
    end,
})
K.CFG_FILE         = "SIC_Helper.ini"
K.MAX_CUSTOM_BINDS = 12
K.WITHME_TIMEOUT   = 8       -- secunde de asteptat raspunsul de la /id
K.NEAR_DISTANCE    = 10.0    -- metri: cat de aproape trebuie sa fie "cel mai apropiat jucator"
K.FADE_SPEED       = 7.0     -- viteza tranzitiilor ferestrelor (1/secunde)
K.MAX_BONUS_PERCENT = 150    -- bonusul maxim de bani pe server
K.FACTION_ICON_SIZE = 40     -- iconita din insigna factiunii (/sih General), px
K.FACTION_BADGE = 72         -- diametrul insignei factiunii, px
K.NOTES_FILE   = getWorkingDirectory() .. "/config/SICHelper_notes.lua"   -- notitele din /notepad
K.NOTE_MAX     = 256         -- lungimea maxima a unei notite
K.NOTE_CHAT    = 128         -- cat intra pe o linie de chat a serverului; peste, se taie
K.NOTES_FOLD_W = 146         -- latimea coloanei cu foldere din /notepad, px
K.ALLY_DELAY   = 2200        -- ms de asteptat inainte de /pay (serverul cere pauza intre comenzi)
K.ALLY_MAX_AGE = 180         -- secunde cat mai asteapta o plata neexpediata (fara /pin)
K.ALLY_WARN    = 20          -- secunde intre doua atentionari "da /pin"

-- valori cu semnificatie fixa: in cod se folosesc DOAR aceste nume, nu cifre / stringuri goale
K.LANG_RO, K.LANG_EN                                 = "ro", "en"
K.CITY_LS, K.CITY_SF, K.CITY_LV                        = "LS", "SF", "LV"
K.TARGET_LAST, K.TARGET_NEAR, K.TARGET_ASK, K.TARGET_NONE = "last", "near", "ask", "none"
K.NOTIFY_ANY, K.NOTIFY_LOW, K.NOTIFY_HIGH             = "any", "low", "high"   -- filtrul notificarilor
K.NOTIFY_SECONDS   = 6       -- cat ramane pe ecran o notificare (5-7 s)
K.THEORY_PAGESIZE  = 30      -- /pagesize la lectiile teoretice (limita serverului: 10-30)
K.PAGESIZE_MIN, K.PAGESIZE_MAX = 10, 30
K.RR_STEP_DELAY    = 1100    -- ms intre comenzile de la repair / refill (serverul are cooldown)

K.LIC_FLYING, K.LIC_SAILING, K.LIC_FISHING, K.LIC_WEAPONS, K.LIC_MATERIALS, K.LIC_ALL =
      "flying", "sailing", "fishing", "weapons", "materials", "all"

-- ============================================================
-- DATE EDITABILE: preturi, texte de test, raspunsuri, tutorial
-- stau in moonloader/config/SICHelper_data.lua, ca sa poata fi inlocuite fara a umbla in script
-- ============================================================
K.DATA_FILE = "config\\SICHelper_data.lua"
local Data, dataError = nil, nil
do
    local ok, result = pcall(dofile, getWorkingDirectory() .. "\\" .. K.DATA_FILE)
    if ok and type(result) == "table" then
        Data = result
    else
        Data = { prices = {}, tests = {}, tutorial = {} }
        dataError = tostring(result)
    end
end

-- tabela centrala a licentelor:
--   id       identificatorul folosit peste tot in cod
--   number   cifra tastata la /withme
--   server   cuvantul acceptat de server la /givelicense (din SIHelper - DE VERIFICAT)
--   label    numele afisat in interfata
--   short    eticheta scurta pentru butoane mici
--   icon     iconita din tab-ul /sic
--   minLevel / prices  din fisierul de date (min-9 / 10-49 / 50+)
local Licenses = {
    list = {
        { id = K.LIC_FLYING,    number = 1, server = "Flying",    label = "Flying",    short = "Fly",  icon = fa.HELICOPTER    },
        { id = K.LIC_SAILING,   number = 2, server = "Sailing",   label = "Sailing",   short = "Sail", icon = fa.SHIP          },
        { id = K.LIC_FISHING,   number = 3, server = "Fishing",   label = "Fishing",   short = "Fish", icon = fa.FISH          },
        { id = K.LIC_WEAPONS,   number = 4, server = "Weapon",    label = "Weapons",   short = "Weap", icon = fa.GUN           },
        { id = K.LIC_MATERIALS, number = 5, server = "Materials", label = "Materials", short = "Mat",  icon = fa.BOXES_STACKED },
        { id = K.LIC_ALL,       number = 6, server = nil,         label = "All",       short = "All",  icon = fa.CROWN         },
    },
    byId = {},
    byNumber = {},
    real = {},   -- doar licentele adevarate (fara "All"), in ordinea numerelor
}
for _, lic in ipairs(Licenses.list) do
    local p = Data.prices and Data.prices[lic.id]
    lic.minLevel = p and p.minLevel or 1
    lic.prices   = p and { low = p.low, mid = p.mid, high = p.high } or nil
    Licenses.byId[lic.id] = lic
    Licenses.byNumber[lic.number] = lic
    if lic.id ~= K.LIC_ALL then table.insert(Licenses.real, lic) end
end

-- testele din fereastra /sic, in ordinea tab-urilor; continutul vine din fisierul de date
--   city     textul depinde de orasul ales (LS / SF / LV)
--   prefix   "T" = task (fly / sail), "Q" = intrebare (fish / weap / mat)
--   channel  "cw" (implicit) = textele pleaca pe /cw; "chat" = in chatul normal (Sailing: pe barca nu merge /cw)
--   buttons  ce texte trimite fiecare buton (un buton poate trimite mai multe, esalonat)
--   texts    [city][lang][n] sau [lang][n]
--   answers  [lang][n], afisate doar instructorului
local TEST_ORDER = {
    { id = "fly",  licId = K.LIC_FLYING    },
    { id = "sail", licId = K.LIC_SAILING   },
    { id = "fish", licId = K.LIC_FISHING   },
    { id = "weap", licId = K.LIC_WEAPONS   },
    { id = "mat",  licId = K.LIC_MATERIALS },
}
local Tests = {}
for _, t in ipairs(TEST_ORDER) do
    local d = Data.tests and Data.tests[t.id]
    if d then
        table.insert(Tests, {
            id = t.id, licId = t.licId,
            city = d.city == true, prefix = d.prefix or "T",
            channel = d.channel or "cw",   -- "cw" = /cw (in vehicul), "chat" = chatul normal (ex. Sailing, pe barca)
            buttons = d.buttons or {}, texts = d.texts or {}, answers = d.answers,
            delay = tonumber(d.delay),   -- pauza (ms) intre textele aceluiasi buton; nil = cea din setari
        })
    end
end
K.TAB_LEVEL50 = "lvl50"   -- tab-ul special pentru level 50+

-- pattern-uri pentru mesajele serverului (aceleasi ca in SIHelper, verificate in joc)
local SERVER = {
    ACCEPT_SERVICE = "/accept%s+(%a+)%s+(%d+)",   -- "... /accept needlicense 123 ..."
    LEVEL_EN       = "| Level:%s*(%d+)",           -- linia din raspunsul la /id
    LEVEL_RO       = "| Nivel:%s*(%d+)",
    -- starea de duty a instructorului (mesajele serverului la /duty, ca in SIHelper)
    DUTY_ON  = { "You are now on duty as instructor",  "Esti acum la datorie ca instructor" },
    DUTY_OFF = { "You are now off duty as instructor", "Nu mai esti la datorie ca instructor",
                 "Server closed the connection", "Lost connection to the server" },
    NOT_ON_DUTY = { "You are not on duty", "Nu esti la datorie" },
    -- schimbarea jobului (pentru repair / refill), ca in SIHelper
    JOB_CHANGED  = { "You are now a (.+)", "Ai devenit (.+)" },
    JOB_MECHANIC = { "Car Mechanic", "Mecanic" },
    NO_SWITCHJOB = { "You are not in a faction which", "Nu esti intr" },
    -- confirmarea ca jucatorul a acceptat licenta (dupa /givelicense)
    GAVE = {
        "You gave a %S+ License to (.+)",
        "acordat Licenta de %S+ lui (.+)",
        "acordat Permisul de port%-arma lui (.+)",
    },
}
K.GIVE_TIMEOUT = 60   -- secunde de asteptat acceptarea unei licente inainte de a renunta la lant
K.SMS_DELAY = 3.2     -- secunde dupa /accept needlicense pana pleaca SMS-ul (serverul cere 3 s intre comenzi; si timp pentru un eventual refuz)
K.CUSTOM_MIN_H = 180  -- inaltimea minima (px) a panoului de bind-uri personalizate din /sih -> Bind-uri
K.CHAT_MAX = 143      -- caractere maxime pe o linie de chat SA:MP (bufferul clientului e de 144)
K.DOCK_SLOT = 46      -- marimea unui slot din bara de iconite (px)
K.DOCK_ICON = 22      -- iconita din slot (px)
K.LEGEND_BASE_W = 340   -- latimea de referinta a legendei bind-urilor (px la 1080p); alta latime = alta scara
K.UI_REF_HEIGHT = 1080  -- rezolutia verticala de referinta: la ea interfata are marimea "1:1"
K.DOCK_EDGE = 70      -- la mai putin de atatia px de marginea de sus / jos, bara de iconite devine orizontala
K.NEED_MAX_AGE  = 300  -- secunde: un /needlicense sosit cat jocul era in bara se mai arata la revenire doar daca e mai nou de atat
K.NEED_MAX_SHOW = 4    -- cate cereri amanate se arata cel mult la revenire (raman cele mai noi)
K.NEED_ID_TIMEOUT = 4  -- secunde de asteptat raspunsul la /id-ul automat de la /needlicense
K.CP_REACHED  = 8      -- metri: sub atat consideram checkpoint-ul atins si il scoatem din legenda
K.CP_MAX_AGE  = 900    -- secunde: un checkpoint mai vechi de atat dispare singur din legenda
K.NEED_TAKEN_AGE = 60         -- secunde: o cerere preluata intre timp de alt instructor se mai arata la revenire doar atat
K.NOTIFY_TAKEN_SECONDS = 8    -- cat mai ramane pe ecran un cartonas dupa ce cererea a fost preluata de altcineva
K.HOVER_TIP_DELAY = 1.5   -- secunde de stat cu cursorul pe un buton T/Q pana apare textul pe care il trimite

-- mesajele trimise pe /f si /sx
local MSG = {
    withme        = "%s (%d) is with me for %s.",
    withme_lvl50  = " He is level 50+.",
    sxwas = {
        [K.LANG_RO] = "L-a acceptat cineva pe %s (%d)?",
        [K.LANG_EN] = "Has anyone accepted %s (%d)?",
    },
}

-- paleta de chat: discreta, text alb, numele jucatorilor in verdele factiunii
local COLOR = {
    SI    = "{10FF78}",   -- verdele School Instructors: prefixul [SIC] si numele jucatorilor
    TEXT  = "{FFFFFF}",   -- textul obisnuit
    DIM   = "{B4BCC4}",   -- explicatii secundare
    MONEY = "{F2C56B}",   -- sume de bani
    CMD   = "{9ED0FF}",   -- comenzi in mesajele de utilizare
    ERR   = "{FF5050}",   -- erori: rosu clar, se vad imediat
}

local TAG = {
    PREFIX = COLOR.SI .. "[SIC] " .. COLOR.TEXT,
    ERROR  = COLOR.SI .. "[SIC] " .. COLOR.ERR,
    USAGE  = COLOR.SI .. "[SIC] " .. COLOR.CMD,
}

-- "Nume (12)" in culoarea factiunii, apoi inapoi la alb
local function nameTag(id, name)
    return COLOR.SI .. tostring(name or "?") .. " (" .. tostring(id) .. ")" .. COLOR.TEXT
end

-- ============================================================
-- CONFIG IMPLICIT
-- ============================================================
local defaultConfig = {
    main = {
        uiLang       = K.LANG_RO,   -- limba interfetei helperului
        procLang     = K.LANG_RO,   -- limba mesajelor trimise candidatului / pe /sx
        faction      = K.CITY_SF,   -- orasul: LS / SF / LV (pentru factiunile care au)
        factionId    = "si",        -- factiunea mea (id din FACTIONS)
        queueDelay   = 700,       -- ms intre doua mesaje trimise automat
        bonusPercent = 0,         -- bonus la bani (eveniment, raport activitate), in procente, din /stats
        autoDl       = 1,         -- trimite si /dl pentru instructor cand un text de test contine /dl
        showAnswers  = 1,         -- afiseaza (doar tie) raspunsul la intrebare cand o trimiti
        pagesize     = 0,         -- randuri in chat (/pagesize 1-30); 0 = nu se atinge
        autoStoplesson = 1,       -- /stoplesson imediat ce jucatorul a acceptat licenta (sub nivel 50)
        notifyOn     = 1,         -- notificare pe ecran la /needlicense
        subtotalAR   = 1,         -- subtotalul din /withme include bonusul factiunii (AR)
        dutyWindows  = 0,         -- la /duty se deschid ferestrele alese mai jos (si se inchid la iesire)
        dutyWinSic   = 1,
        dutyWinWithme = 0,
        dutyWinReport = 0,
        notifyLevel  = K.NOTIFY_ANY, -- pentru ce nivel: any / low (1-49) / high (50+)
        theme        = "si",      -- tema = culoarea factiunii (vezi FACTION_THEMES)
        sicPosX      = -1,        -- -1 = pozitie implicita (dreapta jos)
        sicPosY      = -1,
        sicW         = -1,        -- -1 = marimea implicita
        sicH         = -1,
        wmPosX       = -1,        -- fereastra withme: -1 = centrul ecranului
        wmPosY       = -1,
        wmW          = -1,
        wmH          = -1,
        hudReportX   = -1,        -- HUD raport (on duty): -1 = pozitie implicita, dreapta sus
        hudReportY   = -1,
        hudCheckX    = -1,        -- HUD checklist dovezi
        hudCheckY    = -1,
        -- feature-uri (tab-ul Features din /sih), 1 = pornit
        theoryPagesize = 1,       -- /pagesize 30 la Start lesson pe testele cu intrebari
        chain50      = 1,         -- la 50+: licentele una cate una, dupa fiecare acceptare
        dutyCheck    = 1,         -- refuza give / accept daca nu esti la datorie
        hpMonitor    = 1,         -- HP-ul vehiculului candidatului, live, la Flying / Sailing
        autoCandidate = 1,        -- candidatul se retine singur cand acceptam un /needlicense
        autoSms       = 1,        -- /sms de confirmare dupa /accept needlicense
        clearCp       = 1,         -- sterge checkpoint-ul activ inainte de /accept needlicense
        needMode      = 0,        -- diagnostic /sicneed: 0 tot, 1 doar chat, 2 nimic la /needlicense
        sicLastSent  = 1,         -- linia cu ultimul mesaj trimis, jos in /sic
        dock         = 1,         -- bara de iconite pe ecran (/sic, /withme, /raport, /sih)
        dockOrient   = "auto",    -- orientarea barei: auto / vert / horiz
        sec_lang     = 0,         -- sectiunile din /sih General: 1 = deschisa
        sec_faction  = 1,
        sec_keys     = 0,
        sec_window   = 0,
        sec_cmds     = 0,
        sec_notes    = 0,
        wizardDone   = 0,         -- ghidul de pornire a fost parcurs (sau sarit)
        verCheck     = 1,         -- verifica la pornire daca exista o versiune mai noua
        allyPay      = 0,         -- da banii inapoi membrilor factiunii aliate, cu /pay
        allyId       = "",        -- factiunea aliata aleasa manual; gol = cea din fisierul de date
        bindLegend   = 1,         -- legenda bind-urilor pe ecran (dreapta)
        hideSrvDist  = 1,         -- ascunde mesajul de distanta al serverului cat legenda o arata
        fadeAnim     = 1,         -- tranzitii cu fade la ferestre
        shortsOn     = 0,         -- scurtaturile generale ale lui AdeM (/m, /sj, /ra ...)
        shotRename   = 1,         -- redenumeste screenshot-urile: SIC_Nume_Licenta_data.png
        fvrOn        = 1,         -- FVR: anunt pe /f si /sx, numaratoare, /fvr
        checklist    = 1,         -- panoul cu pasii licentei si screenshot-urile facute
        reportWindow = 1,         -- /raport in fereastra helperului, in locul dialogului serverului
        dutyHud      = 1,         -- HUD mic cu raportul cat esti on duty
    },
    report = {
        daysLeft = -1, progDone = -1, progTotal = -1, bonusDone = -1, bonusTotal = -1, rankupDays = -1, savedAt = 0,
    },
    fvr = {
        startText = "FVR in 10 seconds !!",
        sxText    = "FVR in 10 seconds",
        endText   = "FVR Executed successfully !",
        seconds   = 10,
    },
    binds = {
        -- key = numele tastei ("F1", "None"), on = 1/0, target = last/near/ask/none
        acc_key = "None",  acc_on = 1,  acc_target = K.TARGET_LAST,
        rl_key  = "None",  rl_on  = 1,  rl_target  = K.TARGET_LAST,
        sl_key  = "None",  sl_on  = 0,  sl_target  = K.TARGET_LAST,
        wm_key  = "None",  wm_on  = 0,  wm_target  = K.TARGET_LAST,
        sx_key  = "None",  sx_on  = 0,  sx_target  = K.TARGET_NEAR,
        rr_key  = "None",  rr_on  = 1,  rr_target  = K.TARGET_NONE,
        fvr_key = "None",  fvr_on = 1,  fvr_target = K.TARGET_NONE,
        notif_key = "None", notif_on = 1, notif_target = K.TARGET_NONE,
        sic_key = "None",  sic_on = 1,  sic_target = K.TARGET_NONE,
        sih_key = "None",  sih_on = 0,  sih_target = K.TARGET_NONE,
        note_key = "None", note_on = 1, note_target = K.TARGET_NONE,
        info_key = "None", info_on = 1, info_target = K.TARGET_NEAR,
    },
    custom = {
        count = 0,
    },
    -- statia pentru departamente (/pdc): zona si limita radarului, orasul lui, dialogurile /ticket /su
    pd = {
        zone = "", limit = 100, city = "", pick = "",
    },
}

local cfg = inicfg.load(defaultConfig, K.CFG_FILE)

local function saveCfg()
    inicfg.save(cfg, K.CFG_FILE)
end

-- un feature din setari e pornit? (valorile din ini sunt 1 / 0)
local function feat(key)
    return (tonumber(cfg.main[key]) or 0) == 1
end
-- module definite mai jos, anuntate aici ca sa poata fi folosite de tot codul de dinainte
local Notify, Report, Check, Defer, State, App   -- State si App sunt folosite si de functii definite inaintea lui (ex. Candidate.set)

-- ============================================================
-- TEXTE INTERFATA (ro / en)
-- ============================================================
local L = {
    [K.LANG_RO] = {
        tab_general = "General", tab_binds = "Bind-uri",
        ui_lang = "Limba interfetei", proc_lang = "Limba mesajelor",
        -- notite (/notepad)
        sec_notes = "Notitele mele", notes_title = "Notite", notes_open = "Deschide notepad",
        notes_count = "%d notite in %d foldere", notes_first = "Notite",
        notes_folders = "Foldere", notes_new_folder = "Folder nou...", notes_add_folder = "adauga folder",
        notes_del_folder = "Sterge folderul, cu tot ce e in el",
        notes_del_folder2 = "Mai apasa o data ca sa stergi folderul",
        notes_new = "Scrie o notita sau o comanda...", notes_add = "Adauga",
        notes_empty = "Nicio notita in acest folder. Scrie una jos si apasa Enter.",
        notes_send = "Trimite in chat, exact cum e scrisa",
        notes_copy = "Copiaza textul (il lipesti oriunde cu Ctrl+V)",
        notes_edit = "Modifica notita", notes_del = "Sterge notita",
        notes_save = "Salveaza", notes_cancel = "Renunta",
        notes_copied = "Copiat: %s",
        notes_long = "Serverul taie ce trece de %d caractere.",
        notes_hint = "Dublu-click pe o notita ca sa o modifici.",
        notes_rename_hint = "Dublu-click = redenumeste folderul",
        -- reset aranjament / versiune / ghid de pornire
        font_old = "Fisierul lib/fAwesome6_solid.lua din acest modpack e mai vechi: iconitele mari sunt oprite. Suprascrie-l cu cel din arhiva helperului.",
        -- factiune aliata
        f_allyPay = "Banii inapoi aliatilor",
        f_allyPay_tip = "Cand dai o licenta unui membru al factiunii aliate, helperul ii trimite pretul inapoi cu /pay, imediat ce o accepta. Suma e pretul din fisierul de date, la nivelul lui, fara bonusul AR (acela vine de la factiune, nu din buzunarul lui).",
        ally_none = "fara aliat",
        ally_pick_tip = "Factiunea careia ii dai banii inapoi. Gol = cea scrisa in fisierul de date pentru orasul tau.",
        ally_title = "Factiune aliata",
        ally_paid = "Am dat inapoi %s lui %s: e din factiunea aliata.",
        ally_paid_short = "%s inapoi lui %s",
        ally_pin = "Banii tai sunt inca sub cheie. Deblocheaza-i cu /pin si plata catre aliat pleaca singura (sau foloseste /sicpay).",
        ally_pin_short = "Da /pin: o plata catre aliat asteapta",
        ally_none_due = "Nicio plata in asteptare catre factiunea aliata.",
        g_sicpay = "trimite acum platile catre aliati care asteptau /pin",
        reset_layout = "Reseteaza aranjamentul", reset_done = "Ferestrele si HUD-urile au revenit la locul lor.",
        reset_layout_tip = "Readuce toate ferestrele si panourile de pe ecran la pozitia si marimea implicita (/sicreset).",
        ver_new = "Versiune noua disponibila: %s", ver_src = "- ia-o din Releases, de pe sursa oficiala",
        f_verCheck = "Verifica versiunea", f_verCheck_tip = "La pornire intreaba sursa oficiala daca a aparut o versiune mai noua. Nu trimite nimic despre tine.",
        wiz_title = "SICHelper - ghid de pornire", wiz_step = "Pasul %d din %d",
        wiz_reopen = "Ghidul de pornire", wiz_reopen_tip = "Deschide din nou ghidul in 4 pasi (limba, factiunea, tastele).",
        wiz_lang = "Limba", wiz_lang_hint = "Limba interfetei si a mesajelor trimise candidatilor. Se schimba oricand din /sih.",
        wiz_faction = "Factiunea ta", wiz_faction_hint = "De aici vin culorile, formatul anuntului de pe /f si comenzile potrivite.",
        wiz_keys = "Trei taste", wiz_keys_hint = "Apasa pe casuta, apoi tasta dorita. Restul bind-urilor sunt in /sih -> Bind-uri.",
        wiz_keys_tip = "ESC sterge tasta. Poti sari peste pasul acesta.",
        wiz_done = "Gata", wiz_done1 = "da /duty, apoi asteapta un /needlicense - primesti notificare pe ecran",
        wiz_done2 = "accepta cererea (tasta de mai sus sau /acc) - jucatorul devine candidatul tau",
        wiz_done3 = "deschide /sic, trimite textele testului, apoi da licenta",
        wiz_done_hint = "Tot ce ai vazut aici se schimba oricand din /sih. Lista completa de comenzi e in /sih -> General -> Comenzi.",
        wiz_open_sic = "Deschide /sic", wiz_back = "Inapoi", wiz_next = "Continua", wiz_skip = "Sari peste", wiz_finish = "Gata",
        -- /info
        info_window = "Buletinul jucatorului", info_title = "info", info_show = "Arata",
        info_id_tip = "Alt ID: scrie-l aici si apasa Enter. Fereastra e mereu aceeasi.",
        info_wait = "astept raspunsul la /id...",
        info_level = "nivel", info_faction = "factiune", info_no_faction = "fara factiune",
        info_lics = "licente", info_lic_none = "necunoscute - da /requestlicenses ca sa le vezi",
        info_lic_tip = "Licentele se citesc din dialogul de la /requestlicenses, pentru jucatorul cerut ultimul.",
        info_state = "stare", info_near = "langa tine - %d m", info_far = "nu e langa tine",
        info_in_veh = "in %s", info_lang = "limba",
        info_skin = "skin", info_no_skin = "skin necunoscut",
        info_notes = "Notitele mele despre el",
        info_note_tip = "Scrie ce vrei; se salveaza cand iesi din camp, in config/SICHelper_players.lua",
        info_no_player = "Deschide /info pe un jucator ca sa poti scrie notite.",
        info_hist_title = "istoric cu tine", info_hist_none = "nicio licenta de la tine",
        info_hist = "%d licente de la tine", info_hist_last = "ultima: %s, %s",
        info_cand = "Candidat", info_copy = "Copiaza numele",
        info_copy_tip = "Copiaza numele jucatorului in clipboard.",
        tip_withme_btn = "Deschide fereastra /withme pentru acest jucator.",
        tip_sxwas_btn = "Intreaba pe /sx daca l-a acceptat deja cineva.",
        tip_cand_btn = "Il face candidatul tau (fara sa trimita nimic pe server).",
        notes_nosave = "Nu am putut scrie notitele in config/SICHelper_notes.lua",
        g_notepad = "notitele tale: le trimiti in chat sau le copiezi",
        g_info = "buletinul jucatorului: nivel, factiune, rang, licente, notitele tale",
        g_sicreset = "readuce ferestrele si HUD-urile la pozitia implicita",
        faction = "Factiunea mea", city = "Orasul", delay = "Pauza intre mesaje",
        delay_hint = "intre doua mesaje trimise automat de helper (comenzi, /f, /sx)",
        bonus = "Bonus factiune (%)", bonus_hint = "bonusul factiunii (AR), procentul din /stats; se adauga peste preturile licentelor",
        auto_dl = "/dl automat", auto_dl_hint = "cand trimiti un text de test care contine /dl, dai si tu /dl",
        show_answers = "Raspunsuri in chat", show_answers_hint = "la Q1..Qn iti arata (doar tie) raspunsul asteptat",
        tab_tutorial = "Tutorial", data_missing = "Fisierul de date lipseste sau are o eroare: %s",
        data_hint = "Textele, raspunsurile, preturile si tutorialul se editeaza in moonloader/config/SICHelper_data.lua",
        answer = "Raspuns", theme = "Tema culori", accept_btn = "Accepta ultimul /needlicense", reqlic_tip = "/requestlicenses: candidatului; fara candidat, celui mai apropiat jucator",
        tip_accept = "Trimite /accept needlicense pentru jucatorul de mai sus. Devine candidatul tau si primeste un /sms.",
        tip_start = "Trimite /startlesson pentru candidat, pe licenta din tabul ales.",
        tip_city = "Orasul pentru care se trimit textele testului (LS / SF / LV).",
        tip_give = "Trimite /givelicense candidatului, pentru licenta din tabul ales.",
        tip_fail = "Trimite /stoplesson candidatului: opreste lectia fara licenta.",
        tip_give_lic = "Trimite /givelicense candidatului pentru aceasta licenta.",
        tip_give_all = "Trimite pe rand toate licentele cerute in /withme, fiecare dupa ce o accepta.",
        tip_lang = "Limba textelor trimise (RO / EN). E aceeasi cu Limba mesajelor din /sih.",
        hours = "ore", renew_ok = "sub 50 de ore: se poate da renew", renew_no = "50+ ore: nu se poate da renew",
        close = "Inchide", queue = "Coada", notify_error_title = "Eroare de la server",
        need_license = "%s are nevoie de licente (nivel %s).", need_how_key = "Accepta cu tasta " .. COLOR.CMD .. "%s" .. COLOR.DIM .. " sau din /sic.", need_how_sic = "Accepta din /sic.",
        report_title = "Raport saptamanal", report_none = "Da /raport ca sa vad datele.",
        report_days_left = "Timp ramas (zile)", report_rankup = "Rank UP lider (zile)",
        report_progress = "Raport", report_bonus = "Bonus", report_refresh = "Actualizeaza (/raport)",
        report_session_hint = "licente acceptate in sesiunea asta (de la pornirea jocului)",
        check_title = "DOVEZI", check_accept = "/accept needlicense", check_request = "/requestlicenses",
        check_announce = "Anunt pe /f", check_answer = "Raspuns / ultimul task", check_finish = "/givelicense sau /stoplesson",
        f_checklist = "Checklist dovezi", f_checklist_tip = "Panou in dreapta ecranului cu pasii licentei; se bifeaza singuri, iar aparatul foto arata la ce pas ai facut screenshot.",
        f_reportWindow = "/raport in fereastra helperului", f_reportWindow_tip = "Dialogul de la /raport e inlocuit cu o fereastra cu bare de progres si contoarele sesiunii.",
        f_dutyHud = "HUD raport cat esti on duty", f_dutyHud_tip = "Sus, in dreapta: RAPORT 8/8 si BONUS 85/30. Se ia din /raport si creste singur la fiecare licenta acceptata. Steluta = valori tinute local, da /raport ca sa le confirmi.",
        not_on_duty = "Nu esti la datorie! Foloseste " .. COLOR.CMD .. "/duty" .. COLOR.ERR .. " ca sa te pui on duty.",
        pagesize = "Randuri in chat", pagesize_hint = "trimite /pagesize (10-30); se aplica si la pornire",
        apply = "Aplica", screenshot = "Screenshot (F8)", duty = "duty",
        wm_author = "SICHelper by ZioAdolf  -  Discord: vlandrewz",
        wm_bugs = "Bug sau idee? Discord: vlandrewz  -  Comenzi si texte de test: SIHelper by AdeM",
        wm_src = "GPL-3.0  -  sursa oficiala: github.com/ZioAdolf-modding/SICHelper",
        sec_auto = "Automatizari", sec_notify = "Notificari", sec_window = "Ferestre", sec_cmds = "Comenzi",
        auto_stoplesson = "Stoplesson automat", auto_stoplesson_hint = "cand jucatorul accepta licenta (sub nivel 50)",
        notify_on = "Notificari /needlicense", notify_on_hint = "primesti o notificare cand un jucator foloseste /needlicense",
        notify_level = "Pentru nivel", n_any = "orice", n_low = "1-49", n_high = "50+",
        notify_text = "cere licente", notify_level_short = "nivel", notify_taken = "Serviciul a fost acceptat de: %s", notify_ago = "acum %dm %02ds (jocul era in bara)",
        startlesson = "Start lesson", lesson_started = "Lectie pornita pentru %s (%s).",
        lesson_stopped = "Lectie oprita pentru %s.",
        rr_label = "Repair / Refill", rr_hint = "/repair + /refill (cu /switchjob la mecanic daca e nevoie)",
        rr_start = "Trec pe jobul de mecanic...", rr_done = "Repair si refill gata.",
        rr_nojob = "Nu ai jobul de mecanic.", rr_busy = "Repair / refill e deja in curs.",
        plus_bonus = "+ %d%% bonus factiune",
        -- feature-uri
        tab_features = "Features", sec_commands = "Comenzi",
        fg_test = "Test", fg_candidate = "Candidat", fg_look = "Aspect", fg_fvr = "FVR",
        f_theoryPagesize = "/pagesize 30 la lectiile teoretice",
        f_theoryPagesize_tip = "La Start lesson pe Fishing, Weapons sau Materials pune chatul pe 30 de randuri, ca sa vezi toate raspunsurile.",
        f_autoStoplesson = "Stoplesson automat",
        f_autoStoplesson_tip = "Cand jucatorul accepta licenta, helperul da singur /stoplesson.",
        f_autoDl = "/dl automat",
        f_autoDl_tip = "Cand trimiti textul cu [/dl] candidatului, helperul da /dl si pentru tine.",
        f_showAnswers = "Raspunsuri in chat",
        f_showAnswers_tip = "La fiecare intrebare trimisa vezi in chat (doar tu) raspunsul corect.",
        f_chain50 = "50+: licentele una cate una",
        f_chain50_tip = "La un jucator 50+ dai prima licenta, restul pleaca singure, pe rand, dupa ce le accepta.",
        f_dutyCheck = "Verificare duty",
        f_dutyCheck_tip = "",
        f_hpMonitor = "HP vehicul live",
        f_hpMonitor_tip = "La Flying si Sailing vezi HP-ul vehiculului candidatului in /sic. Sub 950 se face rosu si te anunta.",
        f_clearCp = "Sterge checkpoint-ul la accept",
        f_clearCp_tip = "Daca ai un checkpoint activ cand accepti o cerere, helperul trimite intai /killcp (si /cancel find) ca sa nu ramai cu marcajul vechi. Comenzile sunt editabile in fisierul de date.",
        f_autoSms = "SMS la accept",
        f_autoSms_tip = "Dupa un /accept needlicense reusit, candidatul primeste automat un /sms ca ajungi la el (textul e in fisierul de date).",
        f_autoCandidate = "Candidat automat",
        f_autoCandidate_tip = "In momentul in care accepti un /needlicense (buton sau bind), jucatorul devine candidatul tau.",
        f_dutyWindows = "Ferestre la duty",
        f_dutyWindows_tip = "Cand intri la datorie (/duty) se deschid singure ferestrele alese alaturi; cand iesi, se inchid.",
        f_subtotalAR = "AR bonus",
        f_subtotalAR_tip = "Subtotalul licentelor din /withme include bonusul factiunii (AR, procentul din /stats). Alaturi alegi cat e bonusul.",
        f_notifyOn = "Notificari /needlicense",
        f_notifyOn_tip = "Cand cineva da /needlicense, apare un cartonas pe ecran cu numele si nivelul lui.",
        f_sicLastSent = "Ultimul mesaj in /sic",
        f_sicLastSent_tip = "Jos in /sic vezi ultimul mesaj trimis de helper.",
        f_dock = "Bara de iconite pe ecran", dock_auto = "Auto", dock_vert = "Verticala", dock_horiz = "Orizontala",
        f_bindLegend = "Legenda bind-urilor pe ecran", legend_title = "Bind-uri", legend_dist = "Distanta pana la",
        f_hideSrvDist = "Ascunde distanta serverului de pe ecran", f_hideSrvDist_tip = "Cand ai candidat si legenda arata distanta, mesajul de distanta al serverului (gametext / textdraw) nu se mai afiseaza.",
        f_bindLegend_tip = "Un panou mic, mutabil, cu tastele bind-urilor active si ce fac. Se ascunde cand nu ai niciun bind cu tasta setata.",
        f_dock_tip = "Sloturi cu /sic, /withme, /raport si /sih, mereu pe ecran, mutabile. Click cand cursorul e activ sau cat tii apasata tasta Cursor din Bind-uri (aceeasi tasta, cu o fereastra deschisa, ascunde cursorul ca sa poti folosi camera).",
        f_fadeAnim = "Animatii la ferestre",
        f_fadeAnim_tip = "Ferestrele apar si dispar lin. Oprit = apar instant.",
        f_shotRename = "Redenumire screenshot-uri",
        f_shotRename_tip = "Screenshot-urile facute cu butonul din /sic primesc numele candidatului, licenta si ce era ultima data in chat (ex. SIC_Kernobyl_Flying_2026-09-17_fannounce.png). Raman in acelasi folder.",
        f_shortsOn = "Comenzi scurte generale (by AdeM)",
        f_shortsOn_tip = "Scurtaturile generale din SIHelper by AdeM: /m /cm /missm /missc /sv /sj /lpb /rev /ha /sa /cf /gk /sc /qh /ma /ra. Se aplica dupa Ctrl+R. Oprit implicit, ca sa nu se bata cu alte scripturi.",
        f_fvrOn = "FVR",
        f_fvrOn_tip = "/ffvr anunta pe /f si /sx, numara secundele si da /fvr. /sfvr opreste.",
        fvr_start_text = "Text pe /f", fvr_sx_text = "Text pe /sx", fvr_end_text = "Text dupa /fvr", fvr_seconds = "Secunde",
        fvr_started = "FVR in %d secunde. /sfvr opreste.", fvr_stopped = "FVR oprit.",
        fvr_busy = "Exista deja un FVR in curs.", fvr_none = "Nu e niciun FVR in curs.",
        fvr_notext = "Textul pentru /f lipseste (vezi /sih -> Features -> FVR).", fvr_off = "FVR e oprit din /sih -> Features.",
        hp_fail = "HP-ul vehiculului lui %s a scazut sub 950 (%d)!", hp_fail_short = "HP vehicul sub 950 (%d)",
        hp_label = "HP vehicul",
        shot_renamed = "Screenshot salvat ca %s",
        shot_notfound = "Nu am gasit screenshot-ul nou in %s (SA:MP nu l-a salvat?).",
        level = "nivel", level_unknown = "nivel necunoscut",
        give = "Give license", fail = "Failed / stoplesson",
        chain_wait = "Astept sa accepte %s, apoi continui cu: %s",
        chain_next = "Acceptat. Trimit urmatoarea: %s",
        chain_done = "Toate licentele din /withme au fost date.",
        giveme_started = "Imi dau singur: %s. Accept automat ce ofera serverul.",
        giveme_noid = "Nu-mi pot afla id-ul de jucator.",
        chain_timeout = "Nu a acceptat licenta in %d s; restul lantului a fost anulat.",
        sec_lang = "Limba", sec_faction = "Factiune", sec_send = "Trimitere",
        sec_guide = "Ghid rapid", sec_lic = "Licente pentru /withme",
        actions = "Actiuni instructor", custom = "Bind-uri personalizate", grp_instructor = "Instructor", grp_hud = "HUD / Ferestre",
        binds_search = "Cauta dupa cuvant cheie...", binds_nomatch = "Nimic din ce am nu se potriveste cu cautarea. Mergi la sectiunea Bind-uri personalizate si adauga-ti comanda.",
        col_action = "Actiune", col_key = "Tasta", col_target = "Tinta", col_on = "Activ",
        binds_hint = "Click pe tasta, apoi apasa tasta dorita. ESC sterge bind-ul.",
        add_bind = "Adauga un bind", press_key = "apasa o tasta...", add_bind_hint = "alegi actiunea, apoi apesi tasta",
        legend_hide = "Ascunde din legenda (bind-ul ramane activ)", legend_show = "Arata in legenda", legend_dist_close = "click = inchide",
        bind_clear = "Sterge tasta",
        sec_keys = "Tastele mele", binds_active = "%d bind-uri active", no_binds = "Niciun bind cu tasta setata.",
        lines_short = "randuri", cmds_count = "%d comenzi",
        search_hint = "Cauta o setare (orice tab)...", search_none = "Nimic nu se potriveste cu cautarea.",
        search_more = "... si inca %d rezultate", search_open = "deschide",
        t_last = "ultimul candidat", t_near = "cel mai apropiat", t_ask = "cere ID", t_none = "-",
        conflict = "Conflict: tasta %s e folosita de mai multe actiuni.",
        no_candidate = "Nu am niciun candidat.", no_need = "Nimeni nu a dat /needlicense inca.",
        cand_locked = "Candidatul ramane %s (lectie in curs). Il schimbi manual din /sic sau /siccand.",
        cp_cleared = "Cererea a fost luata de %s; am sters checkpoint-ul.",
        cand_locked_tip = "Candidat in lucru (a acceptat /requestlicenses): un alt accept nu-l mai schimba.",
        no_near = "Nu e niciun jucator la mai putin de %d m.",
        candidate = "Candidat", candidate_is = "Candidat: %s",
        esc_hint = "ESC inchide fereastra", close_all = "Inchide toate ferestrele",
        -- ghid rapid
        g_withme = "anunta pe /f si citeste nivelul din /id",
        g_withme0 = "fara argumente: deschide fereastra",
        g_sxwas = "INAINTE de withme, la un jucator gasit pe strada: intreaba pe /sx daca l-a acceptat deja cineva",
        g_siccand = "seteaza manual candidatul",
        g_sic = "fereastra de teste (mica, mutabila)",
        g_sih = "setari: limba, factiune, feature-uri, bind-uri, tutorial",
        g_salut = "pe /w: salut + cere licentele (fara id: candidatul)", g_pa = "pe /w: la revedere (fara id: candidatul)",
        g_need = "pe /w: intreaba daca are nevoie de licente (fara id: cel mai apropiat)",
        g_ok = "pe /w: felicitari, ai trecut - inainte de /givelicense (fara id: candidatul)",
        g_sicraport = "fereastra de raport (bare de progres, contoarele sesiunii)",
        g_giveme = "licentele pentru tine (renew): trimite /givelicense pe id-ul tau si accepta singur",
        g_shorts1 = "comenzile din SIHelper by AdeM: accept needlicense / requestlicenses / stoplesson (fara id: candidatul)",
        g_shorts2 = "give license: Weapon / Materials / Sailing / Fishing / Flying candidatului",
        g_shorts3 = "start lesson pe aceeasi licenta; /ccc curata chatul",
        g_shorts4 = "textele testelor: w1-5, m1-4, f1-4, lsfl1-3 / lvfl / sffl, lss1-2 / lvs / sfs",
        g_auto = "Candidatul se retine singur cand accepti un /needlicense; e folosit de request / stop si de tab-ul 50+.",
        g_binds = "Bind-urile nu se declanseaza cand scrii in chat, in dialog sau in meniul de pauza.",
        -- fereastra withme / cere ID
        prompt_id = "ID", lic_for = "Licente pentru", ok = "Trimite", cancel = "Anuleaza",
        nearest = "cel mai apropiat jucator", subtotal = "Subtotal",
        bonus_short = "bonus %d%%",
        not_online = "Nu exista un jucator online cu id-ul %d.",
        bad_id = "ID invalid.",
        bad_lic = "Licenta invalida. Foloseste un numar de la 1 la 6.",
        lic_list = "1 Flying, 2 Sailing, 3 Fishing, 4 Weapons, 5 Materials, 6 Toate",
        lic_needed = "Alege cel putin o licenta.",
        usage_withme = "/withme <id> <1-6> [1-6 ...]  sau  /withme pentru fereastra",
        usage_sxwas = "/sxwas <id>",
        withme_busy = "Astept inca raspunsul de la /id pentru comanda anterioara.",
        withme_timeout = "Nu am primit nivelul de la /id; mesajul pe /f NU a fost trimis.",
        sent_f = "Trimis pe /f: %s",
        sent_sx = "Trimis pe /sx: %s", sent_w = "Trimis pe /w lui %s: %s", sent_sms = "SMS de confirmare trimis lui %s.",
        subtotal_chat = "Subtotal licente (nivel %d): " .. COLOR.MONEY .. "%s" .. COLOR.TEXT,
        subtotal_none = "Nivelul %d e sub minimul pentru licentele alese.",
        -- /sic
        sic_last = "ultimul", sic_nothing = "nimic trimis inca",
        sic_give_all = "Toate licentele", sic_withme = "withme",
        sic_no_candidate = "fara candidat: alege un ID mai sus",
        given = "Ai oferit licenta %s jucatorului %s.",
        chain = "Continui automat cu: %s",
        tab_fly = "Flying", tab_sail = "Sailing", tab_fish = "Fishing", tab_weap = "Weapons",
        tab_mat = "Materials", tab_lvl50 = "Level 50+",
        -- departamente (modulul PD)
        grp_pd = "Departamente (PD / FBI / NG)", iface = "Interfata",
        iface_si = "School Instructors  (/sic)", iface_pd = "Departamente  (/pdc)",
        iface_tip = "Un click schimba tot: factiunea, culorile, statia din bara de iconite, comenzile scurte, bind-urile si tutorialul.",
        pd_missing = "Modulul pentru departamente nu s-a incarcat (%s). Restul helperului merge normal.",
        wiz_pd1 = "da /duty (sau Duty din statie, tab-ul Dispecerat)",
        wiz_pd2 = "alege suspectul: din radar, dupa ID sau cel mai apropiat; nivelul se afla singur cu /id",
        wiz_pd3 = "un click pe abatere: helperul spune textul si da comanda potrivita nivelului, dupa regulament",
        wiz_open_pdc = "Deschide /pdc",
        iface_now_pd = "Interfata: Departamente. %s (sau /sic) deschide statia PD; setarile raman in /sih sau /pdh.",
        iface_now_si = "Interfata: School Instructors. /sic deschide fereastra de teste.",
    },
    [K.LANG_EN] = {
        tab_general = "General", tab_binds = "Binds",
        ui_lang = "Interface language", proc_lang = "Message language",
        -- notes (/notepad)
        sec_notes = "My notes", notes_title = "Notes", notes_open = "Open notepad",
        notes_count = "%d notes in %d folders", notes_first = "Notes",
        notes_folders = "Folders", notes_new_folder = "New folder...", notes_add_folder = "add folder",
        notes_del_folder = "Delete this folder and everything in it",
        notes_del_folder2 = "Click again to delete the folder",
        notes_new = "Write a note or a command...", notes_add = "Add",
        notes_empty = "No notes in this folder. Write one below and press Enter.",
        notes_send = "Send to chat, exactly as written",
        notes_copy = "Copy the text (paste it anywhere with Ctrl+V)",
        notes_edit = "Edit the note", notes_del = "Delete the note",
        notes_save = "Save", notes_cancel = "Cancel",
        notes_copied = "Copied: %s",
        notes_long = "The server cuts anything over %d characters.",
        notes_hint = "Double-click a note to edit it.",
        notes_rename_hint = "Double-click to rename the folder",
        -- layout reset / version check / wizard
        font_old = "The lib/fAwesome6_solid.lua in this modpack is older: the large icons are off. Overwrite it with the one from the helper archive.",
        -- allied faction
        f_allyPay = "Pay allies back",
        f_allyPay_tip = "When you give a license to a member of the allied faction, the helper sends the price back with /pay as soon as they accept it. The amount is the price from the data file, at their level, without the AR bonus (that one comes from the faction, not from their pocket).",
        ally_none = "no ally",
        ally_pick_tip = "The faction you pay back. Empty = the one set in the data file for your city.",
        ally_title = "Allied faction",
        ally_paid = "Sent %s back to %s: they are in the allied faction.",
        ally_paid_short = "%s back to %s",
        ally_pin = "Your money is still locked. Unlock it with /pin and the payment to your ally goes out by itself (or use /sicpay).",
        ally_pin_short = "Type /pin: a payment to your ally is waiting",
        ally_none_due = "No payment waiting for the allied faction.",
        g_sicpay = "sends the ally payments that were waiting for /pin",
        reset_layout = "Reset the layout", reset_done = "Windows and HUDs are back in place.",
        reset_layout_tip = "Puts every window and on-screen panel back to its default position and size (/sicreset).",
        ver_new = "New version available: %s", ver_src = "- get it from Releases, on the official source",
        f_verCheck = "Check for updates", f_verCheck_tip = "On start it asks the official source whether a newer version exists. It sends nothing about you.",
        wiz_title = "SICHelper - getting started", wiz_step = "Step %d of %d",
        wiz_reopen = "Getting started", wiz_reopen_tip = "Opens the 4 step guide again (language, faction, keys).",
        wiz_lang = "Language", wiz_lang_hint = "The interface language and the language of the messages sent to candidates. Can be changed anytime in /sih.",
        wiz_faction = "Your faction", wiz_faction_hint = "It sets the colours, the /f announcement format and the commands that fit.",
        wiz_keys = "Three keys", wiz_keys_hint = "Click the box, then press the key you want. All the other binds are in /sih -> Binds.",
        wiz_keys_tip = "ESC clears the key. You can skip this step.",
        wiz_done = "Done", wiz_done1 = "type /duty, then wait for a /needlicense - you get an on-screen card",
        wiz_done2 = "accept it (the key above or /acc) - the player becomes your candidate",
        wiz_done3 = "open /sic, send the test texts, then give the license",
        wiz_done_hint = "Everything here can be changed anytime in /sih. The full command list is in /sih -> General -> Commands.",
        wiz_open_sic = "Open /sic", wiz_back = "Back", wiz_next = "Next", wiz_skip = "Skip", wiz_finish = "Done",
        -- /info
        info_window = "Player card", info_title = "info", info_show = "Show",
        info_id_tip = "Another ID: type it here and press Enter. It is always the same window.",
        info_wait = "waiting for the /id reply...",
        info_level = "level", info_faction = "faction", info_no_faction = "no faction",
        info_lics = "licenses", info_lic_none = "unknown - use /requestlicenses to see them",
        info_lic_tip = "Licenses are read from the /requestlicenses dialog, for the last player you asked about.",
        info_state = "state", info_near = "next to you - %d m", info_far = "not next to you",
        info_in_veh = "in a %s", info_lang = "language",
        info_skin = "skin", info_no_skin = "unknown skin",
        info_notes = "My notes about them",
        info_note_tip = "Write anything; it is saved when you leave the field, in config/SICHelper_players.lua",
        info_no_player = "Open /info on a player to write notes.",
        info_hist_title = "history with you", info_hist_none = "no license from you",
        info_hist = "%d licenses from you", info_hist_last = "last: %s, %s",
        info_cand = "Candidate", info_copy = "Copy the name",
        info_copy_tip = "Copies the player name to the clipboard.",
        tip_withme_btn = "Opens the /withme window for this player.",
        tip_sxwas_btn = "Asks on /sx whether someone has already accepted them.",
        tip_cand_btn = "Makes them your candidate (sends nothing to the server).",
        notes_nosave = "Could not write the notes to config/SICHelper_notes.lua",
        g_notepad = "your notes: send them to chat or copy them",
        g_info = "the player card: level, faction, rank, licenses, your notes",
        g_sicreset = "puts the windows and HUDs back to their default position",
        faction = "My faction", city = "City", delay = "Delay between messages",
        delay_hint = "between two messages the helper sends by itself (commands, /f, /sx)",
        bonus = "Faction bonus (%)", bonus_hint = "faction bonus (AR), the percentage from /stats; added on top of the license prices",
        auto_dl = "Auto /dl", auto_dl_hint = "when you send a test text that contains /dl, you also type /dl",
        show_answers = "Answers in chat", show_answers_hint = "on Q1..Qn it shows you (only you) the expected answer",
        tab_tutorial = "Tutorial", data_missing = "The data file is missing or has an error: %s",
        data_hint = "Texts, answers, prices and the tutorial are edited in moonloader/config/SICHelper_data.lua",
        answer = "Answer", theme = "Color theme", accept_btn = "Accept the last /needlicense", reqlic_tip = "/requestlicenses: to the candidate; with no candidate, to the nearest player",
        tip_accept = "Sends /accept needlicense for the player above. They become your candidate and get a /sms.",
        tip_start = "Sends /startlesson for the candidate, for the license of the selected tab.",
        tip_city = "The city the test texts are sent for (LS / SF / LV).",
        tip_give = "Sends /givelicense to the candidate, for the license of the selected tab.",
        tip_fail = "Sends /stoplesson to the candidate: ends the lesson without a license.",
        tip_give_lic = "Sends /givelicense to the candidate for this license.",
        tip_give_all = "Sends every license asked in /withme, one by one, each after it is accepted.",
        tip_lang = "Language of the texts sent (RO / EN). Same as Message language in /sih.",
        hours = "hours", renew_ok = "under 50 hours: renew possible", renew_no = "50+ hours: no renew",
        close = "Close", queue = "Queue", notify_error_title = "Server error",
        need_license = "%s needs licenses (level %s).", need_how_key = "Accept with key " .. COLOR.CMD .. "%s" .. COLOR.DIM .. " or from /sic.", need_how_sic = "Accept from /sic.",
        report_title = "Weekly report", report_none = "Type /raport to see the data.",
        report_days_left = "Days left", report_rankup = "Rank UP leader (days)",
        report_progress = "Report", report_bonus = "Bonus", report_refresh = "Refresh (/raport)",
        report_session_hint = "licenses accepted this session (since the game started)",
        check_title = "PROOF", check_accept = "/accept needlicense", check_request = "/requestlicenses",
        check_announce = "/f announce", check_answer = "Answer / last task", check_finish = "/givelicense or /stoplesson",
        f_checklist = "Proof checklist", f_checklist_tip = "Panel on the right of the screen with the license steps; they tick by themselves and the camera shows at which step you took a screenshot.",
        f_reportWindow = "/raport in the helper window", f_reportWindow_tip = "The /raport dialog is replaced by a window with progress bars and the session counters.",
        f_dutyHud = "Report HUD while on duty", f_dutyHud_tip = "Top right: REPORT 8/8 and BONUS 85/30. Taken from /raport and increased by itself on every accepted license. Star = values kept locally, type /raport to confirm them.",
        not_on_duty = "You are not on duty! Use " .. COLOR.CMD .. "/duty" .. COLOR.ERR .. " to go on duty.",
        pagesize = "Chat lines", pagesize_hint = "sends /pagesize (10-30); also applied at startup",
        apply = "Apply", screenshot = "Screenshot (F8)", duty = "duty",
        wm_author = "SICHelper by ZioAdolf  -  Discord: vlandrewz",
        wm_bugs = "Bug or idea? Discord: vlandrewz  -  Commands and test texts: SIHelper by AdeM",
        wm_src = "GPL-3.0  -  official source: github.com/ZioAdolf-modding/SICHelper",
        sec_auto = "Automation", sec_notify = "Notifications", sec_window = "Windows", sec_cmds = "Commands",
        auto_stoplesson = "Auto stoplesson", auto_stoplesson_hint = "when the player accepts the license (below level 50)",
        notify_on = "/needlicense notifications", notify_on_hint = "Receive notification when a player uses /needlicense.",
        notify_level = "For level", n_any = "any", n_low = "1-49", n_high = "50+",
        notify_text = "requests licenses", notify_level_short = "level", notify_taken = "The request was accepted by: %s", notify_ago = "%dm %02ds ago (game was in background)",
        startlesson = "Start lesson", lesson_started = "Lesson started for %s (%s).",
        lesson_stopped = "Lesson stopped for %s.",
        rr_label = "Repair / Refill", rr_hint = "/repair + /refill (via /switchjob to mechanic if needed)",
        rr_start = "Switching to the mechanic job...", rr_done = "Repair and refill done.",
        rr_nojob = "You don't have the mechanic job.", rr_busy = "Repair / refill already in progress.",
        plus_bonus = "+ %d%% faction bonus",
        -- features
        tab_features = "Features", sec_commands = "Commands",
        fg_test = "Test", fg_candidate = "Candidate", fg_look = "Look", fg_fvr = "FVR",
        f_theoryPagesize = "/pagesize 30 on theory lessons",
        f_theoryPagesize_tip = "On Start lesson for Fishing, Weapons or Materials the chat goes to 30 lines, so you see all the answers.",
        f_autoStoplesson = "Auto stoplesson",
        f_autoStoplesson_tip = "When the player accepts the license, the helper sends /stoplesson by itself.",
        f_autoDl = "Auto /dl",
        f_autoDl_tip = "When you send the [/dl] text to the candidate, the helper types /dl for you too.",
        f_showAnswers = "Answers in chat",
        f_showAnswers_tip = "For every question you send, you see the correct answer in chat (only you).",
        f_chain50 = "50+: licenses one by one",
        f_chain50_tip = "On a 50+ player you give the first license, the rest go by themselves, one by one, as he accepts them.",
        f_dutyCheck = "Duty check",
        f_dutyCheck_tip = "",
        f_hpMonitor = "Live vehicle HP",
        f_hpMonitor_tip = "On Flying and Sailing you see the candidate vehicle HP in /sic. Under 950 it turns red and warns you.",
        f_clearCp = "Clear the checkpoint on accept",
        f_clearCp_tip = "If a checkpoint is active when you accept a request, the helper first sends /killcp (and /cancel find) so you are not left with the old marker. The commands are editable in the data file.",
        f_autoSms = "SMS on accept",
        f_autoSms_tip = "After a successful /accept needlicense, the candidate automatically gets a /sms saying you are on your way (text in the data file).",
        f_autoCandidate = "Auto candidate",
        f_autoCandidate_tip = "The moment you accept a /needlicense (button or bind), that player becomes your candidate.",
        f_dutyWindows = "Windows on duty",
        f_dutyWindows_tip = "When you go on duty (/duty) the windows picked next to the switch open by themselves; they close when you go off duty.",
        f_subtotalAR = "AR bonus",
        f_subtotalAR_tip = "The /withme license subtotal includes the faction bonus (AR, the percentage from /stats). Set the bonus next to the switch.",
        f_notifyOn = "/needlicense notifications",
        f_notifyOn_tip = "When someone uses /needlicense, a card with his name and level appears on screen.",
        f_sicLastSent = "Last message in /sic",
        f_sicLastSent_tip = "At the bottom of /sic you see the last message the helper sent.",
        f_dock = "Icon bar on screen", dock_auto = "Auto", dock_vert = "Vertical", dock_horiz = "Horizontal",
        f_bindLegend = "Bind legend on screen", legend_title = "Binds", legend_dist = "Distance to",
        f_hideSrvDist = "Hide the server distance on screen", f_hideSrvDist_tip = "When you have a candidate and the legend shows the distance, the server distance message (gametext / textdraw) is not displayed.",
        f_bindLegend_tip = "A small movable panel with the keys of your active binds and what they do. Hidden when no bind has a key set.",
        f_dock_tip = "Slots for /sic, /withme, /raport and /sih, always on screen, movable. Click while the cursor is active or while holding the Cursor key from Binds (with a window open, the same key hides the cursor so you can use the camera).",
        f_fadeAnim = "Window animations",
        f_fadeAnim_tip = "Windows appear and disappear smoothly. Off = instantly.",
        f_shotRename = "Rename screenshots",
        f_shotRename_tip = "Screenshots taken with the /sic button get the candidate name, the license and what was last in chat (e.g. SIC_Kernobyl_Flying_2026-09-17_fannounce.png). They stay in the same folder.",
        f_shortsOn = "General short commands (by AdeM)",
        f_shortsOn_tip = "The general shortcuts from SIHelper by AdeM: /m /cm /missm /missc /sv /sj /lpb /rev /ha /sa /cf /gk /sc /qh /ma /ra. Applied after Ctrl+R. Off by default so it does not clash with other scripts.",
        f_fvrOn = "FVR",
        f_fvrOn_tip = "/ffvr announces on /f and /sx, counts down and sends /fvr. /sfvr cancels.",
        fvr_start_text = "/f text", fvr_sx_text = "/sx text", fvr_end_text = "Text after /fvr", fvr_seconds = "Seconds",
        fvr_started = "FVR in %d seconds. /sfvr cancels.", fvr_stopped = "FVR cancelled.",
        fvr_busy = "There is already an FVR in progress.", fvr_none = "No FVR in progress.",
        fvr_notext = "The /f text is missing (see /sih -> Features -> FVR).", fvr_off = "FVR is disabled in /sih -> Features.",
        hp_fail = "%s's vehicle HP dropped under 950 (%d)!", hp_fail_short = "vehicle HP under 950 (%d)",
        hp_label = "vehicle HP",
        shot_renamed = "Screenshot saved as %s",
        shot_notfound = "No new screenshot found in %s (SA:MP did not save it?).",
        level = "level", level_unknown = "unknown level",
        give = "Give license", fail = "Failed / stoplesson",
        chain_wait = "Waiting for %s to accept, then continuing with: %s",
        chain_next = "Accepted. Sending the next one: %s",
        chain_done = "All licenses from /withme have been given.",
        giveme_started = "Giving myself: %s. I will accept what the server offers.",
        giveme_noid = "I cannot find my own player id.",
        chain_timeout = "The license was not accepted within %d s; the rest of the chain was cancelled.",
        sec_lang = "Language", sec_faction = "Faction", sec_send = "Sending",
        sec_guide = "Quick guide", sec_lic = "Licenses for /withme",
        actions = "Instructor actions", custom = "Custom binds", grp_instructor = "Instructor", grp_hud = "HUD / Windows",
        binds_search = "Search by keyword...", binds_nomatch = "Nothing I have matches that search. Go to the Custom binds section and add your own command.",
        col_action = "Action", col_key = "Key", col_target = "Target", col_on = "On",
        binds_hint = "Click the key, then press the key you want. ESC clears the bind.",
        add_bind = "Add a bind", press_key = "press a key...", add_bind_hint = "pick the action, then press the key",
        legend_hide = "Hide from the legend (the bind stays active)", legend_show = "Show in the legend", legend_dist_close = "click = close",
        bind_clear = "Clear the key",
        sec_keys = "My keys", binds_active = "%d active binds", no_binds = "No bind has a key set.",
        lines_short = "lines", cmds_count = "%d commands",
        search_hint = "Search a setting (any tab)...", search_none = "Nothing matches your search.",
        search_more = "... and %d more results", search_open = "open",
        t_last = "last candidate", t_near = "nearest player", t_ask = "ask for ID", t_none = "-",
        conflict = "Conflict: key %s is used by more than one action.",
        no_candidate = "No candidate.", no_need = "Nobody has used /needlicense yet.",
        cand_locked = "The candidate stays %s (lesson in progress). Change him manually from /sic or /siccand.",
        cp_cleared = "The request was taken by %s; checkpoint cleared.",
        cand_locked_tip = "Candidate in progress (accepted /requestlicenses): another accept will not replace him.",
        no_near = "No player closer than %d m.",
        candidate = "Candidate", candidate_is = "Candidate: %s",
        esc_hint = "ESC closes the window", close_all = "Close all windows",
        -- quick guide
        g_withme = "announces on /f and reads the level from /id",
        g_withme0 = "no arguments: opens the window",
        g_sxwas = "BEFORE withme, for a player met on the street: asks on /sx whether someone already accepted them",
        g_siccand = "sets the candidate manually",
        g_sic = "test window (small, movable)",
        g_sih = "settings: language, faction, features, binds, tutorial",
        g_salut = "on /w: greeting + ask for licenses (no id: the candidate)", g_pa = "on /w: goodbye (no id: the candidate)",
        g_need = "on /w: ask whether they need licenses (no id: nearest player)",
        g_ok = "on /w: congrats, you passed - before /givelicense (no id: the candidate)",
        g_sicraport = "report window (progress bars, session counters)",
        g_giveme = "licenses for yourself (renew): sends /givelicense on your own id and accepts by itself",
        g_shorts1 = "the commands from SIHelper by AdeM: accept needlicense / requestlicenses / stoplesson (no id: the candidate)",
        g_shorts2 = "give license: Weapon / Materials / Sailing / Fishing / Flying to the candidate",
        g_shorts3 = "start lesson for the same license; /ccc clears the chat",
        g_shorts4 = "test texts: w1-5, m1-4, f1-4, lsfl1-3 / lvfl / sffl, lss1-2 / lvs / sfs",
        g_auto = "The candidate is stored automatically when you accept a /needlicense; it is used by request / stop and by the 50+ tab.",
        g_binds = "Binds do not fire while typing in chat, in a dialog or in the pause menu.",
        -- withme / ask-ID window
        prompt_id = "ID", lic_for = "Licenses for", ok = "Send", cancel = "Cancel",
        nearest = "nearest player", subtotal = "Subtotal",
        bonus_short = "bonus %d%%",
        not_online = "There is no online player with id %d.",
        bad_id = "Invalid ID.",
        bad_lic = "Invalid license. Use a number from 1 to 6.",
        lic_list = "1 Flying, 2 Sailing, 3 Fishing, 4 Weapons, 5 Materials, 6 All",
        lic_needed = "Pick at least one license.",
        usage_withme = "/withme <id> <1-6> [1-6 ...]  or  /withme for the window",
        usage_sxwas = "/sxwas <id>",
        withme_busy = "Still waiting for the /id reply of the previous command.",
        withme_timeout = "No level received from /id; the /f message was NOT sent.",
        sent_f = "Sent on /f: %s",
        sent_sx = "Sent on /sx: %s", sent_w = "Sent on /w to %s: %s", sent_sms = "Confirmation SMS sent to %s.",
        subtotal_chat = "License subtotal (level %d): " .. COLOR.MONEY .. "%s" .. COLOR.TEXT,
        subtotal_none = "Level %d is below the minimum for the chosen licenses.",
        -- /sic
        sic_last = "last", sic_nothing = "nothing sent yet",
        sic_give_all = "All licenses", sic_withme = "withme",
        sic_no_candidate = "no candidate: pick an ID above",
        given = "You offered the %s license to %s.",
        chain = "Continuing automatically with: %s",
        tab_fly = "Flying", tab_sail = "Sailing", tab_fish = "Fishing", tab_weap = "Weapons",
        tab_mat = "Materials", tab_lvl50 = "Level 50+",
        -- departments (PD module)
        grp_pd = "Departments (PD / FBI / NG)", iface = "Interface",
        iface_si = "School Instructors  (/sic)", iface_pd = "Departments  (/pdc)",
        iface_tip = "One click switches everything: faction, colours, the station in the icon bar, the short commands, the binds and the tutorial.",
        pd_missing = "The departments module did not load (%s). The rest of the helper works normally.",
        wiz_pd1 = "type /duty (or Duty in the station, Dispatch tab)",
        wiz_pd2 = "pick the suspect: from the radar, by ID or the nearest one; the level comes by itself from /id",
        wiz_pd3 = "one click on the offence: the helper says the text and sends the command that fits the level, by the rules",
        wiz_open_pdc = "Open /pdc",
        iface_now_pd = "Interface: Departments. %s (or /sic) opens the PD station; settings stay in /sih or /pdh.",
        iface_now_si = "Interface: School Instructors. /sic opens the test window.",
    },
}

local function tr(key, ...)
    local pack = L[cfg.main.uiLang] or L[K.LANG_RO]
    local s = pack[key] or key
    if select("#", ...) > 0 then return string.format(s, ...) end
    return s
end

-- urma de diagnostic: ultimele actiuni ale scriptului, in moonloader/SICHelper_trace.txt
-- (daca jocul crapa, ultima linie spune ce a facut helperul chiar inainte)
K.TRACE_FILE = getWorkingDirectory() .. "\\SICHelper_trace.txt"
K.TRACE_PREV = getWorkingDirectory() .. "\\SICHelper_trace_prev.txt"
local traceCount = 0
local function trace(text)
    traceCount = traceCount + 1
    if traceCount == 1 then
        -- urma sesiunii precedente se pastreaza (dupa un crash, acolo e ce facea helperul)
        os.remove(K.TRACE_PREV)
        os.rename(K.TRACE_FILE, K.TRACE_PREV)
    end
    local f = io.open(K.TRACE_FILE, (traceCount == 1) and "w" or "a")
    if not f then return end
    f:write(os.date("%Y-%m-%d %H:%M:%S"), " ", text, "\n")
    f:close()
end

-- tot ce scriem in chat pleaca din bucla principala (nu din randare / click pe butoane):
-- chatul SA:MP redeseneaza cu D3D si nu e sigur de apelat din interiorul frame-ului
-- chat-ul SA:MP tine maximum 144 de caractere pe linie (codurile de culoare se numara si ele);
-- un text mai lung dat lui sampAddChatMessage poate crapa clientul. Impartim la spatiu, iar liniile
-- urmatoare pornesc cu ultima culoare folosita, ca sa arate la fel.
local function chatLines(text)
    if #text <= K.CHAT_MAX then return { text } end
    local lines, line, color = {}, "", ""
    for word in text:gmatch("%S+") do
        local candidate = (line == "") and (color .. word) or (line .. " " .. word)
        if #candidate > K.CHAT_MAX and line ~= "" then
            table.insert(lines, line)
            line = color .. word
        else
            line = candidate
        end
        local last = word:match(".*(%b{})")     -- ultimul cod de culoare din cuvant
        if last and #last == 8 and last:match("^{%x%x%x%x%x%x}$") then color = last end
    end
    if line ~= "" then table.insert(lines, line) end
    return lines
end

local function chat(text)
    local lines = chatLines(tostring(text))
    Defer.push(function()
        for _, l in ipairs(lines) do sampAddChatMessage(l:sub(1, K.CHAT_MAX), -1) end
    end)
end
local function msg(text)
    chat(TAG.PREFIX .. text)
end
local function err(text)
    chat(TAG.ERROR .. text)
end
local function usage(text)
    chat(TAG.USAGE .. text)
end

-- ============================================================
-- COADA DE MESAJE
-- trimite pe rand, cu pauza, ca serverul sa nu ignore mesajele
-- ============================================================
local Queue = {
    items = {},
    nextAt = 0,
    lastSent = nil,   -- ultimul mesaj trimis, afisat in /sic
}

-- delayAfter (optional, ms) = pauza pana la urmatorul mesaj; implicit cea din setari
function Queue.push(text, delayAfter)
    table.insert(Queue.items, { text = text, after = delayAfter })
end

-- in fata cozii si fara asteptare: pleaca la urmatorul frame al scriptului (sub 20 ms)
function Queue.pushFront(text, delayAfter)
    table.insert(Queue.items, 1, { text = text, after = delayAfter })
    Queue.nextAt = 0
end

function Queue.clear()
    Queue.items = {}
end

function Queue.update()
    if #Queue.items == 0 then return end
    local now = os.clock() * 1000
    if now < Queue.nextAt then return end
    local item = table.remove(Queue.items, 1)
    trace("send " .. item.text)
    sampSendChat(item.text)
    Queue.lastSent = item.text
    Queue.nextAt = now + (item.after or tonumber(cfg.main.queueDelay) or 700)
end

-- ============================================================
-- JUCATORI
-- ============================================================
-- JUCATORI
-- id-ul nostru de jucator (sampIsPlayerConnected il da ca deconectat pe al nostru)
local function myPlayerId()
    -- pcall adauga propriul "ok" in fata: functia intoarce (gasit, id)
    local ok, found, id = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if ok and found and type(id) == "number" then return id end
    return nil
end

-- e cineva online cu id-ul asta? (si noi insine contam)
local function idOnline(id)
    if not id then return false end
    return sampIsPlayerConnected(id) or id == myPlayerId()
end

local function playerName(id)
    if idOnline(id) then
        local ok, name = pcall(sampGetPlayerNickname, id)
        if ok and name and name ~= "" then return name end
    end
    return nil
end

-- intoarce id-ul numeric daca jucatorul e online, altfel afiseaza eroarea si intoarce nil
local function requireOnline(id)
    id = tonumber(id)
    if not id then err(tr("bad_id")) return nil end
    if not idOnline(id) then err(tr("not_online", id)) return nil end
    return id
end

-- cel mai apropiat jucator (fara noi), sau nil daca nu e nimeni in raza
local function nearestPlayer()
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local bestId, bestDist = nil, K.NEAR_DISTANCE
    for _, ped in ipairs(getAllChars()) do
        if ped ~= PLAYER_PED then
            local ok, id = sampGetPlayerIdByCharHandle(ped)
            if ok then
                local dist = getDistanceBetweenCoords3d(x, y, z, getCharCoordinates(ped))
                if dist < bestDist then bestDist, bestId = dist, id end
            end
        end
    end
    return bestId
end

-- id-ul jucatorului cu numele dat (serverul confirma licentele cu numele, nu cu id-ul)
local function findPlayerByName(name)
    name = name:match("^%s*(.-)%s*%.?%s*$") or name   -- fara spatii si punctul final
    for id = 0, 999 do
        if sampIsPlayerConnected(id) and sampGetPlayerNickname(id) == name then return id end
    end
    return nil
end

local function stepConnected(fromId, dir)
    local id = fromId or 0
    for _ = 1, 1000 do
        id = (id + dir) % 1000
        if sampIsPlayerConnected(id) then return id end
    end
    return fromId
end

-- limba fiecarui jucator, aflata din textul cererii lui (/needlicense cu "RO" / "EN" in text) sau setata
-- de instructor din comutatorul RO/EN din /sic; nil = nu se stie -> se foloseste "Limba mesajelor" din /sih
local Langs = { byId = {} }
function Langs.remember(id, lang)
    if id and lang then Langs.byId[id] = { lang = lang, name = playerName(id) } end
end
function Langs.of(id)
    local e = id and Langs.byId[id]
    if e and e.name == playerName(id) then return e.lang end
    return nil
end
-- limba de folosit cu un jucator: a lui daca o stim, altfel ultima setare (RO/EN din /sic = Limba mesajelor din /sih)
function Langs.use(id)
    return Langs.of(id) or cfg.main.procLang or K.LANG_RO
end
-- "RO" / "EN" (sau romana / engleza / english) intr-o linie de server
function Langs.detect(text)
    local plain = text:gsub("{%x%x%x%x%x%x}", "")
    if plain:find("%f[%w]RO%f[%W]") or plain:lower():find("%f[%w]romana%f[%W]") then return K.LANG_RO end
    if plain:find("%f[%w]EN%f[%W]") or plain:lower():find("%f[%w]engleza%f[%W]") or plain:lower():find("%f[%w]english%f[%W]") then return K.LANG_EN end
    return nil
end

-- ============================================================
-- CANDIDAT CURENT (doar in memorie, nu se salveaza pe disc)
-- ============================================================
local Candidate = {
    id = nil, name = "",
    licenses = nil,      -- din dialogul de la /requestlicenses: { [LIC_*] = { status, hours } }
    licensesFor = nil,   -- numele jucatorului pentru care sunt licentele de mai sus
}

-- liniile din dialogul "Licentele lui X": "** Licenta de pilot: Valida - Valabilitate: 81 ore"
local DIALOG_LICENSES = {
    { find = "licenta de pilot",     id = K.LIC_FLYING    },
    { find = "licenta de navigatie", id = K.LIC_SAILING   },
    { find = "licenta de pescar",    id = K.LIC_FISHING   },
    { find = "permis de port-arma",  id = K.LIC_WEAPONS   },
    { find = "licenta de materiale", id = K.LIC_MATERIALS },
}
K.RENEW_MAX_HOURS = 50   -- sub atatea ore ramase se poate da renew

-- parseaza dialogul de licente; intoarce true daca a fost un asemenea dialog
function Candidate.parseLicenseDialog(title, text)
    local who = title and title:match("^Licentele lui (.+)$")
    if not who then return false end
    local result = {}
    for line in text:gmatch("[^\n]+") do
        local clean = line:gsub("{%x%x%x%x%x%x}", ""):lower()
        for _, d in ipairs(DIALOG_LICENSES) do
            if clean:find(d.find, 1, true) then
                local status = clean:match(":%s*([%a]+)") or "?"
                local hours = tonumber(clean:match("valabilitate:%s*(%d+)"))
                result[d.id] = { status = status, hours = hours }
            end
        end
    end
    Candidate.licenses, Candidate.licensesFor = result, who
    return true
end

-- licentele parseate se potrivesc cu jucatorul dat?
function Candidate.licensesOf(id)
    if not Candidate.licenses or not id then return nil end
    local name = playerName(id)
    if not name or Candidate.licensesFor ~= name then return nil end
    return Candidate.licenses
end

-- setare explicita (din /sic, /siccand, /withme, accept): ridica si blocajul de mai jos
-- source: "accept" (dupa /accept needlicense) are prioritate - /withme nu il mai schimba pana se termina lectia
function Candidate.set(id, name, source)
    Candidate.id = id
    Candidate.name = name or playerName(id) or ""
    Candidate.locked = false
    Candidate.source = source
    State.hideCandDist = false        -- candidat nou: randul cu distanta reapare
    -- limba candidatului (daca o stim) devine limba testelor din /sic
    local lang = Langs.of(id)
    if lang then State.sicLang = lang end
end

-- candidatul e "in lucru" (a acceptat /requestlicenses): un alt accept de /needlicense nu-l mai schimba,
-- ca sa nu se schimbe ID-ul in /sic in timp ce dai licenta; se deblocheaza la stoplesson / licenta data
-- blocajul candidatului "in lucru" a fost scos (ca la AdeM: candidatul se schimba mereu la accept / sxwas);
-- functiile raman ca sa nu ramana apeluri orfane, dar nu mai blocheaza nimic
function Candidate.lock()   Candidate.locked = false end
function Candidate.unlock(id)
    if not id or id == Candidate.id then Candidate.locked = false Candidate.source = nil end
end

function Candidate.get()
    if not Candidate.id then return nil end
    return Candidate.id, Candidate.name
end
-- jucatorul al carui nume apare undeva in text (intai candidatul, apoi toti cei conectati)
local function findPlayerInText(text)
    local exact = findPlayerByName(text)
    if exact then return exact end
    local candId, candName = Candidate.get()
    if candId and candName ~= "" and text:find(candName, 1, true) then return candId end
    for id = 0, 999 do
        if sampIsPlayerConnected(id) then
            local nick = sampGetPlayerNickname(id)
            if nick and #nick >= 3 and text:find(nick, 1, true) then return id end
        end
    end
    return nil
end

-- urmatorul / precedentul id conectat, cu intoarcere la capat

-- ============================================================
-- PRETURI
-- ============================================================
local function bonusPercent()
    if not feat("subtotalAR") then return 0 end    -- feature oprit: subtotalul ramane pretul de baza
    return math.max(0, math.min(K.MAX_BONUS_PERCENT, tonumber(cfg.main.bonusPercent) or 0))
end

-- nivelul unui jucator: NU se citeste din scoreboard (sampGetPlayerScore a crapat clientul si pe jucatori
-- streamati, si nestreamati). Se stie doar din raspunsurile la /id (la /needlicense si la /withme), tinute
-- intr-o memorie locala (Levels[id] = { level, name }); numele se verifica, id-urile se refolosesc.
local Levels = {}
local function rememberLevel(id, level)
    if id and level then Levels[id] = { level = level, name = playerName(id) } end
end
local function playerLevel(id)
    if not idOnline(id) then return nil end
    local e = Levels[id]
    if e and e.name == playerName(id) then return e.level end
    return nil
end

-- pretul unei licente pentru un nivel, sau nil daca nivelul e sub minim
local function licensePrice(lic, level)
    if not lic.prices or level < lic.minLevel then return nil end
    if level <= 9 then return lic.prices.low end
    if level <= 49 then return lic.prices.mid end
    return lic.prices.high
end


-- ============================================================
-- DEFER: lucruri care nu trebuie facute din randare (click pe butoane), ci din bucla principala:
-- comenzi de client (/pagesize, /dl), apasarea F8. Se ruleaza la urmatorul frame al scriptului.
-- ============================================================
Defer = { list = {} }

function Defer.push(fn)
    table.insert(Defer.list, fn)
end

-- jocul e in fata (nu minimizat / alt-tab)? cand nu e, comenzile de client si F8 asteapta
local function gameInFront()
    if type(isGameWindowForeground) == "function" then return isGameWindowForeground() end
    return true
end

function Defer.run()
    if #Defer.list == 0 then return end
    if not gameInFront() then return end   -- se executa cand revii in joc
    local list = Defer.list
    Defer.list = {}
    for _, fn in ipairs(list) do fn() end
end

-- comanda de client SA:MP (/pagesize, /dl): procesata ca si cum ar fi tastata, din bucla principala
local function clientCommand(text)
    Defer.push(function()
        trace("client cmd " .. text)
        sampProcessChatInput(text)
    end)
end

local function applyPagesize()
    local n = tonumber(cfg.main.pagesize) or 0
    if n >= K.PAGESIZE_MIN and n <= K.PAGESIZE_MAX then clientCommand("/pagesize " .. n) end
end

-- apasa F8 (screenshot-ul clientului SA:MP) ca si cum ar fi apasat de la tastatura
pcall(ffi.cdef, [[
    void keybd_event(unsigned char bVk, unsigned char bScan, unsigned long dwFlags, unsigned long dwExtraInfo);
]])
local Shots   -- definit mai jos; anuntat aici ca takeScreenshot sa-i poata spune ce screenshot urmeaza
local function takeScreenshot(label)
    -- firul de executie se porneste din bucla principala, nu din randare
    Defer.push(function()
        Shots.expect(label or Shots.currentLabel())
        lua_thread.create(function()
            trace("F8")
            ffi.C.keybd_event(vkeys.VK_F8, 0, 0, 0)
            wait(60)
            ffi.C.keybd_event(vkeys.VK_F8, 0, 2, 0)   -- 2 = KEYEVENTF_KEYUP
        end)
    end)
end
-- suma licentelor alese (set de id-uri LIC_*): intoarce totalul cu bonusul factiunii si suma de baza
-- (preturile din fisier sunt fara bonus; bonusul se adauga peste ele)
local function subtotal(licIds, level)
    local ids = licIds
    if licIds[K.LIC_ALL] then
        ids = {}
        for _, lic in ipairs(Licenses.real) do ids[lic.id] = true end
    end
    local base, counted = 0, 0
    for id in pairs(ids) do
        local price = licensePrice(Licenses.byId[id], level)
        if price then
            base = base + price
            counted = counted + 1
        end
    end
    if counted == 0 then return nil end
    local total = math.floor(base * (1 + bonusPercent() / 100) + 0.5)
    return total, base
end

-- "$3.600"
local function money(n)
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
    if out:sub(1, 1) == "." then out = out:sub(2) end
    return "$" .. out
end

-- "$1.800 + 100% = $3.600" (sau doar "$1.800" fara bonus)
local function moneyWithBonus(total, base)
    if bonusPercent() > 0 and base then
        return money(base) .. " + " .. bonusPercent() .. "% = " .. money(total)
    end
    return money(total)
end

-- ============================================================
-- LECTII: start / stop, cu automatizarile cerute
-- ============================================================
-- lectia in curs: { id, licId, at }; HP-ul vehiculului se urmareste DOAR in timpul unei lectii de fly / sail
local Lesson = { current = nil }

function Lesson.begin(id, licId)
    Lesson.current = { id = id, licId = licId, at = os.clock() }
end

function Lesson.finish(id)
    if Lesson.current and (not id or Lesson.current.id == id) then Lesson.current = nil end
end

-- e o lectie practica (Flying / Sailing) in curs cu jucatorul dat?
function Lesson.practicalWith(id)
    local l = Lesson.current
    return l ~= nil and l.id == id and (l.licId == K.LIC_FLYING or l.licId == K.LIC_SAILING)
end

-- /startlesson; la lectiile teoretice (intrebari) se pune /pagesize 30 ca sa incapa raspunsurile
local function startLesson(id, lic, theory)
    trace("startlesson " .. tostring(id) .. " " .. tostring(lic.server) .. (theory and " theory" or ""))
    Queue.push("/startlesson " .. id .. " " .. lic.server)
    Lesson.begin(id, lic.id)
    if theory and feat("theoryPagesize") then clientCommand("/pagesize " .. K.THEORY_PAGESIZE) end
    msg(tr("lesson_started", nameTag(id, playerName(id)), lic.label))
end

-- /stoplesson, cu screenshot dupa o secunda (optional) si revenirea la /pagesize-ul din setari
local lastStop = { id = nil, at = 0 }
local function stopLesson(id, immediate)
    -- acelasi jucator, in mai putin de 5 s (manual + automat): o singura data
    if lastStop.id == id and os.clock() - lastStop.at < 5 then return end
    lastStop.id, lastStop.at = id, os.clock()
    trace("stoplesson " .. tostring(id))
    if immediate then Queue.pushFront("/stoplesson " .. id) else Queue.push("/stoplesson " .. id) end
    Lesson.finish(id)
    Candidate.unlock(id)
    Check.mark(id, "finish")
    msg(tr("lesson_stopped", nameTag(id, playerName(id))))
    applyPagesize()



end

-- ============================================================
-- FADE: tranzitii line intre ferestre
-- ============================================================
local Fade = {}

function Fade.new()
    return { alpha = 0 }
end

-- avanseaza alpha spre 1 (vizibil) sau 0 (ascuns); intoarce valoarea curenta
function Fade.step(f, visible)
    local dt = imgui.GetIO().DeltaTime
    if dt <= 0 or dt > 0.1 then dt = 0.016 end
    local target = visible and 1 or 0
    if not feat("fadeAnim") then f.alpha = target return target end
    if f.alpha < target then
        f.alpha = math.min(1, f.alpha + dt * K.FADE_SPEED)
    elseif f.alpha > target then
        f.alpha = math.max(0, f.alpha - dt * K.FADE_SPEED)
    end
    return f.alpha
end

-- ============================================================
-- STARE FERESTRE

-- notificarile (definite mai jos, in sectiunea UI); declarate aici ca sa poata fi folosite de module

State = {
    sih       = new.bool(false),
    sihFade   = Fade.new(),
    tab       = 1,
    sic       = new.bool(false),
    sicFade   = Fade.new(),
    sicTab    = 1,                   -- indexul in Tests, sau K.TAB_LEVEL50
    sicLang   = cfg.main.procLang,   -- comutatorul RO / EN din /sic
    sicCity   = cfg.main.faction,    -- LS / SF / LV pentru flying si sailing
    sicPosDirty = false,
    candBuf   = new.char[8](),       -- campul de ID din /sic
    candShown = nil,                 -- id-ul afisat in camp (ca sa-l actualizam cand se schimba candidatul)
    textInput = false,               -- true cat timp un camp de text imgui are focus
    dialogSeen = false,              -- dialogul curent al serverului a fost deja citit
    uiScale   = 1.0,                 -- scara interfetei fata de 1080p (se recalculeaza dupa rezolutie)
    hiddenTextdraws = {},            -- textdraw-urile serverului cu distanta, ascunse de noi (id -> true)
    acceptedId = nil,                -- ultimul jucator pe care l-am acceptat (pentru stergerea checkpoint-ului)
    hideCandDist = false,            -- randul cu distanta pana la candidat, inchis manual din legenda
    dockCursor = false,              -- tasta "Cursor" e tinuta apasata
    cursorHeldNoWindow = false,      -- ... fara ferestre deschise: apare cursorul (pentru bara de iconite)
    cursorHeldWithWindow = false,    -- ... cu o fereastra deschisa: cursorul dispare (camera / mers), fereastra ramane
    focused   = true,                -- jocul e in fata; cand nu e, nicio fereastra nu e activa (alt-tab crapa cu cursorul pornit)
    acceptSentAt = nil,              -- cand am trimis ultimul /accept needlicense (pentru erori)
    icons     = false,               -- fontul cu iconite s-a incarcat
    pinOk     = false,               -- ti-ai deblocat banii cu /pin in sesiunea asta
    notes     = new.bool(false),     -- fereastra de notite (/notepad)
    notesFade = Fade.new(),
    noteSel   = 1,                   -- folderul deschis in /notepad
    noteEdit  = nil,                 -- notita aflata in editare (index)
}

-- ============================================================
-- FEREASTRA DE INTREBARE (ID si, pentru withme, licentele)
-- ============================================================
local Prompt = {
    open    = new.bool(false),
    fade    = Fade.new(),
    idBuf   = new.char[8](),
    title   = "",
    needLic = false,
    lics    = {},      -- set: [LIC_*] = true
    cb      = nil,     -- function(id, lics)
    focus   = false,
    center  = false,   -- la deschidere se aseaza in centrul ecranului
}

function Prompt.setId(id)
    imgui.StrCopy(Prompt.idBuf, id and tostring(id) or "")
end

function Prompt.currentId()
    return tonumber(ffi.string(Prompt.idBuf))
end

function Prompt.show(opts)
    Prompt.title   = opts.title or "SIC"
    Prompt.needLic = opts.needLic or false
    Prompt.lics    = {}
    Prompt.cb      = opts.cb
    Prompt.focus   = (opts.focus == true)   -- cursorul intra in campul de ID doar la cerere (altfel blocheaza W/A/S/D)
    Prompt.center  = true
    Prompt.setId(opts.id)
    Prompt.open[0] = true
end

function Prompt.close()
    Prompt.open[0] = false
    Prompt.cb = nil
end

function Prompt.toggleLic(licId)
    if Prompt.lics[licId] then
        Prompt.lics[licId] = nil
    elseif licId == K.LIC_ALL then
        Prompt.lics = { [K.LIC_ALL] = true }       -- "toate" exclude restul
    else
        Prompt.lics[K.LIC_ALL] = nil
        Prompt.lics[licId] = true
    end
end

function Prompt.submit()
    local id = requireOnline(ffi.string(Prompt.idBuf))
    if not id then return end
    if Prompt.needLic and next(Prompt.lics) == nil then err(tr("lic_needed")) return end
    local cb, lics = Prompt.cb, Prompt.lics
    Prompt.close()
    if cb then cb(id, lics) end
end

-- ============================================================
-- WITHME
-- trimite /id <id>, asteapta linia cu nivelul, apoi anunta pe /f
-- ============================================================
local Withme = {
    pending = nil,   -- { id, lics, name, at }
    last    = nil,   -- { id, name, level, lics, given } - pentru continuarea automata la 50+
}

-- lista de licente pentru mesajul /f, in formatul folosit de factiune:
-- "Flying license", "Flying, Fishing, Weapon licenses", "all licenses"
local function licensePhrase(lics)
    if lics[K.LIC_ALL] then return "all licenses" end
    local names = {}
    for _, lic in ipairs(Licenses.real) do
        if lics[lic.id] then table.insert(names, lic.server) end
    end
    return table.concat(names, ", ") .. (#names == 1 and " license" or " licenses")
end

-- lista scurta pentru chat / interfata: "Fly, Sail"
local function licenseShortList(lics)
    if lics[K.LIC_ALL] then return Licenses.byId[K.LIC_ALL].short end
    local names = {}
    for _, lic in ipairs(Licenses.real) do
        if lics[lic.id] then table.insert(names, lic.short) end
    end
    return table.concat(names, ", ")
end

function Withme.start(id, lics)
    id = requireOnline(id)
    if not id then return end
    if next(lics) == nil then err(tr("lic_needed")) return end
    if Withme.pending then err(tr("withme_busy")) return end

    Withme.pending = { id = id, lics = lics, name = playerName(id), at = os.clock() }
    -- /id ramane vizibil in chat: instructorul face screenshot ca dovada
    Queue.push("/id " .. id)
end

-- apelat din onServerMessage cand apare linia "| Level: N"
function Withme.onLevel(level)
    local p = Withme.pending
    if not p then return end
    Withme.pending = nil

    local text = string.format(MSG.withme, p.name, p.id, licensePhrase(p.lics))
    if level >= 50 then text = text .. MSG.withme_lvl50 end

    -- /withme seteaza candidatul doar daca nu exista deja unul venit din /accept needlicense (acela are prioritate)
    if Candidate.source ~= "accept" or Candidate.id == p.id then Candidate.set(p.id, p.name, "withme") end
    rememberLevel(p.id, level)
    Withme.last = { id = p.id, name = p.name, level = level, lics = p.lics, given = {} }

    Queue.push("/f " .. text)
    Check.mark(p.id, "announce")
    msg(tr("sent_f", text))

    local total, base = subtotal(p.lics, level)
    if total then
        msg(tr("subtotal_chat", level, moneyWithBonus(total, base)))
    else
        err(tr("subtotal_none", level))
    end
end

function Withme.update()
    local p = Withme.pending
    if p and os.clock() - p.at > K.WITHME_TIMEOUT then
        Withme.pending = nil
        err(tr("withme_timeout"))
    end
end

-- deschide fereastra cu ID + licente
function Withme.ask(prefillId)
    Prompt.show({
        title = "Withme",
        id = prefillId,
        needLic = true,
        cb = function(id, lics) Withme.start(id, lics) end,
    })
end

-- ============================================================
-- SXWAS
-- ============================================================
local function sxwas(id)
    id = requireOnline(id)
    if not id then return end
    local template = MSG.sxwas[Langs.use(id)] or MSG.sxwas[K.LANG_RO]
    local text = string.format(template, playerName(id), id)
    Queue.push("/sx " .. text)
    msg(tr("sent_sx", text))
    -- jucatorul intrebat devine imediat candidatul (in /sic si in /withme), daca nu e altul in lucru
    if Candidate.locked and Candidate.id ~= id then
        msg(tr("cand_locked", nameTag(Candidate.id, Candidate.name)))
    else
        Candidate.set(id, nil, "sxwas")
        if Prompt.open[0] and Prompt.needLic then Prompt.setId(id) end
    end
end


-- ============================================================
-- MESAJE CATRE CANDIDAT: /salut, /pa, /need (pe /w) si SMS-ul automat dupa accept (textele din fisierul de date)
-- ============================================================
local function candidateText(key, id)
    local pack = Data.messages or {}
    local lang = pack[Langs.use(id)] or pack[K.LANG_RO] or {}
    local template = lang[key] or (pack[K.LANG_RO] or {})[key]
    if not template then return nil end
    return (template:gsub("%%s", playerName(id) or "?"))
end

-- trimite unul dintre textele de mai sus pe /w (privat) jucatorului
local function whisper(key, id)
    id = requireOnline(id)
    if not id then return end
    local text = candidateText(key, id)
    if not text then err(tr("data_missing", "messages." .. key)) return end
    Queue.push("/w " .. id .. " " .. text)
    msg(tr("sent_w", nameTag(id, playerName(id)), text))
end

-- SMS-ul de confirmare dupa /accept needlicense: pleaca dupa cateva secunde, daca serverul nu a refuzat acceptul
local Sms = { pending = nil }   -- { id, at }
function Sms.schedule(id) if feat("autoSms") then Sms.pending = { id = id, at = os.clock() } end end
function Sms.cancel() Sms.pending = nil end
function Sms.update()
    local p = Sms.pending
    if not p or os.clock() - p.at < K.SMS_DELAY then return end
    Sms.pending = nil
    local text = candidateText("sms", p.id)
    if not text or not sampIsPlayerConnected(p.id) then return end
    Queue.push("/sms " .. p.id .. " " .. text)
    msg(tr("sent_sms", nameTag(p.id, playerName(p.id))))
end
-- ============================================================
-- DUTY: nu dam licente si nu acceptam /needlicense daca nu suntem la datorie
-- ============================================================
local Duty = {
    state = nil,   -- nil = necunoscut (dupa /reloadall), true = on duty, false = off duty
}

-- schimbarea starii de duty (din mesajele serverului); cu feature-ul "Ferestre la duty" pornit,
-- ferestrele alese se deschid cand intram la datorie si se inchid cand iesim
function Duty.set(state)
    local before = Duty.state
    Duty.state = state
    if before == state or not feat("dutyWindows") then return end
    local dept = App and App.PD and App.PD.isDept()
    if state == true then
        if feat("dutyWinSic")    then if dept then App.PD.open[0] = true else State.sic[0] = true end end
        if feat("dutyWinReport") then Report.open[0] = true end
        if feat("dutyWinWithme") then Withme.ask(Candidate.get() or nearestPlayer()) end
    elseif before == true then
        if feat("dutyWinSic")    then if dept then App.PD.open[0] = false else State.sic[0] = false end end
        if feat("dutyWinReport") then Report.open[0] = false end
        if feat("dutyWinWithme") then Prompt.close() end
    end
end

-- true daca putem continua; altfel afiseaza eroarea si intoarce false
function Duty.require()
    if Duty.state == false then
        err(tr("not_on_duty"))
        return false
    end
    return true
end

-- ============================================================
-- GIVELICENSE (tab-ul 50+)
-- ============================================================
local Give = {
    -- lantul de licente in curs: { id, name, rest = {licId...}, at }
    -- urmatoarea se trimite abia dupa ce serverul confirma ca a fost acceptata precedenta
    chain = nil,
}

local lastGive = { key = nil, at = 0 }
function Give.one(id, licId)
    if not Duty.require() then return false end
    -- aceeasi licenta, aceluiasi jucator, in mai putin de 3 s: o singura data (click repetat)
    local key = id .. ":" .. licId
    if lastGive.key == key and os.clock() - lastGive.at < 3 then return true end
    lastGive.key, lastGive.at = key, os.clock()
    local lic = Licenses.byId[licId]
    Queue.push("/givelicense " .. id .. " " .. lic.server)
    -- raportul NU creste aici: punctul se ia abia cand jucatorul accepta licenta (vezi Give.onAccepted)
    Check.mark(id, "finish")
    msg(tr("given", lic.label, nameTag(id, playerName(id))))
    return true
end

local function shortNames(licIds)
    local names = {}
    for _, licId in ipairs(licIds) do table.insert(names, Licenses.byId[licId].short) end
    return table.concat(names, ", ")
end

-- porneste un lant: prima licenta pleaca acum, restul pe rand, dupa fiecare acceptare
function Give.startChain(id, licIds)
    if #licIds == 0 then return end
    if not feat("chain50") then
        -- fara lant: toate licentele pleaca acum, esalonate doar de pauza dintre mesaje
        for _, licId in ipairs(licIds) do if not Give.one(id, licId) then return end end
        return
    end
    local first = table.remove(licIds, 1)
    if not Give.one(id, first) then return end
    if #licIds == 0 then Give.chain = nil return end
    -- "sent" = licenta pe care o asteptam acceptata; lantul avanseaza doar la confirmarea EI
    Give.chain = { id = id, name = playerName(id) or "?", sent = first, rest = licIds, at = os.clock() }
    msg(tr("chain_wait", nameTag(id, Give.chain.name), shortNames(licIds)))
end


-- da o licenta si, daca jucatorul a fost anuntat cu /withme la 50+,
-- continua cu restul licentelor din acel /withme (una cate una, dupa acceptare)
function Give.withWithme(id, licId)
    local w = Withme.last
    if not (w and w.id == id and w.level >= 50) then
        Give.one(id, licId)
        return
    end
    local wanted = w.lics
    if wanted[K.LIC_ALL] then
        wanted = {}
        for _, lic in ipairs(Licenses.real) do wanted[lic.id] = true end
    end
    w.given[licId] = true
    local list = { licId }
    for _, lic in ipairs(Licenses.real) do
        if wanted[lic.id] and not w.given[lic.id] then
            w.given[lic.id] = true
            table.insert(list, lic.id)
        end
    end
    Give.startChain(id, list)
end

-- "toate licentele": daca jucatorul a fost anuntat cu /withme, DOAR cele din /withme; altfel toate cinci
function Give.all(id)
    local w = Withme.last
    local wanted = nil
    if w and w.id == id and not w.lics[K.LIC_ALL] then wanted = w.lics end
    local list = {}
    for _, lic in ipairs(Licenses.real) do
        if not wanted or wanted[lic.id] then table.insert(list, lic.id) end
    end
    if w and w.id == id then
        for _, licId in ipairs(list) do w.given[licId] = true end
    end
    Give.startChain(id, list)
end

-- ============================================================
-- /giveme: licentele pentru tine (renew). Trimite /givelicense pe propriul id, iar cand serverul
-- ti le ofera, raspunde singur cu /accept license (ca in SIHelper by AdeM).
-- ============================================================
function Give.me(lics)
    if not Duty.require() then return end
    local myId = myPlayerId()
    if not myId then err(tr("giveme_noid")) return end
    local wanted = {}
    if lics[K.LIC_ALL] then
        for _, lic in ipairs(Licenses.real) do table.insert(wanted, lic) end
    else
        for _, lic in ipairs(Licenses.real) do if lics[lic.id] then table.insert(wanted, lic) end end
    end
    if #wanted == 0 then err(tr("bad_lic")) return end
    Give.meId, Give.meUntil = myId, os.clock() + K.GIVEME_WINDOW * #wanted
    Withme.pending = nil          -- /giveme nu e o lectie: nu se anunta nimic pe /f si nu se schimba candidatul
    for _, lic in ipairs(wanted) do
        Queue.push("/givelicense " .. myId .. " " .. lic.server)
    end
    trace("giveme " .. myId .. ": " .. licenseShortList(lics))
    msg(tr("giveme_started", licenseShortList(lics)))
end

-- serverul ti-a oferit o licenta: o acceptam singuri, cat timp e un /giveme in curs
function Give.meOffered()
    if not Give.meId or not Give.meUntil or os.clock() > Give.meUntil then return end
    Queue.push("/accept license " .. Give.meId)
end

-- licenta mentionata intr-o linie a serverului (RO sau EN), sau nil
local LICENSE_WORDS = {
    { K.LIC_FLYING,    "flying",    "pilot"     },
    { K.LIC_SAILING,   "sailing",   "navigatie" },
    { K.LIC_FISHING,   "fishing",   "pescar"    },
    { K.LIC_WEAPONS,   "weapon",    "port-arma" },
    { K.LIC_MATERIALS, "materials", "materiale" },
}
local function licenseInText(text)
    local low = text:lower()
    for _, w in ipairs(LICENSE_WORDS) do
        if low:find(w[2], 1, true) or low:find(w[3], 1, true) then return w[1] end
    end
    return nil
end
-- serverul a confirmat o licenta acordata (linia intreaga)
function Give.onAccepted(text)
    trace("accepted: " .. tostring(text))
    -- licenta primita in urma unui /giveme e a mea: fara stoplesson, fara lant, fara raport
    if Give.meUntil and os.clock() <= Give.meUntil then return end
    local id = findPlayerInText(text)
    -- formularea "Instructorul X ti-a acordat Licenta..." contine doar numele nostru: jucatorul e
    -- candidatul (sau cel din lantul 50+), nu noi
    local myId = myPlayerId()
    if id == myId then id = (Give.chain and Give.chain.id) or Candidate.get() end

    if id and State.acceptedId == id then State.acceptedId = nil end   -- lectia lui s-a incheiat
    local lic = licenseInText(text)
    -- punctul din raport se ia in acest moment: jucatorul a acceptat licenta
    if id then Report.countGiven(id) end
    if id and lic and App and App.Info then
        App.Info.remember(playerName(id), lic)
        App.Ally.onGiven(id, playerName(id), lic)   -- factiune aliata: banii se dau inapoi
    end
    -- candidatul se deblocheaza cand nu mai are licente de primit (fara lant in curs pentru el)
    if id and not (Give.chain and Give.chain.id == id) then Candidate.unlock(id) end

    -- lantul de la 50+: urmatoarea licenta, dar numai daca s-a acceptat cea trimisa de lant
    local c = Give.chain
    if c and id == c.id then
        if lic and c.sent and lic ~= c.sent then return end   -- alta licenta (data manual): nu e randul lantului
        local nextLic = table.remove(c.rest, 1)
        c.sent = nextLic
        Give.one(c.id, nextLic)
        c.at = os.clock()
        if #c.rest == 0 then
            Give.chain = nil
            msg(tr("chain_done"))
        end
        return   -- la 50+ nu exista lectie de oprit
    end

    -- sub nivel 50: lectia se opreste imediat ce licenta a fost acceptata
    if (tonumber(cfg.main.autoStoplesson) or 0) ~= 1 then return end
    if not id then return end
    local level = playerLevel(id) or 0
    local w = Withme.last
    if w and w.id == id then level = w.level end
    if level < 50 then stopLesson(id, true) end
end

function Give.update()
    local c = Give.chain
    if c and os.clock() - c.at > K.GIVE_TIMEOUT then
        Give.chain = nil
        err(tr("chain_timeout", K.GIVE_TIMEOUT))
    end
end

-- ============================================================
-- REPAIR / REFILL
-- daca avem deja jobul de mecanic: /repair, /refill; altfel /switchjob pana devenim mecanic,
-- /repair, /refill, apoi /switchjob inapoi la jobul dinainte
-- ============================================================
local RR = {
    job      = nil,     -- ultimul job anuntat de server ("Mecanic", "Detectiv"...), nil = necunoscut
    active   = false,
    switched = 0,       -- de cate ori am dat /switchjob in aceasta rulare
    at       = 0,
}
K.RR_MAX_SWITCHES = 3
K.RR_TIMEOUT      = 15

local function isMechanicJob(job)
    if not job then return false end
    for _, name in ipairs(SERVER.JOB_MECHANIC) do
        if job:find(name, 1, true) then return true end
    end
    return false
end

-- repair + refill, esalonate ca serverul sa le accepte; switchBack = mai dam un /switchjob la final
local function repairRefillNow(switchBack)
    Queue.push("/repair", K.RR_STEP_DELAY)
    Queue.push("/refill", K.RR_STEP_DELAY)
    if switchBack then Queue.push("/switchjob", K.RR_STEP_DELAY) end
    RR.active = false
    -- fara mesaje in chat: comanda e tacuta
end

function RR.start()
    if RR.active then return end
    if isMechanicJob(RR.job) then
        repairRefillNow(false)
        return
    end
    RR.active, RR.switched, RR.at = true, 1, os.clock()
    Queue.push("/switchjob", K.RR_STEP_DELAY)
end

-- serverul a anuntat un job nou
function RR.onJob(job)
    RR.job = job
    if not RR.active then return end
    if isMechanicJob(job) then
        repairRefillNow(true)
    elseif RR.switched < K.RR_MAX_SWITCHES then
        RR.switched = RR.switched + 1
        Queue.push("/switchjob", K.RR_STEP_DELAY)
    else
        RR.active = false
        -- tacut: fara mesaj in chat
    end
end

-- serverul nu ne lasa /switchjob: incercam direct
function RR.onNoSwitch()
    if not RR.active then return end
    repairRefillNow(false)
end

function RR.update()
    if RR.active and os.clock() - RR.at > K.RR_TIMEOUT then
        RR.active = false
        -- tacut: fara mesaj in chat
    end
end

-- ============================================================
-- HP-UL VEHICULULUI CANDIDATULUI (Flying / Sailing): live, cu avertisment sub 950
-- ============================================================
K.HP_FAIL = 950.0

local Vehicle = {
    hp     = nil,      -- HP-ul curent al vehiculului candidatului, nil = nu e in vehicul / nu e in raza
    warned = false,    -- am avertizat deja pentru scaderea sub 950 (se reseteaza cand urca la loc)
}

-- se apeleaza din bucla principala, nu din randare
function Vehicle.update()
    local id = Candidate.get()
    if not feat("hpMonitor") or not id or not Lesson.practicalWith(id) then Vehicle.hp = nil return end
    -- de 4 ori pe secunda e suficient; fiecare apel in plus catre joc e un risc in plus
    local now = os.clock()
    if Vehicle.nextAt and now < Vehicle.nextAt then return end
    Vehicle.nextAt = now + 0.25

    -- fara opcode-uri de joc pe ped-ul altui jucator (crapa jocul): citim direct din memorie
    -- CPed + 0x58C = pointer la vehiculul in care e; CVehicle + 0x4C0 = HP (float)
    local ok, ped = sampGetCharHandleBySampPlayerId(id)
    if not ok or not doesCharExist(ped) then Vehicle.hp = nil return end
    local pedPtr = getCharPointer(ped)
    if not pedPtr or pedPtr == 0 then Vehicle.hp = nil return end
    local vehPtr = readMemory(pedPtr + 0x58C, 4, false)
    if not vehPtr or vehPtr == 0 then Vehicle.hp = nil return end
    if not Vehicle.tracedIn then Vehicle.tracedIn = true; trace("vehicle: candidat in vehicul, citesc HP din memorie") end
    local hp = representIntAsFloat(readMemory(vehPtr + 0x4C0, 4, false))
    if not hp or hp ~= hp or hp < 0 or hp > 5000 then Vehicle.hp = nil return end   -- valoare imposibila = pointer gresit
    Vehicle.hp = hp
    if hp < K.HP_FAIL and not Vehicle.warned then
        Vehicle.warned = true
        err(tr("hp_fail", nameTag(id, playerName(id)), math.floor(hp)))
        Notify.push(playerName(id) or "?", tr("hp_fail_short", math.floor(hp)))
    elseif hp >= K.HP_FAIL then
        Vehicle.warned = false
    end
end

-- ============================================================
-- SCREENSHOT-URI: redenumire in loc (acelasi folder), SIC_Nume_Licenta_data.png
-- SA:MP salveaza sa-mp-NNN.png in Documents\GTA San Andreas User Files\SAMP\screens
-- ============================================================
Shots = {
    folder   = nil,
    nextFree = 0,       -- cel mai mic numar sa-mp-NNN liber: SA:MP salveaza urmatorul screenshot acolo
    pending  = nil,     -- { label, at } - asteptam fisierul nou
}

local function shotPath(i)
    return Shots.folder .. "\\" .. string.format("sa-mp-%03d.png", i)
end

-- primul numar liber incepand de la "from" (SA:MP umple golurile de jos in sus)
function Shots.firstFreeFrom(from)
    for i = from, 9999 do
        if not doesFileExist(shotPath(i)) then return i end
    end
    return from
end

function Shots.init()
    trace("shots.init")
    local docs = getFolderPath(0x05)   -- My Documents
    local folder = docs .. "\\GTA San Andreas User Files\\SAMP\\screens"
    if not doesDirectoryExist(folder) then folder = getGameDirectory() end
    Shots.folder = folder
    Shots.nextFree = Shots.firstFreeFrom(0)
    trace("shots: folder " .. folder .. ", urmatorul screenshot = sa-mp-" .. Shots.nextFree)
end

-- text sigur pentru un nume de fisier
local function safeName(s)
    return (tostring(s or ""):gsub("[^%w%._%-%[%]]", "_"))
end

-- anunta ca urmeaza un screenshot; label = "Nume_Licenta"
-- sufixul dupa ultima linie recunoscuta din chat: citim de jos (cea mai noua) in sus
-- si ne oprim la prima linie care contine un text din data.screenshots
function Shots.chatSuffix()
    local markers = Data.screenshots
    if type(markers) ~= "table" or #markers == 0 then return nil end
    for line = 99, 0, -1 do
        local text = sampGetChatString(line)
        if text and text ~= "" then
            local low = text:lower()
            for _, m in ipairs(markers) do
                for _, needle in ipairs(m.find or {}) do
                    if low:find(needle:lower(), 1, true) then return m.suffix end
                end
            end
        end
    end
    return nil
end

-- anunta ca urmeaza un screenshot facut din helper; label = "Nume_Licenta"
function Shots.expect(label)
    if not feat("shotRename") or not Shots.folder then return end
    if Shots.pending then return end
    local suffix = Shots.chatSuffix()
    Check.onShot(suffix)
    Shots.pending = { label = safeName(label), suffix = suffix and safeName(suffix) or nil, at = os.clock() }
    trace("shots: astept sa-mp-" .. Shots.nextFree .. " (" .. Shots.pending.label .. (suffix and ("_" .. suffix) or "") .. ")")
end

-- eticheta implicita: candidatul curent + tab-ul din /sic
function Shots.currentLabel()
    local id, name = Candidate.get()
    local lic = "test"
    if State.sicTab == K.TAB_LEVEL50 then
        lic = "Level50"
    elseif Tests[State.sicTab] then
        lic = Licenses.byId[Tests[State.sicTab].licId].label
    end
    return (name ~= "" and name or (id and tostring(id) or "fara_candidat")) .. "_" .. lic
end

-- marimea unui fisier, sau nil daca nu poate fi deschis (inca se scrie)
local function fileSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local size = f:seek("end")
    f:close()
    return size
end

function Shots.update()
    local p = Shots.pending
    if not p then return end
    local now = os.clock()
    -- verificam rar (de 4 ori pe secunda), nu la fiecare frame
    if p.nextAt and now < p.nextAt then return end
    p.nextAt = now + 0.25
    local age = now - p.at
    if age < 0.5 then return end                 -- fisierul se scrie dupa apasare
    if age > 8 then
        Shots.pending = nil
        err(tr("shot_notfound", Shots.folder))
        return
    end

    -- cautam fisierul nou
    if not p.file then
        for i = Shots.nextFree, Shots.nextFree + 10 do
            if doesFileExist(shotPath(i)) then
                Shots.nextFree = Shots.firstFreeFrom(i + 1)
                p.file = shotPath(i)
                p.size = nil
                break
            end
        end
        if not p.file then return end
    end

    -- redenumim abia cand SA:MP a terminat de scris: marimea nu s-a schimbat intre doua verificari
    local size = fileSize(p.file)
    if not size or size == 0 or size ~= p.size then
        p.size = size
        return
    end

    Shots.pending = nil
    -- SIC_Nume_Licenta_data[_sufix].png
    local base = Shots.folder .. "\\SIC_" .. p.label .. "_" .. os.date("%Y-%m-%d_%H-%M-%S")
    local tail = p.suffix and ("_" .. p.suffix) or ""
    local new = base .. tail .. ".png"
    local n = 1
    while doesFileExist(new) do
        new = base .. "_" .. n .. tail .. ".png"
        n = n + 1
    end
    trace("rename " .. p.file .. " -> " .. new)
    local ok = os.rename(p.file, new)
    if ok then msg(tr("shot_renamed", new:match("([^\\]+)$"))) end
end

-- ============================================================
-- FVR: anunt pe /f (si /sx), numaratoare, /fvr, confirmare pe /sx
-- ============================================================
local FVR = {
    active = false,
    at     = 0,
}

function FVR.start()
    if not feat("fvrOn") then err(tr("fvr_off")) return end
    if FVR.active then err(tr("fvr_busy")) return end
    local seconds = math.max(5, math.min(60, tonumber(cfg.fvr.seconds) or 10))
    local startText = tostring(cfg.fvr.startText or "")
    if startText == "" then err(tr("fvr_notext")) return end
    -- departamentele anunta pe /r (radio) si /d; restul factiunilor pe /f si /sx
    local dept = App and App.PD and App.PD.isDept()
    Queue.push((dept and "/r " or "/f ") .. startText)
    local sx = tostring(cfg.fvr.sxText or "")
    if sx ~= "" then Queue.push((dept and "/d " or "/sx ") .. sx) end
    FVR.active, FVR.at, FVR.seconds = true, os.clock(), seconds
    msg(tr("fvr_started", seconds))
end

function FVR.stop()
    if not FVR.active then err(tr("fvr_none")) return end
    FVR.active = false
    msg(tr("fvr_stopped"))
end

function FVR.update()
    if not FVR.active then return end
    if os.clock() - FVR.at < FVR.seconds then return end
    FVR.active = false
    Queue.push("/fvr")
    local endText = tostring(cfg.fvr.endText or "")
    if endText ~= "" then Queue.push(((App and App.PD and App.PD.isDept()) and "/d " or "/sx ") .. endText) end
end

-- ============================================================
-- RAPORT SAPTAMANAL: dialogul de la /raport, parsat si afisat in fereastra noastra
-- ============================================================
Report = {
    open     = new.bool(false),
    fade     = Fade.new(),
    data     = nil,        -- { daysLeft, progress = {done,total,status}, bonus = {done,total,status}, rankupDays, at }
    session  = { low = 0, high = 0 },   -- licente acceptate in sesiunea asta: sub 50 / 50+
}

-- parseaza textul dialogului "[Nume] - Faction Report"; intoarce true daca a fost acel dialog
function Report.parse(title, text)
    if not title or not title:find("Faction Report", 1, true) then return false end
    local clean = text:gsub("{%x%x%x%x%x%x}", "")
    local d = { at = os.clock() }
    d.daysLeft = tonumber(clean:match("Timp ramas:%s*(%d+)"))
    local pStatus, pRest = clean:match("Progres[^\n]-%(([^)]+)%)[^\n]*\n([^\n]*)")
    if pRest then
        local done, total = pRest:match("(%d+)%s*/%s*(%d+)")
        d.progress = { status = pStatus, done = tonumber(done), total = tonumber(total) }
    end
    local bStatus, bRest = clean:match("Bonus[^\n]-%(([^)]+)%)[^\n]*\n([^\n]*)")
    if bRest then
        local done, total = bRest:match("(%d+)%s*/%s*(%d+)")
        d.bonus = { status = bStatus, done = tonumber(done), total = tonumber(total) }
    end
    d.rankupDays = tonumber(clean:match("Rank UP lider:%s*(%d+)"))
    Report.data = d
    Report.save()
    return true
end

-- datele raportului se tin si in ini, ca sa ramana intre sesiuni (pana la urmatorul /raport)
function Report.save()
    local d = Report.data
    if not d then return end
    cfg.report.daysLeft   = d.daysLeft or -1
    cfg.report.progDone   = d.progress and d.progress.done or -1
    cfg.report.progTotal  = d.progress and d.progress.total or -1
    cfg.report.bonusDone  = d.bonus and d.bonus.done or -1
    cfg.report.bonusTotal = d.bonus and d.bonus.total or -1
    cfg.report.rankupDays = d.rankupDays or -1
    cfg.report.savedAt    = os.time()
    saveCfg()
end

function Report.load()
    local r = cfg.report
    if not r or (tonumber(r.progTotal) or -1) < 0 then return end
    local function n(v) v = tonumber(v) if v and v >= 0 then return v end return nil end
    Report.data = {
        at = os.clock(), fromIni = true,
        daysLeft = n(r.daysLeft), rankupDays = n(r.rankupDays),
        progress = { done = n(r.progDone) or 0, total = n(r.progTotal) },
        bonus    = n(r.bonusTotal) and { done = n(r.bonusDone) or 0, total = n(r.bonusTotal) } or nil,
    }
end

-- o licenta data = o "actiune in factiune": crestem raportul local pana la urmatorul /raport
-- intra licenta in raportul saptamanal? Serverul nu pune la socoteala licentele date jucatorilor
-- de nivel mic (1) si nici pe cele de la 50+. Pragurile sunt in fisierul de date.
function Report.counts(level)
    if not level or level <= 0 then return true end    -- nivel necunoscut: numaram, sa nu pierdem progres
    local lv = Data and Data.report_levels
    local min = (lv and tonumber(lv.min)) or 2
    local max = (lv and tonumber(lv.max)) or 49
    return level >= min and level <= max
end

-- o licenta in plus in raport. Fiecare contor se opreste la maxim: cand progresul e plin (10/10),
-- ce urmeaza nu se mai aduna acolo, ci doar la bonus.
function Report.bump(level)
    local d = Report.data
    if not d then return end
    if not Report.counts(level) then
        trace("raport: licenta la nivel " .. tostring(level) .. " nu intra in raport")
        return
    end
    local function add(c)
        if not c then return end
        local done, total = tonumber(c.done) or 0, tonumber(c.total)
        if total and done >= total then return end     -- plin: ramane asa
        c.done = done + 1
    end
    add(d.progress)
    add(d.bonus)
    Report.save()
end
-- o licenta data (/givelicense trimis): o numaram dupa nivelul jucatorului
function Report.countGiven(id)
    local level = playerLevel(id) or 0
    local w = Withme.last
    if w and w.id == id then level = w.level end
    if level >= 50 then Report.session.high = Report.session.high + 1
    else Report.session.low = Report.session.low + 1 end
    Report.bump(level)
end

-- ============================================================
-- CHECKLIST DOVEZI: pasii unei licente, bifati automat + screenshot-urile facute
-- ============================================================
local CHECK_STEPS = { "accept", "request", "announce", "answer", "finish" }
-- sufixul de screenshot care corespunde fiecarui pas
local CHECK_SUFFIX = { needlicense = "accept", requestlicenses = "request", fannounce = "announce", givelicense = "finish" }

Check = {
    forId  = nil,      -- candidatul pentru care e lista
    done   = {},       -- [step] = true
    shot   = {},       -- [step] = true (screenshot facut la acel pas)
    asked  = false,    -- am trimis cel putin o intrebare / task (pentru pasul "answer")
}

function Check.reset(id)
    Check.forId, Check.done, Check.shot, Check.asked = id, {}, {}, false
    Check.hiddenFor = nil   -- candidat nou: panoul de dovezi reapare
end

-- pasul e valabil pentru candidatul curent?
local function checkFor(id)
    if not feat("checklist") then return false end
    if Check.forId ~= id then Check.reset(id) end
    return true
end

function Check.mark(id, step)
    if not id or not checkFor(id) then return end
    if not Check.done[step] then
        Check.done[step] = true
        trace("checklist: " .. step)
    end
end

-- ðŸ“· apasat cu sufixul dat in chat: bifam screenshot-ul pasului potrivit
-- am trimis o intrebare / un task candidatului
function Check.markAsked(id)
    if checkFor(id) then Check.asked = true end
end

function Check.onShot(suffix)
    local id = Candidate.get()
    if not id or not checkFor(id) then return end
    local step = suffix and CHECK_SUFFIX[suffix]
    if not step and Check.done.answer and not Check.done.finish then step = "answer" end
    if step then Check.shot[step] = true end
end

function Check.count()
    local n = 0
    for _, s in ipairs(CHECK_STEPS) do if Check.done[s] then n = n + 1 end end
    return n, #CHECK_STEPS
end

-- ============================================================
-- ACTIUNI
-- fiecare actiune are un id folosit si in config (<id>_key etc.)
-- ============================================================
local Actions = {}

local function actionLabel(a)
    return (cfg.main.uiLang == K.LANG_EN) and a.label_en or a.label_ro
end

-- ultimul /needlicense vazut (id, nume) - tinta pentru accept; candidatul se seteaza abia la acceptare
local LastNeed = { id = nil, name = nil }

-- id-ul precompletat in fereastra "cere ID"
local function prefillFor(action)
    if action.id == "acc" and LastNeed.id then return LastNeed.id end
    if action.prefill == K.TARGET_NEAR then return nearestPlayer() or Candidate.get() end
    return Candidate.get() or nearestPlayer()
end

-- trimite /accept needlicense; cu "Candidat automat" pornit, jucatorul devine candidatul in acest moment
local function sendAccept(id)
    if not Duty.require() then return end
    -- cu un checkpoint activ, acceptul pune altul peste: il stergem intai (comenzile sunt in fisierul de date)
    if State.checkpoint and feat("clearCp") then
        for _, c in ipairs(Data.clear_checkpoint or { "/killcp" }) do Queue.push(c) end
    end
    Queue.push("/accept needlicense " .. id)
    Check.mark(id, "accept")
    State.acceptSentAt = os.clock()
    State.acceptedId = id            -- pe cine am acceptat: daca cererea e luata de altcineva, stergem checkpoint-ul lui
    Sms.schedule(id)
    if not feat("autoCandidate") then return end
    if Candidate.locked and Candidate.id ~= id then msg(tr("cand_locked", nameTag(Candidate.id, Candidate.name))) return end
    Candidate.set(id, LastNeed.id == id and LastNeed.name or nil, "accept")
    -- fereastra /withme deschisa in acel moment: ii punem si ei noul ID
    if Prompt.open[0] and Prompt.needLic then Prompt.setId(id) end
end

-- obtine id-ul tinta conform setarii actiunii si apeleaza cb(id)
local function resolveTarget(action, cb)
    local mode = cfg.binds[action.id .. "_target"] or K.TARGET_NONE
    if mode == K.TARGET_NONE then return cb(nil) end
    if mode == K.TARGET_LAST then
        -- pentru accept, "ultimul" e ultimul /needlicense; pentru restul, candidatul
        local id = (action.id == "acc") and (LastNeed.id or Candidate.get()) or Candidate.get()
        if not id then err(tr(action.id == "acc" and "no_need" or "no_candidate")) return end
        return cb(id)
    end
    if mode == K.TARGET_NEAR then
        local id = nearestPlayer()
        if not id then err(tr("no_near", K.NEAR_DISTANCE)) return end
        return cb(id)
    end
    -- K.TARGET_ASK: fereastra, cu un id precompletat
    Prompt.show({
        title = actionLabel(action),
        id = prefillFor(action),
        needLic = false,
        focus = true,     -- aici chiar se cere un ID tastat
        cb = function(id) cb(id) end,
    })
end

Actions.list = {
    {
        id = "acc", prefill = K.TARGET_LAST,
        label_ro = "Accept needlicense", label_en = "Accept needlicense",
        hint = "/accept needlicense <id>",
        run = function(a)
            resolveTarget(a, function(id)
                trace("accept (bind) " .. tostring(id))
                sendAccept(id)
            end)
        end,
    },
    {
        id = "rl", prefill = K.TARGET_LAST,
        label_ro = "Cere licentele", label_en = "Request licenses",
        hint = "/requestlicenses <id>",
        run = function(a) resolveTarget(a, function(id) Queue.push("/requestlicenses " .. id) end) end,
    },
    {
        id = "sl", prefill = K.TARGET_LAST,
        label_ro = "Opreste lectia", label_en = "Stop lesson",
        hint = "/stoplesson <id>",
        run = function(a) resolveTarget(a, function(id) Queue.push("/stoplesson " .. id) end) end,
    },
    {
        id = "wm", prefill = K.TARGET_LAST, group = "hud",
        label_ro = "Arata / ascunde /withme", label_en = "Toggle /withme",
        hint = "/withme",
        -- comutator: inchide fereastra daca e deschisa; altfel o deschide cu id-ul dupa tinta
        run = function(a)
            if Prompt.open[0] then Prompt.close() return end
            local mode = cfg.binds[a.id .. "_target"]
            local id = nil
            if mode == K.TARGET_LAST then id = Candidate.get() end
            if mode == K.TARGET_NEAR then id = nearestPlayer() end
            if mode == K.TARGET_ASK  then id = prefillFor(a) end
            Withme.ask(id)
        end,
    },
    {
        id = "sx", prefill = K.TARGET_NEAR,
        label_ro = "Sxwas", label_en = "Sxwas",
        hint = "/sxwas <id>",
        run = function(a) resolveTarget(a, function(id) sxwas(id) end) end,
    },
    {
        id = "salut", prefill = K.TARGET_LAST,
        label_ro = "Salut candidat (/w)", label_en = "Greet candidate (/w)",
        hint = "/salut <id>",
        run = function(a) resolveTarget(a, function(id) whisper("salut", id or Candidate.get()) end) end,
    },
    {
        id = "pa", prefill = K.TARGET_LAST,
        label_ro = "La revedere (/w)", label_en = "Goodbye (/w)",
        hint = "/pa <id>",
        run = function(a) resolveTarget(a, function(id) whisper("pa", id or Candidate.get()) end) end,
    },
    {
        id = "need", prefill = K.TARGET_NEAR,
        label_ro = "Intreaba de licente (/w)", label_en = "Ask about licenses (/w)",
        hint = "/need <id>",
        run = function(a) resolveTarget(a, function(id) whisper("need", id or nearestPlayer()) end) end,
    },
    {
        id = "ok", prefill = K.TARGET_LAST,
        label_ro = "Felicitari, ai trecut (/w)", label_en = "Congrats, you passed (/w)",
        hint = "/ok <id>",
        run = function(a) resolveTarget(a, function(id) whisper("ok", id or Candidate.get()) end) end,
    },
    {
        id = "duty",
        label_ro = "Duty (/duty)", label_en = "Duty (/duty)",
        hint = "/duty",
        run = function() Queue.push("/duty") end,
    },
    {
        id = "rr",
        label_ro = "Repair / Refill", label_en = "Repair / Refill",
        hint = "/repair + /refill",
        run = function() RR.start() end,
    },
    {
        id = "fvr",
        label_ro = "FVR", label_en = "FVR",
        hint = "/ffvr",
        run = function() FVR.start() end,
    },
    {
        id = "notif", group = "hud",
        label_ro = "Inchide notificarea", label_en = "Dismiss notification",
        hint = "-",
        run = function() Notify.dismiss(1) end,
    },
    {
        id = "sic", group = "hud",
        label_ro = "Arata / ascunde statia (/sic sau /pdc)", label_en = "Toggle the station (/sic or /pdc)",
        hint = "/sic  /pdc",
        -- statia factiunii tale: /sic la School Instructors, /pdc la departamente
        run = function()
            if App.PD and App.PD.isDept() then App.PD.toggle() else State.sic[0] = not State.sic[0] end
        end,
    },
    {
        id = "sih", group = "hud",
        label_ro = "Arata / ascunde /sih", label_en = "Toggle /sih",
        hint = "/sih",
        run = function() State.sih[0] = not State.sih[0] end,
    },
    {
        id = "note", group = "hud",
        label_ro = "Arata / ascunde notitele", label_en = "Toggle notepad",
        hint = "/notepad",
        run = function() State.notes[0] = not State.notes[0] end,
    },
    {
        id = "info", prefill = K.TARGET_NEAR, group = "hud",
        label_ro = "Fereastra /info", label_en = "Info window",
        hint = "/info <id>",
        run = function(a) resolveTarget(a, function(id) App.Info.show(id or nearestPlayer()) end) end,
    },
    {
        id = "raport", group = "hud",
        label_ro = "Arata / ascunde /raport", label_en = "Toggle /raport",
        hint = "/sicraport",
        run = function() Report.open[0] = not Report.open[0] end,
    },
    {
        id = "closeall", group = "hud",
        label_ro = "Inchide toate ferestrele", label_en = "Close all windows", short_ro = "Inchide tot", short_en = "Close all",
        hint = "-",
        run = function() Actions.closeAll() end,
    },
    {
        id = "cursor", group = "hud",
        label_ro = "Cursor (tine apasat): il arata fara ferestre / il ascunde cu ferestre", label_en = "Cursor (hold): show it with no windows / hide it with windows open",
        short_ro = "Cursor (tine apasat)", short_en = "Cursor (hold)",
        hint = "-",
        run = function() end,   -- se foloseste prin tinere apasata (vezi Keys.update), nu prin apasare
    },
}

Actions.byId = {}
for _, a in ipairs(Actions.list) do Actions.byId[a.id] = a end

-- actiunile doar de instructor: la departamente nu se mai arata in /sih (tastele deja puse merg in continuare)
K.SI_ONLY = { acc = true, rl = true, sl = true, wm = true, sx = true, salut = true, pa = true, need = true, ok = true }
-- actiunea se arata in /sih pentru factiunea aleasa?
function Actions.visible(a)
    local dept = App.PD ~= nil and App.PD.isDept()
    if dept and K.SI_ONLY[a.id] then return false end
    if a.show and not a.show() then return false end
    return true
end

-- ============================================================
-- BIND-URI PERSONALIZATE
-- stocate plat in ini: c1_cmd / c1_key / c1_on ...
-- ============================================================
local Custom = {}

function Custom.count()
    return tonumber(cfg.custom.count) or 0
end

function Custom.get(i)
    return {
        cmd = tostring(cfg.custom["c" .. i .. "_cmd"] or "/comanda"),
        key = tostring(cfg.custom["c" .. i .. "_key"] or "None"),   -- ini poate intoarce un numar ("5")
        on  = tonumber(cfg.custom["c" .. i .. "_on"]) or 1,
    }
end

function Custom.set(i, data)
    cfg.custom["c" .. i .. "_cmd"] = data.cmd
    cfg.custom["c" .. i .. "_key"] = data.key
    cfg.custom["c" .. i .. "_on"]  = data.on
end

function Custom.add()
    local n = Custom.count()
    if n >= K.MAX_CUSTOM_BINDS then return false end
    n = n + 1
    cfg.custom.count = n
    Custom.set(n, { cmd = "/comanda", key = "None", on = 1 })
    saveCfg()
    return true
end

function Custom.remove(idx)
    local n = Custom.count()
    if idx < 1 or idx > n then return end
    for i = idx, n - 1 do
        Custom.set(i, Custom.get(i + 1))
    end
    cfg.custom["c" .. n .. "_cmd"] = nil
    cfg.custom["c" .. n .. "_key"] = nil
    cfg.custom["c" .. n .. "_on"]  = nil
    cfg.custom.count = n - 1
    saveCfg()
end

-- ============================================================
-- SISTEM DE TASTE
-- ============================================================
local Keys = {
    capturing = nil,   -- "a:acc" sau "c:3"
    prev = {},         -- stare tasta la frame-ul anterior
    nameToId = {},
    idToName = {},
}

do
    -- construim maparea nume <-> cod; de la mouse doar butonul din mijloc (rotita) si butoanele laterale,
    -- ca sa poata fi bind-uri (ex. tasta "Cursor"); click stanga / dreapta nu (ar prinde click-ul de pe buton)
    for id = 0x04, 0xFE do
        local name = vkeys.id_to_name(id)
        if name and name ~= "" and (not name:find("Button") or id == vkeys.VK_MBUTTON or id == vkeys.VK_XBUTTON1 or id == vkeys.VK_XBUTTON2) then
            Keys.idToName[id] = name
            Keys.nameToId[name] = id
        end
    end
end

function Keys.justPressed(id)
    local down = isKeyDown(id)
    local was = Keys.prev[id]
    Keys.prev[id] = down
    return down and not was
end

-- sincronizeaza starea tuturor tastelor fara sa declanseze nimic
function Keys.syncAll()
    for id in pairs(Keys.idToName) do Keys.prev[id] = isKeyDown(id) end
end

-- toate tastele folosite, pentru detectarea conflictelor
function Keys.usage()
    local used = {}
    for _, a in ipairs(Actions.list) do
        local k = Keys.nameOf(a.id)
        if k and k ~= "None" then used[k] = (used[k] or 0) + 1 end
    end
    for i = 1, Custom.count() do
        local k = Custom.get(i).key
        if k ~= "None" then used[k] = (used[k] or 0) + 1 end
    end
    return used
end

function Keys.conflicts()
    local list = {}
    for k, n in pairs(Keys.usage()) do
        if n > 1 then table.insert(list, k) end
    end
    table.sort(list)
    return list
end

-- numele tastei unei actiuni, mereu ca text (inicfg intoarce numere pentru taste ca "5")
function Keys.nameOf(actionId)
    return tostring(cfg.binds[actionId .. "_key"] or "None")
end

function Keys.assign(ref, keyName)
    if ref:sub(1, 2) == "a:" then
        cfg.binds[ref:sub(3) .. "_key"] = keyName
    else
        local i = tonumber(ref:sub(3))
        local d = Custom.get(i); d.key = keyName; Custom.set(i, d)
    end
    saveCfg()
end

-- blocheaza bind-urile cand scrii in chat / esti in dialog / meniu / camp de text imgui
local function inputBusy()
    return sampIsChatInputActive() or sampIsDialogActive() or isPauseMenuActive() or State.textInput
end

function Keys.update()
    -- ESC se citeste o singura data pe frame, apoi se foloseste mai jos
    local esc = Keys.justPressed(vkeys.VK_ESCAPE)

    -- modul de captura: prima tasta apasata devine bind, ESC sterge
    if Keys.capturing then
        if esc then
            Keys.assign(Keys.capturing, "None")
            Keys.capturing = nil
            return
        end
        for id, name in pairs(Keys.idToName) do
            if Keys.justPressed(id) then
                Keys.assign(Keys.capturing, name)
                Keys.capturing = nil
                return
            end
        end
        return
    end

    -- tasta "Cursor" (tinuta apasata): cursorul pentru bara de iconite; nu si cand scrii in chat / e dialog
    do
        local ck = Keys.nameOf("cursor")
        local on = (tonumber(cfg.binds.cursor_on) or 0) == 1
        local id = ck and ck ~= "None" and Keys.nameToId[ck] or nil
        State.dockCursor = (on and id ~= nil and isKeyDown(id)
                            and not sampIsChatInputActive() and not sampIsDialogActive() and not isPauseMenuActive())
        -- in sens invers: cu o fereastra deschisa, aceeasi tasta ascunde cursorul cat o tii (camera / condus)
        local windowOpen = State.sih[0] or Prompt.open[0] or State.sic[0] or Report.open[0] or (App.PD ~= nil and App.PD.open[0])
        State.cursorHeldNoWindow   = State.dockCursor and not windowOpen
        State.cursorHeldWithWindow = State.dockCursor and windowOpen
    end

    -- (ESC pentru ferestre e tratat in onWindowMessage, inaintea jocului - vezi escCloses)

    if inputBusy() then
        -- tot trebuie sa actualizam starea, altfel se acumuleaza "just pressed"
        Keys.syncAll()
        return
    end

    for _, a in ipairs(Actions.list) do
        local keyName = Keys.nameOf(a.id)
        local on = tonumber(cfg.binds[a.id .. "_on"]) or 0
        if on == 1 and keyName and keyName ~= "None" then
            local id = Keys.nameToId[keyName]
            if id and Keys.justPressed(id) then a.run(a) end
        end
    end

    for i = 1, Custom.count() do
        local b = Custom.get(i)
        if b.on == 1 and b.key ~= "None" then
            local id = Keys.nameToId[b.key]
            if id and Keys.justPressed(id) then Queue.push(b.cmd) end
        end
    end
end

-- buffere imgui
local buf = {
    delay    = new.int(tonumber(cfg.main.queueDelay) or 700),
    bonus    = new.int(tonumber(cfg.main.bonusPercent) or 0),
    pagesize = new.int(math.max(K.PAGESIZE_MIN, math.min(K.PAGESIZE_MAX, tonumber(cfg.main.pagesize) or 10))),
    custom   = {},
}

local function customBuf(i)
    if not buf.custom[i] then
        buf.custom[i] = new.char[64]()
        imgui.StrCopy(buf.custom[i], Custom.get(i).cmd)
    end
    return buf.custom[i]
end

-- ============================================================
-- UI: stil si ajutoare
-- ============================================================
-- ============================================================
-- TEME DE CULORI: o culoare principala care coloreaza toate ferestrele
-- (titluri, butoane active, bife, slidere); textul si fundalul raman neutre
-- ============================================================
local function V4(r, g, b, a) return imgui.ImVec4(r, g, b, a or 1) end
-- ============================================================
-- FACTIUNI (lista de pe rpg.b-zone.ro/factions) si TEME DE CULORI pe categorii
-- ============================================================
-- fiecare factiune: id, nume, culoarea oficiala (hex), tema (categoria de culori), orase (daca are LS/LV/SF)
local FACTIONS = {
    { id = "si",         label = "School Instructors", hex = "00ff78", theme = "si",          cities = true, icon = "GRADUATION_CAP" },
    { id = "taxi",       label = "Taxi",               hex = "ECD450", theme = "taxi",        cities = true, icon = "TAXI" },
    { id = "pd",         label = "Police Department",  hex = "1E519D", theme = "departments",      cities = true, icon = "SHIELD_HALVED" },
    { id = "fbi",        label = "FBI",                hex = "1E519D", theme = "departments", icon = "USER_SECRET" },
    { id = "ng",         label = "National Guard",     hex = "1E519D", theme = "departments", icon = "PERSON_MILITARY_RIFLE" },
    { id = "paramedics", label = "Paramedics",         hex = "F29D9D", theme = "paramedics", icon = "TRUCK_MEDICAL" },
    { id = "news",       label = "News Reporters",     hex = "C2A2DA", theme = "news", icon = "NEWSPAPER" },
    { id = "tow",        label = "Tow Truck Company",  hex = "D7CE96", theme = "civic", icon = "TRUCK_PICKUP" },
    { id = "mayor",      label = "Mayor",              hex = "9ACD32", theme = "civic", icon = "LANDMARK_DOME" },
    { id = "hitmen",     label = "Hitmen Agency",      hex = "AA3333", theme = "mafia", icon = "CROSSHAIRS" },
    { id = "soa",        label = "Sons of Anarchy",    hex = "7A003F", theme = "mafia", icon = "MOTORCYCLE" },
    { id = "bloods",     label = "Green Street Bloods",hex = "33AA33", theme = "mafia", icon = "HAND_FIST" },
    { id = "verdant",    label = "Verdant Family",     hex = "656565", theme = "mafia", icon = "LEAF" },
    { id = "vietnamese", label = "Vietnamese Boys",    hex = "8aa09d", theme = "mafia", icon = "YIN_YANG" },
    { id = "bratva",     label = "The Tsar Bratva",    hex = "946141", theme = "mafia", icon = "WHISKEY_GLASS" },
    { id = "triad",      label = "Red Dragon Triad",   hex = "d0000f", theme = "mafia", icon = "DRAGON" },
    { id = "pimps",      label = "Southern Pimps",     hex = "B32CF6", theme = "mafia", icon = "GEM" },
    { id = "rifa",       label = "Avispa Rifa",        hex = "3a460c", theme = "mafia", icon = "PEPPER_HOT" },
    { id = "pier",       label = "69 Pier Mobs",       hex = "33CCFF", theme = "mafia", icon = "ANCHOR" },
    { id = "cartel",     label = "El Loco Cartel",     hex = "FF9900", theme = "mafia", icon = "SKULL" },
}
local Factions = { list = FACTIONS, byId = {} }
for _, f in ipairs(FACTIONS) do Factions.byId[f.id] = f end

-- numele rangului dupa numarul din /id: "(6)" la School Instructors -> "Under Boss".
-- Factiunile fara nume proprii de ranguri intorc "Rang 6"; rangul 0 e cel de dinainte de test.
function Factions.rankName(factionId, n)
    n = tonumber(n)
    if not n then return nil end
    if n <= 0 then return (Data and Data.rank_zero) or "Rang 0" end
    local set = Data and Data.ranks and Data.ranks[factionId]
    if set and set[n] then return set[n] end
    if n >= 7 then return (Data and Data.rank_leader) or "Rang 7 (Lider)" end
    return string.format((Data and Data.rank_generic) or "Rang %d", n)
end

local function hexToRgb(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
local function H(hex, a) local r, g, b = hexToRgb(hex) return V4(r, g, b, a or 1) end

-- Schema unei palete (aceeasi structura pentru toate categoriile):
--   primary   culoarea factiunii: butoane primare (Start lesson, Give, Trimite), bara de progres
--   accent    varianta mai deschisa, pentru text: titluri de sectiune, valori, tab activ, iconite
--   selBg / selBorder      butoanele "selectate" (tab activ, optiune aleasa, ON)
--   idleBg / idleBorder / idleText   butoanele NEselectate si OFF
--   onColor / offColor     textul comutatoarelor ON / OFF
--   darkText  textul de pe butonul primar e inchis (accent luminos) sau alb
local THEMES = {
    { id = "si",          label = "School Instructors", primary = "00D96A", accent = "6EF2AC",
      selBg = "133326", selBorder = "1F8A55", idleBg = "151C18", idleBorder = "24352C", idleText = "9BB5A8",
      onColor = "00D96A", offColor = "5D6E66", darkText = true },
    { id = "taxi",        label = "Taxi",               primary = "E6C93F", accent = "F2DF80",
      selBg = "3A3314", selBorder = "9B8A1F", idleBg = "1E1C14", idleBorder = "38341C", idleText = "C4BA8B",
      onColor = "E6C93F", offColor = "6E6A50", darkText = true },
    { id = "departments", label = "Departamente",       primary = "2E6BC8", accent = "7FAEEC",
      selBg = "162A45", selBorder = "2A5A9E", idleBg = "14181F", idleBorder = "223047", idleText = "9AAAC2",
      onColor = "5A93E0", offColor = "4F5A6B", darkText = false },
    { id = "mafia",       label = "Mafia / Gang",       primary = "C0392B", accent = "E8867A",
      selBg = "3A1714", selBorder = "8F2A20", idleBg = "1F1515", idleBorder = "3A2222", idleText = "BB9A9A",
      onColor = "E05A4B", offColor = "6B4A4A", darkText = false },
    { id = "paramedics",  label = "Paramedics",         primary = "F29D9D", accent = "F7C0C0",
      selBg = "3D2424", selBorder = "A65C5C", idleBg = "211818", idleBorder = "3C2727", idleText = "C9A5A5",
      onColor = "F29D9D", offColor = "6E5252", darkText = true },
    { id = "news",        label = "Jurnalisti",         primary = "C2A2DA", accent = "DCC8EA",
      selBg = "2E2438", selBorder = "7A5E93", idleBg = "1B1721", idleBorder = "312739", idleText = "B4A6C3",
      onColor = "C2A2DA", offColor = "5F5569", darkText = true },
    { id = "civic",       label = "Tow / Mayor",        primary = "B7C07C", accent = "D5DCA6",
      selBg = "2F3320", selBorder = "7F8A3C", idleBg = "1B1D15", idleBorder = "31351F", idleText = "B0B49A",
      onColor = "B7C07C", offColor = "5F6252", darkText = true },
}

local Themes = { list = {}, byId = {} }
for _, t in ipairs(THEMES) do
    local theme = {
        id = t.id, label_ro = t.label, label_en = t.label,
        raw = H(t.primary), accent = H(t.accent),
        btn = H(t.idleBg), border = H(t.idleBorder), idleText = H(t.idleText),
        hover = H(t.selBg), active = H(t.selBorder), selBorder = H(t.selBorder),
        onColor = H(t.onColor), offColor = H(t.offColor), darkText = t.darkText,
    }
    table.insert(Themes.list, theme)
    Themes.byId[t.id] = theme
end
-- configurile din versiunile vechi
Themes.byId.cyan, Themes.byId.green, Themes.byId.blue = Themes.byId.si, Themes.byId.si, Themes.byId.departments
Themes.byId.purple, Themes.byId.orange, Themes.byId.red = Themes.byId.news, Themes.byId.taxi, Themes.byId.mafia
Themes.byId.police = Themes.byId.departments

-- culorile folosite in cod; cele dependente de tema se schimba in applyTheme()
local GREEN      = Themes.byId.si.accent             -- accent: titluri de sectiune, valori active
local BTN_ACTIVE = Themes.byId.si.hover               -- fundalul butoanelor "selectate"
local ACCENT_TXT = V4(0.055, 0.078, 0.094)             -- textul de pe butoanele primare (se schimba cu tema)
local ACCENT_RAW = Themes.byId.si.raw                  -- culoarea exacta a factiunii, pentru butoanele primare
local OK_GREEN   = V4(0.37, 0.75, 0.47)                -- #5fbf77: bifat / valid
local BLUE       = V4(0.55, 0.75, 1.00)                -- comenzi
local AMBER      = V4(0.88, 0.76, 0.29)                -- #e0c24a: bani, atentionari
local RED        = V4(0.88, 0.42, 0.39)                -- #e06a64
local DIM        = V4(0.59, 0.64, 0.67)                -- #97a3ab
local TEXT       = V4(0.89, 0.91, 0.93)                -- #e4e9ec
local BTN_IDLE   = Themes.byId.si.btn                   -- fundalul butoanelor neselectate (din tema)
local BTN_BORDER = Themes.byId.si.border                -- chenarul butoanelor neselectate
local IDLE_TEXT  = Themes.byId.si.idleText              -- textul butoanelor neselectate
local SW_ON, SW_OFF = Themes.byId.si.onColor, Themes.byId.si.offColor   -- comutatoarele ON / OFF
local HEADER_BG  = V4(0.11, 0.13, 0.15)                -- #1c2226: bara de titlu si capete de panou

-- aplica tema din setari; culorile de stil doar daca imgui e pornit (se apeleaza si din frame)
local function applyTheme()
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    GREEN, BTN_ACTIVE, ACCENT_RAW = t.accent, t.hover, t.raw
    BTN_IDLE, BTN_BORDER, IDLE_TEXT, SW_ON, SW_OFF = t.btn, t.border, t.idleText, t.onColor, t.offColor
    ACCENT_TXT = t.darkText and V4(0.055, 0.078, 0.094) or V4(0.96, 0.97, 0.98)
    if not imgui.IsInitialized() then return end
    local c, clr = imgui.GetStyle().Colors, imgui.Col
    c[clr.Button]           = t.btn
    c[clr.ButtonHovered]    = t.hover
    c[clr.ButtonActive]     = t.active
    c[clr.FrameBgHovered]   = t.btn
    c[clr.FrameBgActive]    = t.hover
    c[clr.Header]           = t.btn
    c[clr.HeaderHovered]    = t.hover
    c[clr.HeaderActive]     = t.active
    c[clr.CheckMark]        = t.accent
    c[clr.SliderGrab]       = t.accent
    c[clr.SliderGrabActive] = t.accent
    c[clr.ResizeGripHovered]= t.hover
    c[clr.ResizeGripActive] = t.active
    c[clr.TextSelectedBg]   = t.hover
    c[clr.PlotHistogram]    = t.raw      -- barele de progres
    c[clr.Border]           = t.border   -- chenarele butoanelor / ferestrelor iau tonul temei
end

-- marimile stilului (rotunjiri, padding-uri, spatii) la scara curenta a interfetei (State.uiScale);
-- se reaplica de fiecare data cand se schimba rezolutia jocului
local function applyStyleSizes()
    local style = imgui.GetStyle()
    style.WindowRounding    = 5
    style.FrameRounding     = 4
    style.ChildRounding     = 4
    style.GrabRounding      = 3
    style.WindowBorderSize  = 1
    style.FrameBorderSize   = 1        -- butoanele au chenar subtil, ca in mockup
    style.WindowPadding     = imgui.ImVec2(10, 10)
    style.FramePadding      = imgui.ImVec2(6, 4)    -- ca inainte: iconitele stau centrate in butoane
    style.ItemSpacing       = imgui.ImVec2(6, 5)
    style.ScrollbarSize     = 10
    style:ScaleAllSizes(State.uiScale)
end

-- scara interfetei: 1.0 la 1080p pe verticala; mai mare pe rezolutii mai mari (fonturi, ferestre, HUD-uri)
local function px(v) return math.floor(v * State.uiScale + 0.5) end
local function uiScaleUpdate()
    local res = imgui.GetIO().DisplaySize
    if not res or res.y <= 0 then return end
    local scale = math.max(0.75, math.min(1.6, res.y / K.UI_REF_HEIGHT))
    if math.abs(scale - State.uiScale) < 0.01 then return end
    State.uiScale = scale
    imgui.GetIO().FontGlobalScale = scale
    applyStyleSizes()
    trace(string.format("ui: scara %.2f (%dx%d)", scale, res.x, res.y))
end

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil

    -- fontul cu iconite (FontAwesome) pentru tab-urile din /sic
    State.icons = (type(fa.Init) == "function") and pcall(fa.Init) or false
    -- acelasi font, mare, pentru insigna factiunii si bara de iconite; InitBig exista doar in
    -- fisierul de font din arhiva helperului, deci verificam inainte sa-l cerem
    local okBig, bigFont = false, nil
    if type(fa.InitBig) == "function" then
        okBig, bigFont = pcall(fa.InitBig, K.FACTION_ICON_SIZE)
    else
        State.fontOld = true
    end
    State.iconBig = okBig and bigFont or nil

-- DEZACTIVAT (test crash la revenirea din alt-tab):     -- font monospace pentru valori (ID, nivel, sume, ore), ca in mockup; Consolas exista pe orice Windows
-- DEZACTIVAT (test crash la revenirea din alt-tab):     local monoPath = getFolderPath(0x14) .. "\\consola.ttf"
-- DEZACTIVAT (test crash la revenirea din alt-tab):     if doesFileExist(monoPath) then
-- DEZACTIVAT (test crash la revenirea din alt-tab):         State.monoFont = imgui.GetIO().Fonts:AddFontFromFileTTF(monoPath, 14, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
-- DEZACTIVAT (test crash la revenirea din alt-tab):     end

    applyStyleSizes()

    -- culorile neutre din mockup (fundal, text, chenare); cele de accent vin din tema
    local style = imgui.GetStyle()
    local c, clr = style.Colors, imgui.Col
    c[clr.WindowBg]        = V4(0.078, 0.090, 0.102, 0.94)   -- #14171a @ 94%
    c[clr.ChildBg]         = V4(0.098, 0.110, 0.125, 1.00)   -- #191d20
    c[clr.PopupBg]         = V4(0.078, 0.090, 0.102, 1.00)
    c[clr.Border]          = V4(0.184, 0.212, 0.235, 1.00)   -- #2f363c
    c[clr.FrameBg]         = V4(0.102, 0.125, 0.141, 1.00)   -- #1a2024
    c[clr.TitleBg]         = HEADER_BG
    c[clr.TitleBgActive]   = HEADER_BG
    c[clr.TitleBgCollapsed]= HEADER_BG
    c[clr.MenuBarBg]       = HEADER_BG
    c[clr.Text]            = TEXT
    c[clr.TextDisabled]    = DIM
    c[clr.Separator]       = V4(0.184, 0.212, 0.235, 1.00)
    c[clr.ResizeGrip]      = V4(0.184, 0.212, 0.235, 1.00)
    c[clr.ScrollbarBg]     = V4(0.078, 0.090, 0.102, 1.00)
    c[clr.ScrollbarGrab]   = V4(0.184, 0.212, 0.235, 1.00)
    applyTheme()
end)

-- buton primar: umplut cu accent, text inchis (Start lesson, Give license, Trimite)
local function primaryButton(label, size)
    imgui.PushStyleColor(imgui.Col.Button, ACCENT_RAW)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, V4(math.min(1, ACCENT_RAW.x * 1.15 + 0.05), math.min(1, ACCENT_RAW.y * 1.15 + 0.05), math.min(1, ACCENT_RAW.z * 1.15 + 0.05)))
    imgui.PushStyleColor(imgui.Col.ButtonActive, V4(ACCENT_RAW.x * 0.85, ACCENT_RAW.y * 0.85, ACCENT_RAW.z * 0.85))
    imgui.PushStyleColor(imgui.Col.Text, ACCENT_TXT)
    imgui.PushStyleColor(imgui.Col.Border, ACCENT_RAW)
    local clicked = imgui.Button(label, size)
    imgui.PopStyleColor(5)
    return clicked
end

-- text cu fontul monospace (valori), daca s-a incarcat
local function mono(fn)
    if State.monoFont then imgui.PushFont(State.monoFont) end
    fn()
    if State.monoFont then imgui.PopFont() end
end

K.LABEL_COL  = 190   -- coloana la care incep controalele in tab-ul General
K.SEARCH_MAX = 12    -- cate rezultate se arata la cautarea din /sih
K.GIVEME_WINDOW = 12   -- secunde per licenta in care /giveme accepta singur licenta oferita de server

-- titlu de sectiune: text verde cu majuscule si o linie sub el
local function sectionHeader(text)
    imgui.Spacing()
    TC(GREEN, u8(string.upper(text)))
    imgui.Separator()
    imgui.Spacing()
end

-- eticheta + cursor mutat pe coloana controalelor
local function labeled(text)
    TX(u8(text))
    imgui.SameLine(K.LABEL_COL)
end

-- buton cu stare (activ / inactiv); intoarce true la click
local function toggleButton(label, active, size, activeText, idleText)
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    imgui.PushStyleColor(imgui.Col.Button, active and BTN_ACTIVE or BTN_IDLE)
    imgui.PushStyleColor(imgui.Col.Border, active and t.selBorder or BTN_BORDER)
    imgui.PushStyleColor(imgui.Col.Text, active and (activeText or GREEN) or (idleText or IDLE_TEXT))
    local clicked = imgui.Button(label, size)
    imgui.PopStyleColor(3)
    return clicked
end

-- buton de tab: cel activ e evidentiat
local function tabButton(text, index, width)
    local active = (State.tab == index)
    imgui.PushStyleColor(imgui.Col.Button, active and BTN_ACTIVE or BTN_IDLE)
    imgui.PushStyleColor(imgui.Col.Text, active and GREEN or DIM)
    if imgui.Button(u8(text) .. "##tab" .. index, imgui.ImVec2(width, 26)) then State.tab = index end
    imgui.PopStyleColor(2)
end

-- grup de butoane exclusive (LS / SF / LV, Romana / English); intoarce valoarea aleasa
local function choiceButtons(id, options, current, width)
    local chosen = nil
    for i, opt in ipairs(options) do
        if toggleButton(u8(opt.label) .. "##" .. id .. i, current == opt.value, imgui.ImVec2(width, 22)) then
            chosen = opt.value
        end
        if i < #options then imgui.SameLine() end
    end
    return chosen
end

-- o linie din ghid: comanda colorata + explicatie
local function guideLine(cmd, text)
    TC(BLUE, cmd)
    imgui.SameLine(150)
    imgui.PushStyleColor(imgui.Col.Text, TEXT)
    TW(u8(text))   -- cu wrap, ca explicatiile mai lungi sa nu iasa din panou
    imgui.PopStyleColor()
end

-- buton de tasta; ref = "a:acc" / "c:2"
local function keyButton(ref, keyName, conflicted, width)
    local capturing = (Keys.capturing == ref)
    local label = capturing and tr("press_key") or keyName
    if capturing then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.09, 0.20, 0.12, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, GREEN)
    elseif conflicted then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.20, 0.09, 0.09, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, RED)
    else
        imgui.PushStyleColor(imgui.Col.Button, BTN_IDLE)
        imgui.PushStyleColor(imgui.Col.Text, TEXT)
    end
    local clicked = imgui.Button(u8(label) .. "##key" .. ref, imgui.ImVec2(width, 22))
    imgui.PopStyleColor(2)
    if clicked then
        Keys.capturing = capturing and nil or ref
        -- resetam starea ca sa nu captureze chiar tasta de click
        Keys.syncAll()
    end
    return clicked
end

local LANG_OPTIONS = {
    { value = K.LANG_RO, label = "Romana"  },
    { value = K.LANG_EN, label = "English" },
}
local FACTION_OPTIONS = {
    { value = K.CITY_LS, label = K.CITY_LS },
    { value = K.CITY_SF, label = K.CITY_SF },
    { value = K.CITY_LV, label = K.CITY_LV },
}
local TARGET_OPTIONS = { K.TARGET_LAST, K.TARGET_NEAR, K.TARGET_ASK }
local TARGET_LABEL   = { [K.TARGET_LAST] = "t_last", [K.TARGET_NEAR] = "t_near", [K.TARGET_ASK] = "t_ask" }

-- ============================================================
-- /sih - tab Bind-uri (aspect ca in SIHelper: doua panouri, titluri centrate)
-- ============================================================
K.KEY_W, K.RESET_W, K.TARGET_W, K.CHK_W, K.DEL_W = 64, 46, 118, 20, 22
K.ACTION_CMD_COL = 150   -- coloana comenzii pe randul unei actiuni

-- titlu centrat, verde, cu iconita de o parte si de alta
local function panelTitle(text, icon)
    local label = u8(text)
    if State.icons and icon then label = icon .. "  " .. label .. "  " .. icon end
    local w = imgui.GetContentRegionAvail().x
    imgui.SetCursorPosX(imgui.GetCursorPosX() + math.max(0, (w - imgui.CalcTextSize(label).x) / 2))
    TC(GREEN, label)
    imgui.Spacing()
    imgui.Spacing()
end

-- muta cursorul pe aceeasi linie, astfel incat un grup de latime totalW sa fie lipit de dreapta
local function alignRight(totalW)
    imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - totalW)
end

-- butonul "reset": sterge tasta (si opreste captura, daca era pornita)
local function resetButton(ref)
    if imgui.Button(u8("reset") .. "##reset" .. ref, imgui.ImVec2(K.RESET_W, 22)) then
        if Keys.capturing == ref then Keys.capturing = nil end
        Keys.assign(ref, "None")
    end
end

local function rowSeparator()
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
end

-- un rand de actiune: nume | comanda ......... [tasta] [reset] [tinta] [activ]
local function drawActionRow(a, conflicts, spacing)
    local keyName = Keys.nameOf(a.id)
    local on = tonumber(cfg.binds[a.id .. "_on"]) or 0
    local target = cfg.binds[a.id .. "_target"] or K.TARGET_NONE

    TX(actionLabel(a))
    imgui.SameLine(K.ACTION_CMD_COL)
    TC(BLUE, a.hint)
    alignRight(K.KEY_W + K.RESET_W + K.TARGET_W + K.CHK_W + spacing * 3)
    keyButton("a:" .. a.id, keyName, conflicts[keyName], K.KEY_W)
    imgui.SameLine()
    resetButton("a:" .. a.id)
    imgui.SameLine()
    if target == K.TARGET_NONE then
        imgui.Dummy(imgui.ImVec2(K.TARGET_W, 20))
    else
        imgui.PushItemWidth(K.TARGET_W)
        if imgui.BeginCombo("##t" .. a.id, u8(tr(TARGET_LABEL[target] or "t_last"))) then
            for _, mode in ipairs(TARGET_OPTIONS) do
                if imgui.Selectable(u8(tr(TARGET_LABEL[mode])) .. "##" .. mode .. a.id, target == mode) then
                    cfg.binds[a.id .. "_target"] = mode
                    saveCfg()
                end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
    end
    imgui.SameLine()
    local chk = new.bool(on == 1)
    if imgui.Checkbox("##on" .. a.id, chk) then
        cfg.binds[a.id .. "_on"] = chk[0] and 1 or 0
        saveCfg()
    end
    if imgui.IsItemHovered() then TIP(u8(tr("col_on"))) end

    rowSeparator()
end

-- actiunea se potriveste cu textul cautat? (nume RO/EN, comanda, id; fara diferenta intre litere mari/mici)
local function actionMatches(a, needle)
    if needle == "" then return true end
    local hay = (a.label_ro .. " " .. a.label_en .. " " .. (a.hint or "") .. " " .. a.id):lower()
    return hay:find(needle, 1, true) ~= nil
end

-- grupurile din panoul de actiuni, in ordinea afisarii
local ACTION_GROUPS = {
    { id = "instructor", title = "grp_instructor" },
    { id = "pd",         title = "grp_pd" },
    { id = "hud",        title = "grp_hud" },
}

local bindSearchBuf = nil
local function drawActionsPanel(conflicts)
    panelTitle(tr("actions"), fa.KEYBOARD)
    local spacing = imgui.GetStyle().ItemSpacing.x

    -- cautare dupa cuvant cheie
    bindSearchBuf = bindSearchBuf or new.char[64]()
    if State.icons then TC(DIM, fa.MAGNIFYING_GLASS) imgui.SameLine(0, 8) end
    imgui.PushItemWidth(260)
    imgui.InputTextWithHint("##bindsearch", u8(tr("binds_search")), bindSearchBuf, 64)
    imgui.PopItemWidth()
    local needle = ffi.string(bindSearchBuf):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if needle ~= "" then
        imgui.SameLine()
        if imgui.Button("x##bindsearchclr", imgui.ImVec2(22, 22)) then imgui.StrCopy(bindSearchBuf, "") needle = "" end
    end
    imgui.Spacing()

    local shown = 0
    for _, g in ipairs(ACTION_GROUPS) do
        local rows = {}
        for _, a in ipairs(Actions.list) do
            if (a.group or "instructor") == g.id and actionMatches(a, needle) and Actions.visible(a) then table.insert(rows, a) end
        end
        if #rows > 0 then
            TC(DIM, u8(string.upper(tr(g.title))))
            imgui.Spacing()
            for _, a in ipairs(rows) do drawActionRow(a, conflicts, spacing) end
            shown = shown + #rows
        end
    end
    if shown == 0 then
        imgui.Spacing()
        imgui.PushStyleColor(imgui.Col.Text, DIM)
        TW(u8(tr("binds_nomatch")))
        imgui.PopStyleColor()
    end
end

local function drawCustomPanel(conflicts)
    panelTitle(tr("custom"), fa.TERMINAL)
    local spacing = imgui.GetStyle().ItemSpacing.x

    local n = Custom.count()
    local removeIdx = nil
    for i = 1, n do
        local b = Custom.get(i)
        -- [comanda .......][tasta][activ][x]
        local inputW = imgui.GetContentRegionAvail().x - (K.KEY_W + K.CHK_W + K.DEL_W + spacing * 3)
        imgui.PushItemWidth(math.max(60, inputW))
        local cb = customBuf(i)
        if imgui.InputText("##cmd" .. i, cb, 64) then
            b.cmd = ffi.string(cb)
            Custom.set(i, b)
            saveCfg()
        end
        imgui.PopItemWidth()

        imgui.SameLine()
        keyButton("c:" .. i, b.key, conflicts[b.key], K.KEY_W)

        imgui.SameLine()
        local chk = new.bool(b.on == 1)
        if imgui.Checkbox("##con" .. i, chk) then
            b.on = chk[0] and 1 or 0
            Custom.set(i, b)
            saveCfg()
        end
        if imgui.IsItemHovered() then TIP(u8(tr("col_on"))) end

        imgui.SameLine()
        if imgui.Button("x##del" .. i, imgui.ImVec2(K.DEL_W, 22)) then removeIdx = i end

        rowSeparator()
    end

    if removeIdx then
        Custom.remove(removeIdx)
        buf.custom = {}
    end

    if n < K.MAX_CUSTOM_BINDS then
        if imgui.Button(u8("+ " .. tr("add_bind")), imgui.ImVec2(imgui.GetContentRegionAvail().x, 24)) then
            Custom.add()
        end
    end
end

local function drawBindsTab()
    local conflicts = {}
    local list = Keys.conflicts()
    for _, k in ipairs(list) do conflicts[k] = true end

    TC(DIM, u8(tr("binds_hint")))
    if #list > 0 then
        imgui.SameLine()
        TC(RED, u8("  " .. tr("conflict", table.concat(list, ", "))))
    end
    imgui.Spacing()

    -- actiunile pe toata latimea (un rand fiecare), bind-urile personalizate dedesubt
    local rowH = 22 + imgui.GetStyle().ItemSpacing.y * 3 + 1
    -- panoul de actiuni nu creste peste spatiul disponibil: bind-urile personalizate raman mereu vizibile
    -- (cel putin K.CUSTOM_MIN_H); daca sunt prea multe actiuni, lista lor deruleaza in panou
    local actionsH = math.min(52 + 70 + #Actions.list * rowH, imgui.GetContentRegionAvail().y - K.CUSTOM_MIN_H)

    imgui.BeginChild("##bindsActions", imgui.ImVec2(0, actionsH), true)
    drawActionsPanel(conflicts)
    imgui.EndChild()

    imgui.BeginChild("##bindsCustom", imgui.ImVec2(0, 0), true)
    drawCustomPanel(conflicts)
    imgui.EndChild()
end

-- ============================================================
-- /sih - tab Features: fiecare feature cu comutator ON / OFF si explicatie la hover
-- camp numeric cu - / + si unitate (delay, pagesize, bonus)
local function optInt(id, buffer, min, max, step, unit)
    imgui.PushItemWidth(110)
    local changed = imgui.InputInt("##" .. id, buffer, step, step * 5)
    imgui.PopItemWidth()
    if changed then buffer[0] = math.max(min, math.min(max, buffer[0])) end
    if unit then
        imgui.SameLine()
        TC(DIM, unit)
    end
    return changed
end

-- ============================================================
local FEATURE_GROUPS = {
    { title = "fg_test",      keys = { "theoryPagesize", "autoStoplesson", "autoDl", "showAnswers", "chain50", "hpMonitor" } },
    { title = "fg_candidate", keys = { "autoCandidate", "autoSms", "clearCp", "notifyOn", "subtotalAR", "allyPay", "checklist", "reportWindow", "dutyHud", "dutyWindows" } },
    { title = "fg_look",      keys = { "dock", "bindLegend", "hideSrvDist", "sicLastSent", "fadeAnim", "shotRename", "shortsOn", "verCheck" } },
    { title = "fg_fvr",       keys = { "fvrOn" } },
}

-- ferestrele care se pot deschide automat la duty
K.DUTY_WINDOWS = {
    { key = "dutyWinSic",    label = "/sic" },
    { key = "dutyWinWithme", label = "/withme" },
    { key = "dutyWinReport", label = "/raport" },
}

local NOTIFY_OPTIONS = {
    { value = K.NOTIFY_ANY,  label = "n_any"  },
    { value = K.NOTIFY_LOW,  label = "n_low"  },
    { value = K.NOTIFY_HIGH, label = "n_high" },
}

-- buffere pentru textele FVR

local function fvrBuffers()
    if not State.fvrBuf then
        State.fvrBuf = { start = new.char[128](), sx = new.char[128](), stop = new.char[128](),
                   seconds = new.int(tonumber(cfg.fvr.seconds) or 10) }
        imgui.StrCopy(State.fvrBuf.start, tostring(cfg.fvr.startText or ""))
        imgui.StrCopy(State.fvrBuf.sx,    tostring(cfg.fvr.sxText or ""))
        imgui.StrCopy(State.fvrBuf.stop,  tostring(cfg.fvr.endText or ""))
    end
    return State.fvrBuf
end

-- comutator ON / OFF: verde cand e pornit, gri cand e oprit
local function switchButton(key)
    local on = feat(key)
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    imgui.PushStyleColor(imgui.Col.Button, on and BTN_ACTIVE or BTN_IDLE)
    imgui.PushStyleColor(imgui.Col.Border, on and t.selBorder or BTN_BORDER)
    imgui.PushStyleColor(imgui.Col.Text, on and SW_ON or SW_OFF)
    local clicked = imgui.Button((on and "ON" or "OFF") .. "##sw" .. key, imgui.ImVec2(44, 22))
    imgui.PopStyleColor(3)
    if clicked then
        cfg.main[key] = on and 0 or 1
        saveCfg()
    end
end

local function featureRow(key)
    switchButton(key)
    imgui.SameLine()
    TC(feat(key) and TEXT or DIM, u8(tr("f_" .. key)))
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(360)
        TW(u8(tr("f_" .. key .. "_tip")))
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end

    -- optiuni suplimentare pe acelasi rand
    if key == "subtotalAR" and feat(key) then
        -- cat e bonusul factiunii (AR), in procente
        imgui.SameLine(0, 16)
        if optInt("bonus", buf.bonus, 0, K.MAX_BONUS_PERCENT, 5, "%") then
            cfg.main.bonusPercent = buf.bonus[0]
            saveCfg()
        end
        if imgui.IsItemHovered() then TIP(u8(tr("bonus_hint"))) end
    end
    if key == "allyPay" and feat(key) then
        -- cui ii dai banii inapoi; gol = cea din fisierul de date, pe orasul tau
        imgui.SameLine(0, 16)
        local cur = App.Ally.who()
        local curFac = Factions.byId[cur]
        imgui.PushItemWidth(200)
        if imgui.BeginCombo("##allyfac", u8(curFac and curFac.label or tr("ally_none"))) then
            if imgui.Selectable(u8(tr("ally_none")) .. "##allynone", cur == "") then
                cfg.main.allyId = ""
                saveCfg()
            end
            for _, f in ipairs(Factions.list) do
                local r, g, b = hexToRgb(f.hex)
                imgui.PushStyleColor(imgui.Col.Text, V4(math.max(r, 0.35), math.max(g, 0.35), math.max(b, 0.35)))
                if imgui.Selectable(u8(f.label) .. "##ally" .. f.id, f.id == cur) then
                    cfg.main.allyId = f.id
                    saveCfg()
                end
                imgui.PopStyleColor()
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
        if imgui.IsItemHovered() then TIP(u8(tr("ally_pick_tip"))) end
    end
    if key == "dock" and feat(key) then
        -- orientarea barei: auto (dupa margine) / verticala / orizontala
        imgui.SameLine(0, 16)
        local options = { { value = "auto", label = tr("dock_auto") }, { value = "vert", label = tr("dock_vert") }, { value = "horiz", label = tr("dock_horiz") } }
        local pick = choiceButtons("dockorient", options, cfg.main.dockOrient or "auto", 74)
        if pick then cfg.main.dockOrient = pick saveCfg() end
    end
    if key == "dutyWindows" and feat(key) then
        -- care ferestre se deschid la duty: bife, ca sa fie clar ce e ales (se pot alege mai multe)
        imgui.SameLine(0, 16)
        for i, w in ipairs(K.DUTY_WINDOWS) do
            if i > 1 then imgui.SameLine(0, 10) end
            local chk = new.bool(feat(w.key))
            if imgui.Checkbox(w.label .. "##dw" .. w.key, chk) then
                cfg.main[w.key] = chk[0] and 1 or 0
                saveCfg()
            end
        end
    end
    if key == "notifyOn" and feat(key) then
        imgui.SameLine(0, 16)
        local options = {}
        for i, o in ipairs(NOTIFY_OPTIONS) do options[i] = { value = o.value, label = tr(o.label) } end
        local pick = choiceButtons("notifylvl", options, cfg.main.notifyLevel or K.NOTIFY_ANY, 56)
        if pick then cfg.main.notifyLevel = pick saveCfg() end
    end
end

local function drawFvrSettings()
    local b = fvrBuffers()
    local function textRow(labelKey, buffer, cfgKey)
        imgui.SetCursorPosX(52)
        TC(DIM, u8(tr(labelKey)))
        imgui.SameLine(180)
        imgui.PushItemWidth(-10)
        if imgui.InputText("##fvr" .. cfgKey, buffer, 128) then
            cfg.fvr[cfgKey] = ffi.string(buffer)
            saveCfg()
        end
        imgui.PopItemWidth()
    end
    textRow("fvr_start_text", b.start, "startText")
    textRow("fvr_sx_text",    b.sx,    "sxText")
    textRow("fvr_end_text",   b.stop,  "endText")
    imgui.SetCursorPosX(52)
    TC(DIM, u8(tr("fvr_seconds")))
    imgui.SameLine(180)
    imgui.PushItemWidth(110)
    if imgui.InputInt("##fvrsec", b.seconds, 1, 5) then
        b.seconds[0] = math.max(5, math.min(60, b.seconds[0]))
        cfg.fvr.seconds = b.seconds[0]
        saveCfg()
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    TC(DIM, "/ffvr  /sfvr")
end

local function drawFeaturesTab()
    for _, group in ipairs(FEATURE_GROUPS) do
        sectionHeader(tr(group.title))
        for _, key in ipairs(group.keys) do
            featureRow(key)
            if key == "fvrOn" and feat(key) then drawFvrSettings() end
        end
    end
end
-- ============================================================
-- /sih - tab General: sectiuni pliabile (fiecare isi arata pe scurt continutul), cautare peste toate
-- emblema factiunii alese, centrata in spatiul liber al sectiunii Factiune: orizontal intre capatul
-- meniului (leftX) si chenar, vertical intre secTop si secBottom (coordonate de ecran);
-- desenata direct in draw list, ca sa nu deranjeze asezarea randurilor
local function drawFactionEmblem(faction, leftX, secTop, secBottom)
    if not State.iconBig or not faction.icon then return end
    local glyph = fa[faction.icon]
    if not glyph or glyph == "?" then return end
    local size = px(K.FACTION_ICON_SIZE)
    local textSize = State.iconBig:CalcTextSizeA(size, math.huge, 0, glyph)
    local rightX = imgui.GetWindowPos().x + imgui.GetWindowContentRegionMax().x
    local cx, cy = (leftX + rightX) / 2, (secTop + secBottom) / 2
    local r, g, b = hexToRgb(faction.hex)
    r, g, b = math.max(r, 0.35), math.max(g, 0.35), math.max(b, 0.35)   -- culorile inchise (FBI, Rifa) raman vizibile
    local dl, radius = imgui.GetWindowDrawList(), px(K.FACTION_BADGE) / 2
    -- insigna: disc plin in culoarea factiunii (transparent), inel exterior, iconita in centru
    dl:AddCircleFilled(imgui.ImVec2(cx, cy), radius, imgui.GetColorU32Vec4(V4(r, g, b, 0.16)), 48)
    dl:AddCircle(imgui.ImVec2(cx, cy), radius, imgui.GetColorU32Vec4(V4(r, g, b, 0.85)), 48, 2)
    dl:AddCircle(imgui.ImVec2(cx, cy), radius - 5, imgui.GetColorU32Vec4(V4(r, g, b, 0.30)), 48, 1)
    dl:AddTextFontPtr(State.iconBig, size, imgui.ImVec2(cx - textSize.x / 2, cy - textSize.y / 2), imgui.GetColorU32Vec4(V4(r, g, b, 0.95)), glyph)
end

-- setarile din toate tab-urile, si sectiunea "Tastele mele" cu adaugare de bind pe loc
-- ============================================================
local Gen = {}

-- capul unei sectiuni: caret + TITLU + rezumat la dreapta; click = deschide / inchide (se retine in ini)
function Gen.section(id, title, summary)
    local key = "sec_" .. id
    local open = (tonumber(cfg.main[key]) or 0) == 1
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local w, h = imgui.GetContentRegionAvail().x, px(28)
    local p = imgui.GetCursorScreenPos()
    if imgui.InvisibleButton("##sec" .. id, imgui.ImVec2(w, h)) then
        open = not open
        cfg.main[key] = open and 1 or 0
        saveCfg()
    end
    local hovered = imgui.IsItemHovered()
    local dl, font, fs = imgui.GetWindowDrawList(), imgui.GetFont(), imgui.GetFontSize()
    local pMin, pMax = imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x + w, p.y + h)
    dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(hovered and t.hover or V4(0.098, 0.110, 0.125, 1)), px(5))
    dl:AddRect(pMin, pMax, imgui.GetColorU32Vec4(open and t.selBorder or BTN_BORDER), px(5), 15, 1)
    local caret = State.icons and (open and fa.CARET_DOWN or fa.CARET_RIGHT) or (open and "-" or "+")
    local x = p.x + px(10)
    dl:AddText(imgui.ImVec2(x, p.y + (h - fs) / 2), imgui.GetColorU32Vec4(open and t.accent or IDLE_TEXT), caret)
    x = x + font:CalcTextSizeA(fs, math.huge, 0, caret).x + px(10)
    local label = u8(string.upper(title))
    dl:AddText(imgui.ImVec2(x, p.y + (h - fs) / 2), imgui.GetColorU32Vec4(open and t.accent or TEXT), label)
    if summary and summary ~= "" then
        local s = u8(summary)
        local sw = font:CalcTextSizeA(fs * 0.92, math.huge, 0, s).x
        dl:AddTextFontPtr(font, fs * 0.92, imgui.ImVec2(p.x + w - px(10) - sw, p.y + (h - fs * 0.92) / 2),
                          imgui.GetColorU32Vec4(DIM), s)
    end
    if open then imgui.Dummy(imgui.ImVec2(0, px(2))) end
    return open
end
-- un rand din sectiunea "Tastele mele": numele actiunii, tasta, ochiul (arata / ascunde in legenda)
-- si X care sterge bind-ul
function Gen.keyRow(ref, label, keyName, hidden, onToggle, onClear)
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    TC(hidden and DIM or TEXT, u8(label))
    local spacing = imgui.GetStyle().ItemSpacing.x
    alignRight(K.KEY_W + px(26) * 2 + spacing * 2)
    keyButton(ref, keyName, false, K.KEY_W)
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, V4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Text, hidden and DIM or t.accent)
    local eye = State.icons and (hidden and fa.EYE_SLASH or fa.EYE) or (hidden and "-" or "o")
    if imgui.Button(eye .. "##eye" .. ref, imgui.ImVec2(px(26), 22)) then onToggle() end
    imgui.PopStyleColor(2)
    if imgui.IsItemHovered() then TIP(u8(tr(hidden and "legend_show" or "legend_hide"))) end
    imgui.SameLine()
    imgui.PushStyleColor(imgui.Col.Button, V4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Text, DIM)
    if imgui.Button((State.icons and fa.XMARK or "x") .. "##clr" .. ref, imgui.ImVec2(px(26), 22)) then onClear() end
    imgui.PopStyleColor(2)
    if imgui.IsItemHovered() then TIP(u8(tr("bind_clear"))) end
end

-- sectiunea "Tastele mele": bind-urile cu tasta setata + "Adauga un bind"
function Gen.keys()
    local shown = 0
    for _, a in ipairs(Actions.list) do
        local keyName = Keys.nameOf(a.id)
        if keyName and keyName ~= "None" then
            shown = shown + 1
            local hidden = (tonumber(cfg.binds[a.id .. "_hide"]) or 0) == 1
            Gen.keyRow("a:" .. a.id, actionLabel(a), keyName, hidden,
                function()
                    cfg.binds[a.id .. "_hide"] = hidden and 0 or 1   -- doar in legenda; bind-ul ramane activ
                    saveCfg()
                end,
                function() Keys.assign("a:" .. a.id, "None") end)
        end
    end
    for i = 1, Custom.count() do
        local b = Custom.get(i)
        if b.key ~= "None" then
            shown = shown + 1
            local hidden = (tonumber(cfg.custom["c" .. i .. "_hide"]) or 0) == 1
            Gen.keyRow("c:" .. i, b.cmd, b.key, hidden,
                function()
                    cfg.custom["c" .. i .. "_hide"] = hidden and 0 or 1
                    saveCfg()
                end,
                function() Keys.assign("c:" .. i, "None") end)
        end
    end
    if shown == 0 then TC(DIM, u8(tr("no_binds"))) end

    -- adaugare pe loc: alegi actiunea, apoi apesi tasta
    imgui.Dummy(imgui.ImVec2(0, px(2)))
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    imgui.PushStyleColor(imgui.Col.Button, V4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Border, t.selBorder)
    imgui.PushStyleColor(imgui.Col.Text, t.accent)
    -- PushItemWidth si culorile se scot DUPA intregul bloc: intre BeginCombo si EndCombo suntem in
    -- fereastra popup-ului, iar un Pop de acolo crapa jocul
    imgui.PushItemWidth(220)
    if imgui.BeginCombo("##addbind", "+  " .. u8(tr("add_bind"))) then
        for _, a in ipairs(Actions.list) do
            local keyName = Keys.nameOf(a.id)
            if (not keyName or keyName == "None") and Actions.visible(a) then
                if imgui.Selectable(u8(actionLabel(a)) .. "##addb" .. a.id) then
                    cfg.binds[a.id .. "_on"] = 1
                    saveCfg()
                    Keys.capturing = "a:" .. a.id      -- urmatoarea tasta apasata devine bind-ul
                    Keys.syncAll()
                end
            end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()
    imgui.PopStyleColor(3)
    imgui.SameLine()
    TC(DIM, u8(Keys.capturing and tr("press_key") or tr("add_bind_hint")))
end

-- toate setarile, intr-o lista plata, pentru cautare: { tab, grup, text, tip, cheie }
function Gen.index()
    local list = {}
    local function add(tab, group, text, kind, key)
        table.insert(list, { tab = tab, group = group, text = text, kind = kind, key = key })
    end
    add(tr("tab_general"), tr("sec_lang"), tr("ui_lang"), "sec", "lang")
    add(tr("tab_general"), tr("sec_lang"), tr("proc_lang"), "sec", "lang")
    add(tr("tab_general"), tr("sec_faction"), tr("faction"), "sec", "faction")
    add(tr("tab_general"), tr("sec_faction"), tr("city"), "sec", "faction")
    add(tr("tab_general"), tr("sec_window"), tr("theme"), "sec", "window")
    add(tr("tab_general"), tr("sec_window"), tr("delay"), "sec", "window")
    add(tr("tab_general"), tr("sec_window"), tr("pagesize"), "sec", "window")
    add(tr("tab_general"), tr("sec_notes"), tr("notes_title"), "sec", "notes")
    add(tr("tab_general"), tr("sec_window"), tr("reset_layout"), "sec", "window")
    add(tr("tab_general"), tr("sec_window"), tr("wiz_reopen"), "sec", "window")
    for _, group in ipairs(FEATURE_GROUPS) do
        for _, k in ipairs(group.keys) do
            add(tr("tab_features"), tr(group.title), tr("f_" .. k), "feat", k)
        end
    end
    for _, a in ipairs(Actions.list) do
        add(tr("tab_binds"), tr("grp_" .. (a.group or "instructor")), actionLabel(a), "bind", a.id)
    end
    return list
end

-- rezultatele cautarii: eticheta tabului, setarea, si controlul ei (comutator / tasta) unde are sens
function Gen.results(needle)
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local found = 0
    for _, e in ipairs(Gen.index()) do
        if e.text:lower():find(needle, 1, true) or (e.key and tostring(e.key):lower():find(needle, 1, true)) then
            found = found + 1
            if found <= K.SEARCH_MAX then
                local tag = u8(string.upper(e.tab .. " > " .. e.group))
                imgui.PushStyleColor(imgui.Col.Button, t.hover)
                imgui.PushStyleColor(imgui.Col.Text, t.accent)
                imgui.SmallButton(tag .. "##tag" .. found)
                imgui.PopStyleColor(2)
                imgui.SameLine()
                if e.kind == "feat" then
                    switchButton(e.key)
                    imgui.SameLine()
                    TC(feat(e.key) and TEXT or DIM, u8(e.text))
                elseif e.kind == "bind" then
                    keyButton("a:" .. e.key, Keys.nameOf(e.key), false, K.KEY_W)
                    imgui.SameLine()
                    TC(TEXT, u8(e.text))
                else
                    TC(TEXT, u8(e.text))
                    imgui.SameLine()
                    if imgui.SmallButton(u8(tr("search_open")) .. "##go" .. found) then
                        cfg.main["sec_" .. e.key] = 1
                        imgui.StrCopy(State.searchBuf, "")
                        saveCfg()
                    end
                end
            end
        end
    end
    if found == 0 then
        imgui.Spacing()
        TC(DIM, u8(tr("search_none")))
    elseif found > K.SEARCH_MAX then
        TC(DIM, u8(tr("search_more", found - K.SEARCH_MAX)))
    end
    return found
end

-- ============================================================
-- NOTITE (/notepad): textele tale, pe foldere. Fiecare notita se poate trimite in chat exact cum e
-- scrisa (text sau comanda) sau copia in clipboard. Se salveaza in
-- moonloader/config/SICHelper_notes.lua - un fisier Lua, editabil si din afara jocului.
-- ============================================================
local Notes = { data = {}, loaded = false }

function Notes.folder()
    return Notes.data[State.noteSel or 1]
end

function Notes.total()
    local n = 0
    for _, f in ipairs(Notes.data) do n = n + #f.items end
    return n
end

-- salvarea: un fisier Lua simplu (%q scapa ghilimelele si randurile noi)
function Notes.save()
    local f = io.open(K.NOTES_FILE, "w")
    if not f then err(tr("notes_nosave")) return end
    f:write("-- SICHelper - notitele tale (/notepad). Se poate edita si de aici, cu jocul inchis.\n")
    f:write("return {\n")
    for _, fold in ipairs(Notes.data) do
        f:write(string.format("  { name = %q, items = {\n", tostring(fold.name)))
        for _, item in ipairs(fold.items) do
            f:write(string.format("    %q,\n", tostring(item)))
        end
        f:write("  } },\n")
    end
    f:write("}\n")
    f:close()
end

-- prima pornire: aducem notitele din scriptul Notepad.lua (config/Notepad.ini), ca sa nu se piarda
function Notes.importOld()
    local out = {}
    local ok, old = pcall(inicfg.load, nil, "Notepad.ini")
    if not ok or type(old) ~= "table" then return out end
    local function grab(section, name)
        local t = old[section]
        if type(t) ~= "table" then return end
        local keys = {}
        for k in pairs(t) do table.insert(keys, k) end
        table.sort(keys, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
        local items = {}
        for _, k in ipairs(keys) do
            local v = tostring(t[k])
            if v ~= "" and v ~= "true" then table.insert(items, v) end
        end
        if #items > 0 then table.insert(out, { name = name, items = items }) end
    end
    grab("text", "Notepad")
    if type(old.folders) == "table" then
        for k, v in pairs(old.folders) do
            local name = tostring(v)
            if name == "true" or name == "" then name = tostring(k) end
            grab(name, name)
        end
    end
    return out
end

function Notes.load()
    Notes.data = nil
    if doesFileExist(K.NOTES_FILE) then
        local chunk = loadfile(K.NOTES_FILE)
        if chunk then
            local ok, res = pcall(chunk)
            if ok and type(res) == "table" then Notes.data = res end
        end
    end
    if not Notes.data then Notes.data = Notes.importOld() end
    for _, fold in ipairs(Notes.data) do
        fold.name = tostring(fold.name or tr("notes_first"))
        if type(fold.items) ~= "table" then fold.items = {} end
    end
    if #Notes.data == 0 then table.insert(Notes.data, { name = tr("notes_first"), items = {} }) end
    State.noteSel, State.noteEdit = 1, nil
    Notes.loaded = true
    trace("notite: " .. #Notes.data .. " foldere, " .. Notes.total() .. " randuri")
end

-- buton mic, doar iconita, fara fundal
function Notes.iconBtn(tag, glyph, fallback, i, col)
    imgui.PushStyleColor(imgui.Col.Button, V4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Text, col)
    local hit = imgui.Button((State.icons and glyph or fallback) .. "##nb" .. tag .. i, imgui.ImVec2(px(24), 22))
    imgui.PopStyleColor(2)
    return hit
end

-- taie textul ca sa intre pe un rand (restul se vede in tooltip)
function Notes.clip(text, w)
    if w <= 0 or imgui.CalcTextSize(u8(text)).x <= w then return text end
    local s = text
    while #s > 4 and imgui.CalcTextSize(u8(s .. "...")).x > w do
        s = s:sub(1, #s - math.max(1, math.floor(#s / 12)))
    end
    return s .. "..."
end

-- un rand: textul (dublu-click = modificare) si butoanele trimite / copiaza / modifica / sterge
function Notes.row(i, text)
    local fold = Notes.folder()
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local spacing, bw = imgui.GetStyle().ItemSpacing.x, px(24)

    if State.noteEdit == i then
        -- textbox-ul si-a pierdut focusul (click in alta parte): salvam, cu un frame intarziere,
        -- ca butonul "renunta" sa aiba timp sa anuleze
        if State.noteBlur then
            State.noteBlur = nil
            local v = ffi.string(State.noteEditBuf)
            if v:gsub("%s", "") ~= "" then fold.items[i] = v Notes.save() end
            State.noteEdit = nil
            return
        end
        imgui.PushItemWidth(imgui.GetContentRegionAvail().x - (bw * 2 + spacing * 3))
        local justFocused = State.noteFocus
        if State.noteFocus then imgui.SetKeyboardFocusHere() State.noteFocus = false end
        local done = imgui.InputText("##noteedit" .. i, State.noteEditBuf, K.NOTE_MAX, imgui.InputTextFlags.EnterReturnsTrue)
        local active = imgui.IsItemActive()
        imgui.PopItemWidth()
        imgui.SameLine()
        local save = Notes.iconBtn("SAVE", fa.FLOPPY_DISK, "s", i, t.accent)
        if imgui.IsItemHovered() then TIP(u8(tr("notes_save"))) end
        if save or done then
            local v = ffi.string(State.noteEditBuf)
            if v:gsub("%s", "") ~= "" then fold.items[i] = v Notes.save() end
            State.noteEdit, State.noteBlur = nil, nil
        end
        imgui.SameLine()
        if Notes.iconBtn("CANC", fa.XMARK, "x", i, DIM) then State.noteEdit, State.noteBlur = nil, nil end
        if imgui.IsItemHovered() then TIP(u8(tr("notes_cancel"))) end
        if State.noteEdit == i and not active and not justFocused then State.noteBlur = true end
        return
    end

    local w = imgui.GetContentRegionAvail().x - (bw * 4 + spacing * 5)
    local label = Notes.clip(text, w - px(10)):gsub("##", "# #")
    imgui.PushStyleColor(imgui.Col.HeaderHovered, t.hover)
    imgui.PushStyleColor(imgui.Col.HeaderActive, t.active)
    imgui.Selectable(u8(label) .. "##noterow" .. i, false, 0, imgui.ImVec2(w, 0))
    imgui.PopStyleColor(2)
    if imgui.IsItemHovered() then
        local tip = text
        if #text > K.NOTE_CHAT then tip = tip .. "\n\n" .. tr("notes_long", K.NOTE_CHAT) end
        TIP(u8(tip .. "\n" .. tr("notes_hint")))
        if imgui.IsMouseDoubleClicked(0) then
            State.noteEdit, State.noteFocus, State.noteBlur = i, true, nil
            imgui.StrCopy(State.noteEditBuf, text)
        end
    end
    imgui.SameLine()
    if Notes.iconBtn("SEND", fa.PAPER_PLANE, ">", i, t.accent) then Queue.push(text) end
    if imgui.IsItemHovered() then TIP(u8(tr("notes_send"))) end
    imgui.SameLine()
    if Notes.iconBtn("COPY", fa.COPY, "c", i, TEXT) then
        imgui.SetClipboardText(text)
        msg(tr("notes_copied", text))
    end
    if imgui.IsItemHovered() then TIP(u8(tr("notes_copy"))) end
    imgui.SameLine()
    if Notes.iconBtn("EDIT", fa.PEN_TO_SQUARE, "e", i, DIM) then
        State.noteEdit, State.noteFocus, State.noteBlur = i, true, nil
        imgui.StrCopy(State.noteEditBuf, text)
    end
    if imgui.IsItemHovered() then TIP(u8(tr("notes_edit"))) end
    imgui.SameLine()
    if Notes.iconBtn("DEL", fa.TRASH, "x", i, RED) then Notes.pendingDel = i end
    if imgui.IsItemHovered() then TIP(u8(tr("notes_del"))) end
end

-- coloana din stanga: folderele + adaugarea unui folder nou
function Notes.folders(bodyH)
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    imgui.BeginChild("##notefolders", imgui.ImVec2(px(K.NOTES_FOLD_W), bodyH), true)
    TC(t.accent, u8(string.upper(tr("notes_folders"))))
    imgui.Separator()
    for i, fold in ipairs(Notes.data) do
        if State.foldEdit == i then
            -- redenumire pe loc: Enter salveaza, si un click in alta parte salveaza
            imgui.PushItemWidth(-1)
            if State.foldFocus then imgui.SetKeyboardFocusHere() end
            local done = imgui.InputText("##rename" .. i, State.foldEditBuf, 32, imgui.InputTextFlags.EnterReturnsTrue)
            local active = imgui.IsItemActive()
            imgui.PopItemWidth()
            if done or (not active and not State.foldFocus) then
                local nm = ffi.string(State.foldEditBuf):gsub("^%s+", ""):gsub("%s+$", "")
                if nm ~= "" then fold.name = nm Notes.save() end
                State.foldEdit = nil
            end
            State.foldFocus = false
        else
            local sel = (State.noteSel == i)
            imgui.PushStyleColor(imgui.Col.Header, t.hover)
            imgui.PushStyleColor(imgui.Col.HeaderHovered, t.hover)
            local icon = State.icons and ((sel and fa.FOLDER_OPEN or fa.FOLDER) .. "  ") or ""
            if imgui.Selectable(icon .. u8(fold.name) .. "  (" .. #fold.items .. ")##nf" .. i, sel) then
                State.noteSel, State.noteEdit, State.noteDelAt = i, nil, nil
            end
            imgui.PopStyleColor(2)
            if imgui.IsItemHovered() then
                TIP(u8(tr("notes_rename_hint")))
                if imgui.IsMouseDoubleClicked(0) then
                    State.foldEdit, State.foldFocus, State.noteEdit = i, true, nil
                    imgui.StrCopy(State.foldEditBuf, fold.name)
                end
            end
        end
    end
    imgui.Separator()
    imgui.PushItemWidth(-1)
    local add = imgui.InputTextWithHint("##newfolder", u8(tr("notes_new_folder")), State.folderBuf, 32,
                                       imgui.InputTextFlags.EnterReturnsTrue)
    imgui.PopItemWidth()
    imgui.PushStyleColor(imgui.Col.Text, t.accent)
    if imgui.SmallButton("+  " .. u8(tr("notes_add_folder")) .. "##addfolder") then add = true end
    imgui.PopStyleColor()
    local name = ffi.string(State.folderBuf):gsub("^%s+", ""):gsub("%s+$", "")
    if add and name ~= "" then
        table.insert(Notes.data, { name = name, items = {} })
        State.noteSel, State.noteEdit = #Notes.data, nil
        imgui.StrCopy(State.folderBuf, "")
        Notes.save()
    end
    imgui.EndChild()
end

-- salveaza ce era in editare (folosit cand fereastra se inchide cu un click in afara ei)
function Notes.commit()
    local fold = Notes.folder()
    if State.noteEdit and State.noteEditBuf and fold and fold.items[State.noteEdit] then
        local v = ffi.string(State.noteEditBuf)
        if v:gsub("%s", "") ~= "" then fold.items[State.noteEdit] = v Notes.save() end
    end
    if State.foldEdit and State.foldEditBuf and Notes.data[State.foldEdit] then
        local nm = ffi.string(State.foldEditBuf):gsub("^%s+", ""):gsub("%s+$", "")
        if nm ~= "" then Notes.data[State.foldEdit].name = nm Notes.save() end
    end
    State.noteEdit, State.foldEdit = nil, nil
end

function Notes.draw()
    if not Notes.loaded then Notes.load() end
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    State.noteBuf     = State.noteBuf     or new.char[K.NOTE_MAX]()
    State.noteEditBuf = State.noteEditBuf or new.char[K.NOTE_MAX]()
    State.folderBuf   = State.folderBuf   or new.char[32]()
    State.foldEditBuf = State.foldEditBuf or new.char[32]()

    local bodyH = -(imgui.GetTextLineHeightWithSpacing() + px(16))
    Notes.folders(bodyH)
    imgui.SameLine()
    imgui.BeginChild("##notelist", imgui.ImVec2(0, bodyH), false)
    local fold = Notes.folder()
    if fold then
        TC(TEXT, u8(string.upper(fold.name)))
        alignRight(px(24))
        if Notes.iconBtn("DELF", fa.TRASH, "X", 0, RED) then
            if State.noteDelAt and os.clock() - State.noteDelAt < 3 then
                table.remove(Notes.data, State.noteSel)
                if #Notes.data == 0 then table.insert(Notes.data, { name = tr("notes_first"), items = {} }) end
                State.noteSel, State.noteDelAt, State.noteEdit = 1, nil, nil
                Notes.save()
            else
                State.noteDelAt = os.clock()
            end
        end
        if imgui.IsItemHovered() then TIP(u8(tr(State.noteDelAt and "notes_del_folder2" or "notes_del_folder"))) end
        imgui.Separator()
        fold = Notes.folder()
        if #fold.items == 0 then TC(DIM, u8(tr("notes_empty"))) end
        Notes.pendingDel = nil
        for i = 1, #fold.items do Notes.row(i, fold.items[i]) end
        if Notes.pendingDel then
            table.remove(fold.items, Notes.pendingDel)
            Notes.pendingDel, State.noteEdit = nil, nil
            Notes.save()
        end
    end
    imgui.EndChild()

    -- randul de jos: scrii o notita noua (Enter sau butonul Adauga)
    imgui.Separator()
    if State.icons then TC(t.accent, fa.PEN_TO_SQUARE) imgui.SameLine(0, 6) end
    imgui.PushItemWidth(imgui.GetContentRegionAvail().x - px(96))
    local go = imgui.InputTextWithHint("##newnote", u8(tr("notes_new")), State.noteBuf, K.NOTE_MAX,
                                      imgui.InputTextFlags.EnterReturnsTrue)
    imgui.PopItemWidth()
    imgui.SameLine()
    if primaryButton(u8(tr("notes_add")) .. "##addnote", imgui.ImVec2(px(88), 22)) then go = true end
    local v = ffi.string(State.noteBuf)
    if go and v:gsub("%s", "") ~= "" and Notes.folder() then
        table.insert(Notes.folder().items, v)
        imgui.StrCopy(State.noteBuf, "")
        Notes.save()
    end
end

-- ============================================================
-- EXTRA: reset aranjament, verificare de versiune, /info si ghidul de pornire.
-- Toate stau in tabela App: Lua accepta cel mult 200 de variabile locale intr-un fisier si
-- limita e aproape atinsa, asa ca modulele noi nu mai primesc fiecare un nume propriu.
-- ============================================================
App = { Ver = {}, Info = {}, Wizard = {} }

-- schimbarea factiunii (combo, ghid, Interfata): tema, statia potrivita si un mesaj clar in chat.
-- quiet = fara ferestre deschise / inchise (din ghidul de pornire)
function App.setFaction(id, quiet)
    local f = Factions.byId[id]
    if not f then return end
    local wasDept = App.PD ~= nil and App.PD.isDept()
    cfg.main.factionId, cfg.main.theme = f.id, f.theme
    saveCfg()
    applyTheme()
    if not App.PD then
        if id == "pd" or id == "fbi" or id == "ng" then err(tr("pd_missing", tostring(App.PDError))) end
        return
    end
    local dept = App.PD.isDept()
    if dept and not wasDept then
        if not quiet then State.sic[0], App.PD.open[0] = false, true end
        msg(tr("iface_now_pd", App.PD.command()))
    elseif wasDept and not dept then
        if not quiet then App.PD.open[0] = false end
        msg(tr("iface_now_si"))
    end
    trace("factiune: " .. tostring(id) .. (dept and " (departament)" or ""))
end

-- randul Interfata, sus in /sih -> General: un click schimba statia, comenzile, bind-urile, tutorialul si culorile
function App.ifaceRow()
    local dept = App.PD ~= nil and App.PD.isDept()
    TC(DIM, u8(string.upper(tr("iface"))))
    imgui.SameLine()
    local w = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
    local siLabel = (State.icons and (fa.GRADUATION_CAP .. "  ") or "") .. u8(tr("iface_si"))
    if toggleButton(siLabel .. "##ifsi", cfg.main.factionId == "si", imgui.ImVec2(w, px(30))) and cfg.main.factionId ~= "si" then
        App.setFaction("si")
    end
    if imgui.IsItemHovered() then TIP(u8(tr("iface_tip"))) end
    imgui.SameLine()
    local pdLabel = (State.icons and (fa.SHIELD_HALVED .. "  ") or "") .. u8(tr("iface_pd"))
    if toggleButton(pdLabel .. "##ifpd", dept, imgui.ImVec2(w, px(30))) and not dept then App.setFaction("pd") end
    if imgui.IsItemHovered() then TIP(u8(tr("iface_tip"))) end
    if App.PDError then
        imgui.PushStyleColor(imgui.Col.Text, RED)
        TW(u8(tr("pd_missing", App.PDError)))
        imgui.PopStyleColor()
    end
    imgui.Spacing()
end

-- conditia de asezare a ferestrelor: normal "prima data", dar o jumatate de secunda dupa
-- "Reseteaza aranjamentul" devine "intotdeauna", ca tot ce e pe ecran sa sara la locul implicit
function App.cond()
    if State.repos and os.clock() - State.repos < 0.5 then return imgui.Cond.Always end
    return imgui.Cond.FirstUseEver
end

-- pozitiile si marimile retinute in ini (ferestre + HUD-uri)
K.LAYOUT_KEYS = {
    "sicPosX", "sicPosY", "sicW", "sicH", "wmPosX", "wmPosY", "wmW", "wmH", "reportX", "reportY",
    "hudReportX", "hudReportY", "hudCheckX", "hudCheckY", "hudDockX", "hudDockY", "hudLegendX", "hudLegendY",
    "pdcX", "pdcY", "pdcW", "pdcH",
}

function App.resetLayout()
    for _, k in ipairs(K.LAYOUT_KEYS) do cfg.main[k] = -1 end
    -- si orice pozitie de HUD adaugata mai tarziu
    for k in pairs(cfg.main) do
        local name = tostring(k)
        if name:find("^hud") and (name:sub(-1) == "X" or name:sub(-1) == "Y") then cfg.main[k] = -1 end
    end
    cfg.main.hudLegendW = nil     -- fara valoare = latimea implicita a legendei
    cfg.main.dockHoriz = 0
    saveCfg()
    State.repos = os.clock()      -- ferestrele citesc asta prin App.cond() si sar la loc
    msg(tr("reset_done"))
    trace("aranjament resetat")
end

-- ------------------------------------------------------------
-- VERIFICARE DE VERSIUNE: ia un fisier text de pe sursa oficiala si compara numerele.
-- Nu trimite nimic despre tine si se poate opri din Features.
-- ------------------------------------------------------------
K.VER_URL  = "https://raw.githubusercontent.com/ZioAdolf-modding/SICHelper/main/VERSION"
K.VER_FILE = getWorkingDirectory() .. "/config/SICHelper_version.txt"
K.VER_WAIT = 20    -- secunde cat asteptam fisierul descarcat

-- numarul versiunii (1.7.0) si eticheta de pre-lansare ("beta", "rc.1"; nil = versiune finala)
function App.Ver.parse(s)
    local txt = tostring(s or "")
    local a, b, c = txt:match("(%d+)%.(%d+)%.(%d+)")
    if not a then return nil end
    return tonumber(a) * 1000000 + tonumber(b) * 1000 + tonumber(c), txt:match("%d+%.%d+%.%d+%-([%w%.%-]+)")
end

-- e versiunea de pe sursa oficiala mai noua decat a mea? La acelasi numar, versiunea finala bate
-- pre-lansarea (1.7.0 > 1.7.0-beta), iar intre doua pre-lansari decide eticheta (beta < rc).
function App.Ver.isNewer(remote, mine)
    local rn, rp = App.Ver.parse(remote)
    local mn, mp = App.Ver.parse(mine)
    if not rn then return false end
    if not mn then return true end
    if rn ~= mn then return rn > mn end
    if rp == mp then return false end
    if not rp then return true end        -- finala bate pre-lansarea cu acelasi numar
    if not mp then return false end
    return rp > mp
end

function App.Ver.check()
    if App.Ver.asked or not feat("verCheck") then return end
    App.Ver.asked = true
    if type(downloadUrlToFile) ~= "function" then return end
    os.remove(K.VER_FILE)
    if pcall(downloadUrlToFile, K.VER_URL, K.VER_FILE) then
        App.Ver.waiting = os.clock()
        trace("verificare de versiune pornita")
    end
end

-- fisierul apare asincron: il citim din bucla principala, o singura data
function App.Ver.update()
    if not App.Ver.waiting then return end
    if os.clock() - App.Ver.waiting > K.VER_WAIT then App.Ver.waiting = nil return end
    if not doesFileExist(K.VER_FILE) then return end
    local f = io.open(K.VER_FILE, "r")
    if not f then return end
    local s = f:read("*a") or ""
    f:close()
    local n = App.Ver.parse(s)
    if not n then return end          -- fisierul e inca incomplet: mai incercam la urmatorul frame
    App.Ver.waiting = nil
    App.Ver.latest = (s:match("[%w%.%-]+") or "?")
    if App.Ver.isNewer(App.Ver.latest, VERSION) then
        App.Ver.newer = true
        msg(tr("ver_new", App.Ver.latest))
    else
        trace("versiune la zi (" .. tostring(App.Ver.latest) .. ")")
    end
end

-- linia din /sih: apare doar cand exista o versiune mai noua
function App.Ver.row()
    if not App.Ver.newer then return end
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    imgui.PushStyleColor(imgui.Col.ChildBg, t.hover)
    imgui.BeginChild("##vernew", imgui.ImVec2(0, imgui.GetTextLineHeightWithSpacing() + px(10)), true)
    if State.icons then TC(t.accent, fa.CIRCLE_ARROW_DOWN) imgui.SameLine(0, 8) end
    TC(t.accent, u8(tr("ver_new", App.Ver.latest)))
    imgui.SameLine()
    TC(DIM, u8(tr("ver_src")))
    imgui.EndChild()
    imgui.PopStyleColor()
    imgui.Spacing()
end

-- ------------------------------------------------------------
-- /info <id>: "buletinul" jucatorului. Datele vin din raspunsul (ascuns) la /id, din ce e
-- streamat langa tine si din notitele tale despre el (fisier separat, editabil).
-- ------------------------------------------------------------
App.Info.open  = new.bool(false)
App.Info.fade  = Fade.new()
App.Info.cache = {}     -- dupa nume: ultimul raspuns la /id
App.Info.byId  = {}     -- acelasi lucru, dupa id (factiunea se afla si pentru plata catre aliati)
App.Info.tex   = {}     -- imaginile de skin deja incarcate (id -> textura sau false)
K.INFO_ID_TIMEOUT = 6   -- secunde de asteptat raspunsul la /id
K.INFO_SKIN_DIR = getWorkingDirectory() .. "/resource/skins/"
K.PLAYERS_FILE  = getWorkingDirectory() .. "/config/SICHelper_players.lua"
K.INFO_LEFT     = 186   -- coloana cu skin-ul (px la 1080p)

-- fisierul cu notitele tale despre jucatori (etichete + comentariu liber), pe nume
function App.Info.loadPlayers()
    App.Info.players = nil
    if doesFileExist(K.PLAYERS_FILE) then
        local chunk = loadfile(K.PLAYERS_FILE)
        if chunk then
            local ok, res = pcall(chunk)
            if ok and type(res) == "table" then App.Info.players = res end
        end
    end
    App.Info.players = App.Info.players or {}
end

function App.Info.savePlayers()
    if not App.Info.players then return end
    local f = io.open(K.PLAYERS_FILE, "w")
    if not f then return end
    f:write("-- SICHelper - notitele tale despre jucatori (/info). Se poate edita si de aici.\n")
    f:write("return {\n")
    for name, p in pairs(App.Info.players) do
        -- jucatorii despre care nu s-a notat nimic nu ajung in fisier
        local empty = (tostring(p.note or "") == "") and #(p.tags or {}) == 0 and not p.given
        if not empty then
            f:write(string.format("  [%q] = { note = %q, tags = {", tostring(name), tostring(p.note or "")))
            for _, tag in ipairs(p.tags or {}) do f:write(string.format(" %q,", tostring(tag))) end
            f:write(" }")
            if p.given then f:write(string.format(", given = %d", tonumber(p.given) or 0)) end
            if p.lastLic then f:write(string.format(", lastLic = %q", tostring(p.lastLic))) end
            if p.lastAt then f:write(string.format(", lastAt = %d", tonumber(p.lastAt) or 0)) end
            f:write(" },\n")
        end
    end
    f:write("}\n")
    f:close()
end

function App.Info.player(name)
    if not name or name == "" then return nil end
    if not App.Info.players then App.Info.loadPlayers() end
    local p = App.Info.players[name] or { note = "", tags = {} }
    p.tags, p.note = p.tags or {}, p.note or ""
    App.Info.players[name] = p
    return p
end

function App.Info.hasTag(p, tag)
    for _, t in ipairs((p and p.tags) or {}) do if t == tag then return true end end
    return false
end

function App.Info.toggleTag(name, tag)
    local p = App.Info.player(name)
    if not p then return end
    for i, t in ipairs(p.tags) do
        if t == tag then table.remove(p.tags, i) App.Info.savePlayers() return end
    end
    table.insert(p.tags, tag)
    App.Info.savePlayers()
end

-- fiecare licenta acceptata se noteaza in fisierul de jucatori (istoricul din /info)
function App.Info.remember(name, licId)
    if not name or name == "" then return end
    local p = App.Info.player(name)
    if not p then return end
    p.given = (tonumber(p.given) or 0) + 1
    p.lastLic = licId or p.lastLic
    p.lastAt = os.time()
    App.Info.savePlayers()
end

-- Raspunsul la /id, citit pe segmente (nu dupa pozitie): ultimul segment NU e mereu factiunea.
--   "(947) [AIM]DroneGOAT | Ping: 108 | FPS: 110 | Nivel: 157 | SF School Instructors (6)"
--   "(121) [XO].YOUMADENOTME | Ping: 44 | FPS: 88 | Nivel: 33 | Onyx Skin: 289"
-- "<ceva> Skin: N" e id-ul skin-ului (Onyx / Diamond), nu o factiune; il folosim pentru poza.
function App.Info.parse(plain)
    local d, first = {}, true
    d.id   = tonumber(plain:match("^%s*%((%d+)%)"))
    d.name = plain:match("^%s*%(%d+%)%s*(.-)%s*|")
    for seg in plain:gmatch("[^|]+") do
        local s = seg:gsub("^%s+", ""):gsub("%s+$", "")
        if first then
            first = false                                  -- primul segment e "(id) nume"
        elseif s:match("^[Pp]ing:") then
            d.ping = tonumber(s:match("(%d+)"))
        elseif s:match("^FPS:") then
            d.fps = tonumber(s:match("(%d+)"))
        elseif s:match("^[NL][ie]vel:") then
            d.level = tonumber(s:match("(%d+)"))
        elseif s:match("[Ss]kin:%s*%d+") then
            d.skin = tonumber(s:match("[Ss]kin:%s*(%d+)"))
            d.skinKind = s:match("^(%a+)%s+[Ss]kin")       -- "Onyx", "Diamond"
        else
            local fac, rank = s:match("^(.-)%s*%((%d+)%)$")
            if fac and fac ~= "" then
                d.faction, d.rank = fac, tonumber(rank)
            elseif s ~= "" and App.Info.factionId(s) then
                d.faction = s                              -- factiune fara rang in linie
            elseif s ~= "" then
                d.extra = d.extra and (d.extra .. "   -   " .. s) or s
            end
        end
    end
    if not d.level and not d.ping then return nil end
    return d
end

-- id-ul factiunii din numele scris de server (fara prefixul orasului)
function App.Info.factionId(label)
    if not label then return nil end
    local name = label:gsub("^%s*[LS][SVF]%s+", ""):lower()
    for _, f in ipairs(FACTIONS) do
        local l = f.label:lower()
        if name == l or name:find(l, 1, true) or l:find(name, 1, true) then return f.id end
    end
    return nil
end

function App.Info.show(id)
    id = requireOnline(id)
    if not id then return end
    App.Info.id = id
    App.Info.open[0] = true
    App.Info.ask(id)
end

function App.Info.ask(id)
    if not id then return end
    App.Info.pending = { id = id, at = os.clock() }
    Queue.pushFront("/id " .. id)
    trace("info: /id " .. tostring(id))
end

-- linia de la server; true = a fost raspunsul cerut de noi si nu se mai afiseaza in chat
function App.Info.onLine(plain)
    local p = App.Info.pending
    if not p or os.clock() - p.at > K.INFO_ID_TIMEOUT then return false end
    local d = App.Info.parse(plain)
    if not d then return false end
    App.Info.pending = nil
    d.id, d.at = d.id or p.id, os.clock()
    if d.name then App.Info.cache[d.name] = d end
    if d.id then App.Info.byId[d.id] = d end
    if d.level and d.id then rememberLevel(d.id, d.level) end
    App.Info.data = d
    return true
end

-- ce se vede local, doar pentru jucatorii streamati. Ca la monitorizarea HP-ului, pe ped-ul altui
-- jucator NU dam opcode-uri de joc (crapa clientul): citim din memorie, cu verificari.
function App.Info.nearby(id)
    local out = {}
    if not id then return out end
    local ok, found, ped = pcall(sampGetCharHandleBySampPlayerId, id)
    if not ok or not found or not ped or not doesCharExist(ped) then return out end
    out.streamed = true
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    out.dist = math.floor(getDistanceBetweenCoords3d(mx, my, mz, getCharCoordinates(ped)) + 0.5)
    local pedPtr = getCharPointer(ped)
    if not pedPtr or pedPtr == 0 then return out end
    local skin = readMemory(pedPtr + 0x22, 2, false)     -- CEntity + 0x22 = model
    if skin and skin >= 0 and skin <= 311 then out.skin = skin end
    local vehPtr = readMemory(pedPtr + 0x58C, 4, false)  -- CPed + 0x58C = vehiculul in care e
    if vehPtr and vehPtr ~= 0 then
        local model = readMemory(vehPtr + 0x22, 2, false)
        if model and model >= 400 and model <= 611 then
            local okn, nm = pcall(getNameOfVehicleModel, model)
            if okn then out.vehName = nm end
        end
        local hp = representIntAsFloat(readMemory(vehPtr + 0x4C0, 4, false))
        if hp and hp == hp and hp >= 0 and hp <= 5000 then out.vehHp = math.floor(hp) end
    end
    return out
end

function App.Info.near(id)
    local ok, res = pcall(App.Info.nearby, id)
    if ok and type(res) == "table" then return res end
    return {}
end

-- latimea si inaltimea unui PNG, citite din antetul IHDR (4 octeti fiecare, big-endian)
function App.Info.pngSize(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local head = f:read(24) or ""
    f:close()
    if #head < 24 or head:sub(2, 4) ~= "PNG" then return nil end
    local function be32(s)
        local a, b, c, d = s:byte(1, 4)
        if not d then return nil end
        return ((a * 256 + b) * 256 + c) * 256 + d
    end
    local w, hh = be32(head:sub(17, 20)), be32(head:sub(21, 24))
    if not w or not hh or w < 1 or hh < 1 then return nil end
    return w, hh
end

function App.Info.skinTex(skin)
    if not skin then return nil end
    App.Info.texWH = App.Info.texWH or {}
    if App.Info.tex[skin] ~= nil then return App.Info.tex[skin] or nil end
    local path = K.INFO_SKIN_DIR .. tostring(skin) .. ".png"
    if not doesFileExist(path) then App.Info.tex[skin] = false return nil end
    local ok, tex = pcall(imgui.CreateTextureFromFile, path)
    App.Info.tex[skin] = (ok and tex) or false
    if App.Info.tex[skin] then
        local w, hh = App.Info.pngSize(path)
        App.Info.texWH[skin] = { w = w or 165, h = hh or 300 }
    end
    return App.Info.tex[skin] or nil
end

-- un panou mic: eticheta gri deasupra, valoarea dedesubt
function App.Info.card(tag, label, value, w, col)
    imgui.BeginChild("##ic" .. tag, imgui.ImVec2(w, px(44)), true)
    TC(DIM, u8(string.upper(label)))
    TC(col or TEXT, u8(value))
    imgui.EndChild()
end

-- eticheta de sub poza: "SKIN 289" sau "SKIN 289 (Onyx)"
function App.Info.skinLabel(skin, kind)
    if not skin then return tr("info_no_skin") end
    local s = string.upper(tr("info_skin")) .. "  " .. tostring(skin)
    if kind then s = s .. "  (" .. tostring(kind) .. ")" end
    return s
end

-- coloana din stanga: imaginea de skin, daca exista pachetul, altfel o silueta desenata
function App.Info.skinBox(skin, h, kind)
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    imgui.BeginChild("##infoskin", imgui.ImVec2(px(K.INFO_LEFT), h), true)
    local tex = App.Info.skinTex(skin)
    local avail = imgui.GetContentRegionAvail()
    local pad = imgui.GetStyle().WindowPadding.x
    -- eticheta de sub poza, centrata
    local function label()
        local s = u8(App.Info.skinLabel(skin, kind))
        imgui.SetCursorPosX(math.max(pad, (avail.x - imgui.CalcTextSize(s).x) / 2 + pad))
        TC(DIM, s)
    end
    if tex then
        -- poza isi pastreaza proportiile (sursele sunt inalte, 165x300): se incadreaza, nu se intinde
        local wh = (App.Info.texWH or {})[skin] or { w = 165, h = 300 }
        local maxW, maxH = avail.x, avail.y - px(18)
        local scale = math.min(maxW / wh.w, maxH / wh.h)
        local iw, ih = wh.w * scale, wh.h * scale
        if maxH - ih > 1 then imgui.Dummy(imgui.ImVec2(1, (maxH - ih) / 2)) end
        imgui.SetCursorPosX((avail.x - iw) / 2 + pad)
        imgui.Image(tex, imgui.ImVec2(iw, ih))
        label()
    else
        -- silueta simpla: cap plus corp
        local p0 = imgui.GetCursorScreenPos()
        local dl = imgui.GetWindowDrawList()
        local cx, cy = p0.x + avail.x / 2, p0.y + (avail.y - px(20)) / 2
        local col = imgui.GetColorU32Vec4(V4(t.border.x, t.border.y, t.border.z, 1))
        dl:AddCircleFilled(imgui.ImVec2(cx, cy - px(34)), px(20), col, 24)
        dl:AddRectFilled(imgui.ImVec2(cx - px(26), cy - px(8)), imgui.ImVec2(cx + px(26), cy + px(52)), col, px(10))
        imgui.Dummy(imgui.ImVec2(avail.x, math.max(px(20), avail.y - px(22))))
        label()
    end
    imgui.EndChild()
end

function App.Info.pills(id)
    local lics = Candidate.licensesOf(id)
    if not lics then
        TC(DIM, u8(tr("info_lic_none")))
        if imgui.IsItemHovered() then TIP(u8(tr("info_lic_tip"))) end
        return
    end
    for i, lic in ipairs(Licenses.real) do
        local have = lics[lic.id]
        local ok = (have and (tostring(have.status):find("valid") or tostring(have.status):find("activ"))) and true or false
        toggleButton(u8(lic.short .. (have and (ok and "  v" or "  x") or "  ?")) .. "##pill" .. lic.id,
                     ok, imgui.ImVec2(px(62), 22), OK_GREEN, have and RED or DIM)
        if imgui.IsItemHovered() then
            local txt = lic.label .. ": " .. (have and tostring(have.status) or "?")
            if have and have.hours then txt = txt .. " (" .. have.hours .. "h)" end
            TIP(u8(txt))
        end
        if i < #Licenses.real then imgui.SameLine() end
    end
end

function App.Info.notes(name)
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local p = App.Info.player(name)
    if not p then TC(DIM, u8(tr("info_no_player"))) return end
    State.infoNoteBuf = State.infoNoteBuf or new.char[512]()
    if App.Info.noteFor ~= name then     -- alt jucator: aducem nota lui in camp
        App.Info.noteFor = name
        imgui.StrCopy(State.infoNoteBuf, p.note or "")
        App.Info.noteWas = false
    end
    TC(t.accent, u8(string.upper(tr("info_notes"))))
    local tags = (App.PD and App.PD.isDept() and App.PD.tags()) or Data.player_tags or {}
    for i, tag in ipairs(tags) do
        if toggleButton(u8(tag) .. "##tag" .. i, App.Info.hasTag(p, tag), imgui.ImVec2(0, 22)) then
            App.Info.toggleTag(name, tag)
        end
        if i < #tags then imgui.SameLine() end
    end
    imgui.InputTextMultiline("##infonote", State.infoNoteBuf, 512, imgui.ImVec2(-1, px(52)))
    if imgui.IsItemHovered() then TIP(u8(tr("info_note_tip"))) end
    local active = imgui.IsItemActive()
    if App.Info.noteWas and not active then     -- ai iesit din camp: salvam
        p.note = ffi.string(State.infoNoteBuf)
        App.Info.savePlayers()
        trace("info: nota salvata pentru " .. tostring(name))
    end
    App.Info.noteWas = active
end

function App.Info.draw()
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local id = App.Info.id
    local d  = App.Info.data or {}
    local name = d.name or (id and playerName(id)) or "?"
    local near = App.Info.near(id)
    State.infoBuf = State.infoBuf or new.char[8]()

    -- cap: nume, id si campul pentru alt ID
    if State.icons then TC(t.accent, fa.ID_CARD) imgui.SameLine(0, 8) end
    TC(t.accent, u8(string.upper(tr("info_title"))))
    imgui.SameLine()
    TC(TEXT, u8(name))
    imgui.SameLine()
    TC(DIM, "(" .. tostring(id or "?") .. ")")
    alignRight(px(132))
    imgui.PushItemWidth(px(46))
    local go = imgui.InputText("##infoid", State.infoBuf, 8,
                               bit.bor(imgui.InputTextFlags.CharsDecimal, imgui.InputTextFlags.EnterReturnsTrue))
    imgui.PopItemWidth()
    if imgui.IsItemHovered() then TIP(u8(tr("info_id_tip"))) end
    imgui.SameLine()
    if primaryButton(u8(tr("info_show")) .. "##infogo", imgui.ImVec2(px(78), 22)) then go = true end
    if go then
        local want = tonumber(ffi.string(State.infoBuf))
        if want then App.Info.show(want) end
    end
    if App.Info.pending then
        imgui.SameLine()
        TC(DIM, u8(tr("info_wait")))
    end
    imgui.Separator()

    local bodyH = -(imgui.GetTextLineHeightWithSpacing() * 3 + px(104))
    imgui.BeginChild("##infobody", imgui.ImVec2(0, bodyH), false)
    local h = imgui.GetContentRegionAvail().y
    App.Info.skinBox(near.skin or d.skin, h, d.skinKind)
    imgui.SameLine()
    imgui.BeginChild("##inforight", imgui.ImVec2(0, h), false)

    local gap = imgui.GetStyle().ItemSpacing.x
    local w1 = imgui.GetContentRegionAvail().x - px(188) - gap * 2
    App.Info.card("lvl", tr("info_level"), d.level and tostring(d.level) or "?", w1, t.accent)
    imgui.SameLine()
    App.Info.card("ping", "ping", d.ping and tostring(d.ping) or "?", px(90))
    imgui.SameLine()
    App.Info.card("fps", "fps", d.fps and tostring(d.fps) or "?", px(90))

    -- factiunea si rangul (numarul din /id devine numele rangului)
    local facLine = d.faction or d.extra or tr("info_no_faction")
    if d.rank then
        facLine = facLine .. "   -   " .. tostring(d.rank) .. "  "
                  .. tostring(Factions.rankName(App.Info.factionId(d.faction), d.rank))
    end
    App.Info.card("fac", tr("info_faction"), facLine, -1, d.faction and t.accent or DIM)

    imgui.BeginChild("##infolic", imgui.ImVec2(-1, px(52)), true)
    TC(DIM, u8(string.upper(tr("info_lics"))))
    App.Info.pills(id)
    imgui.EndChild()

    local state = near.streamed and tr("info_near", near.dist) or tr("info_far")
    if near.vehName then
        state = state .. "   -   " .. tr("info_in_veh", near.vehName)
        if near.vehHp then state = state .. " (" .. near.vehHp .. " HP)" end
    end
    local w2 = imgui.GetContentRegionAvail().x - px(86) - gap
    App.Info.card("state", tr("info_state"), state, w2)
    imgui.SameLine()
    App.Info.card("lang", tr("info_lang"), string.upper(tostring(Langs.of(id) or cfg.main.procLang)), px(84))

    -- istoricul tau cu el (din fisierul de jucatori)
    local p = App.Info.player(name ~= "?" and name or nil)
    local hist = tr("info_hist_none")
    if p and (tonumber(p.given) or 0) > 0 then
        hist = tr("info_hist", p.given)
        if p.lastLic then
            local lic = Licenses.byId[p.lastLic]
            hist = hist .. "   -   " .. tr("info_hist_last", (lic and lic.label) or tostring(p.lastLic),
                                           p.lastAt and os.date("%d.%m", p.lastAt) or "?")
        end
    end
    App.Info.card("hist", tr("info_hist_title"), hist, -1)
    imgui.EndChild()
    imgui.EndChild()

    App.Info.notes(name ~= "?" and name or nil)

    imgui.Separator()
    -- la departamente: suspect / control / somatie in locul butoanelor de instructor
    if App.PD and App.PD.isDept() then App.PD.infoButtons(id, name) return end
    local bw = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x * 3) / 4
    if primaryButton(u8(tr("sic_withme")) .. "##iwm", imgui.ImVec2(bw, 24)) and id then Withme.ask(id) end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_withme_btn"))) end
    imgui.SameLine()
    if toggleButton("Sxwas##isx", false, imgui.ImVec2(bw, 24)) and id then sxwas(id) end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_sxwas_btn"))) end
    imgui.SameLine()
    if toggleButton(u8(tr("info_cand")) .. "##ical", false, imgui.ImVec2(bw, 24)) and id then
        Candidate.set(id, name ~= "?" and name or nil)
        msg(tr("candidate_is", nameTag(id, playerName(id))))
    end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_cand_btn"))) end
    imgui.SameLine()
    if toggleButton(u8(tr("info_copy")) .. "##icp", false, imgui.ImVec2(bw, 24)) then
        imgui.SetClipboardText(name)
        msg(tr("notes_copied", name))
    end
    if imgui.IsItemHovered() then TIP(u8(tr("info_copy_tip"))) end
end


-- ------------------------------------------------------------
-- FACTIUNEA ALIATA: licenta data unui membru al factiunii aliate se plateste inapoi, cu /pay.
-- Factiunea jucatorului vine din raspunsul la /id, pe care helperul il citeste oricum.
-- Suma e pretul licentei din fisierul de date, dupa nivelul lui (fara bonusul AR: acela vine
-- de la factiune, nu din buzunarul jucatorului).
-- Daca nu ti-ai deblocat banii cu /pin, plata asteapta si pleaca singura imediat ce dai /pin.
-- ------------------------------------------------------------
App.Ally = { queue = {} }

-- factiunea aliata: intai alegerea ta din /sih, apoi cea din fisierul de date (pe oras)
function App.Ally.who()
    local pick = tostring(cfg.main.allyId or "")
    if pick ~= "" then return pick end
    local set = Data and Data.allies and Data.allies[tostring(cfg.main.factionId)]
    if type(set) ~= "table" then return "" end
    return tostring(set[tostring(cfg.main.faction)] or "")
end

-- e jucatorul in factiunea aliata? (dupa ce am retinut de la /id)
function App.Ally.is(id, name)
    local ally = App.Ally.who()
    if ally == "" then return false end
    local d = (name and App.Info.cache[name]) or (id and App.Info.byId[id])
    if not d or not d.faction then return false end
    return App.Info.factionId(d.faction) == ally
end

-- cat a platit jucatorul: pretul licentei la nivelul lui
function App.Ally.amount(id, licId)
    local lic = Licenses.byId[licId]
    if not lic then return nil end
    local level = playerLevel(id)
    if not level then
        local d = id and App.Info.byId[id]
        level = d and d.level
    end
    if not level then return nil end
    return licensePrice(lic, level)
end

-- apelat cand jucatorul a acceptat licenta (adica atunci cand banii au ajuns la tine)
function App.Ally.onGiven(id, name, licId)
    if not feat("allyPay") or not id then return end
    if id == myPlayerId() then return end            -- /giveme: sunt banii mei
    if not App.Ally.is(id, name) then return end
    local sum = App.Ally.amount(id, licId)
    if not sum or sum <= 0 then
        trace("aliat: nu stiu pretul pentru " .. tostring(licId) .. " (nivel necunoscut)")
        return
    end
    table.insert(App.Ally.queue, { id = id, name = name or playerName(id), sum = sum, at = os.clock() })
    App.Ally.flush()
end

-- trimite ce se poate; ce nu (lipseste /pin) ramane in coada si pleaca mai tarziu
function App.Ally.flush()
    local held = 0
    for i = #App.Ally.queue, 1, -1 do
        local p = App.Ally.queue[i]
        if os.clock() - p.at > K.ALLY_MAX_AGE then
            table.remove(App.Ally.queue, i)
            trace("aliat: plata expirata pentru " .. tostring(p.name))
        elseif State.pinOk then
            table.remove(App.Ally.queue, i)
            Queue.push("/pay " .. p.id .. " " .. p.sum, K.ALLY_DELAY)
            App.Ally.last = { id = p.id, name = p.name, sum = p.sum, at = os.clock() }
            msg(tr("ally_paid", money(p.sum), nameTag(p.id, p.name)))
            Notify.push(tr("ally_title"), tr("ally_paid_short", money(p.sum), tostring(p.name)))
            trace("aliat: /pay " .. p.id .. " " .. p.sum)
        else
            held = held + 1
        end
    end
    if held > 0 and (not App.Ally.warnedAt or os.clock() - App.Ally.warnedAt > K.ALLY_WARN) then
        App.Ally.warnedAt = os.clock()
        err(tr("ally_pin"))
        Notify.push(tr("ally_title"), tr("ally_pin_short"))
    end
end

-- serverul ne-a trimis la /pin dupa ce am incercat sa platim: punem plata inapoi in coada
function App.Ally.onPinNeeded()
    State.pinOk = false
    local p = App.Ally.last
    App.Ally.last = nil
    if p and os.clock() - p.at < 15 then
        table.insert(App.Ally.queue, { id = p.id, name = p.name, sum = p.sum, at = os.clock() })
        trace("aliat: plata catre " .. tostring(p.name) .. " amanata, lipseste /pin")
    end
    App.Ally.warnedAt = nil
    App.Ally.flush()
end
-- ------------------------------------------------------------
-- GHIDUL DE PORNIRE: patru pasi la prima instalare (limba, factiunea, trei taste, gata).
-- Se poate redeschide oricand din /sih -> General.
-- ------------------------------------------------------------
App.Wizard.open = new.bool(false)
App.Wizard.fade = Fade.new()
App.Wizard.step = 1
K.WIZ_STEPS = 4
K.WIZ_KEYS  = { "acc", "sic", "cursor" }   -- tastele propuse la pasul 3
K.WIZ_KEYS_PD = { "sic", "pd_radar", "cursor" }   -- la departamente: statia, radarul, cursorul

function App.Wizard.start(force)
    if not force and (tonumber(cfg.main.wizardDone) or 0) == 1 then return end
    App.Wizard.step = 1
    App.Wizard.open[0] = true
    trace("ghid de pornire deschis")
end

function App.Wizard.finish()
    cfg.main.wizardDone = 1
    saveCfg()
    App.Wizard.open[0] = false
    Keys.capturing = nil
end

function App.Wizard.dots()
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    for i = 1, K.WIZ_STEPS do
        local on = (i == App.Wizard.step)
        local glyph = State.icons and (on and fa.CIRCLE or fa.MINUS) or (on and "o" or "-")
        TC(on and t.accent or DIM, glyph)
        imgui.SameLine(0, 5)
    end
    imgui.NewLine()
end

function App.Wizard.draw()
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local myFaction = Factions.byId[cfg.main.factionId] or Factions.byId.si
    local step = App.Wizard.step

    App.Wizard.dots()
    TC(DIM, u8(tr("wiz_step", step, K.WIZ_STEPS)))
    imgui.Spacing()

    imgui.BeginChild("##wizbody", imgui.ImVec2(0, -(px(38))), false)
    if step == 1 then
        sectionHeader(tr("wiz_lang"))
        TC(DIM, u8(tr("wiz_lang_hint")))
        imgui.Spacing()
        local w = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
        if toggleButton("Romana##wizro", cfg.main.uiLang == K.LANG_RO, imgui.ImVec2(w, px(38))) then
            cfg.main.uiLang, cfg.main.procLang = K.LANG_RO, K.LANG_RO
            State.sicLang = K.LANG_RO
            saveCfg()
        end
        imgui.SameLine()
        if toggleButton("English##wizen", cfg.main.uiLang == K.LANG_EN, imgui.ImVec2(w, px(38))) then
            cfg.main.uiLang, cfg.main.procLang = K.LANG_EN, K.LANG_EN
            State.sicLang = K.LANG_EN
            saveCfg()
        end

    elseif step == 2 then
        sectionHeader(tr("wiz_faction"))
        TC(DIM, u8(tr("wiz_faction_hint")))
        imgui.Spacing()
        imgui.PushItemWidth(px(260))
        if imgui.BeginCombo("##wizfac", u8(myFaction.label)) then
            for _, f in ipairs(Factions.list) do
                local r, g, b = hexToRgb(f.hex)
                imgui.PushStyleColor(imgui.Col.Text, V4(math.max(r, 0.35), math.max(g, 0.35), math.max(b, 0.35)))
                if imgui.Selectable(u8(f.label) .. "##wf" .. f.id, f.id == myFaction.id) then
                    App.setFaction(f.id, true)
                end
                imgui.PopStyleColor()
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
        if myFaction.cities then
            imgui.Spacing()
            TX(u8(tr("city")))
            local pick = choiceButtons("wizcity", FACTION_OPTIONS, cfg.main.faction, 52)
            if pick then cfg.main.faction = pick saveCfg() end
        end

    elseif step == 3 then
        sectionHeader(tr("wiz_keys"))
        TC(DIM, u8(tr("wiz_keys_hint")))
        imgui.Spacing()
        for _, aid in ipairs((App.PD and App.PD.isDept()) and K.WIZ_KEYS_PD or K.WIZ_KEYS) do
            local a = Actions.byId[aid]
            if a then
                TX(u8(actionLabel(a)))
                alignRight(K.KEY_W)
                keyButton("a:" .. aid, Keys.nameOf(aid), false, K.KEY_W)
                cfg.binds[aid .. "_on"] = 1
            end
        end
        imgui.Spacing()
        TC(DIM, u8(Keys.capturing and tr("press_key") or tr("wiz_keys_tip")))

    else
        local dept = App.PD and App.PD.isDept()
        sectionHeader(tr("wiz_done"))
        guideLine("1.", tr(dept and "wiz_pd1" or "wiz_done1"))
        guideLine("2.", tr(dept and "wiz_pd2" or "wiz_done2"))
        guideLine("3.", tr(dept and "wiz_pd3" or "wiz_done3"))
        imgui.Spacing()
        TC(DIM, u8(tr("wiz_done_hint")))
        imgui.Spacing()
        if primaryButton(u8(tr(dept and "wiz_open_pdc" or "wiz_open_sic")) .. "##wizsic", imgui.ImVec2(px(170), 26)) then
            App.Wizard.finish()
            if dept then App.PD.open[0] = true else State.sic[0] = true end
        end
    end
    imgui.EndChild()

    -- navigarea
    imgui.Separator()
    if step > 1 then
        if toggleButton(u8(tr("wiz_back")) .. "##wizback", false, imgui.ImVec2(px(90), 24)) then
            App.Wizard.step = step - 1
        end
        imgui.SameLine()
    end
    alignRight(px(200))
    if toggleButton(u8(tr("wiz_skip")) .. "##wizskip", false, imgui.ImVec2(px(90), 24)) then App.Wizard.finish() end
    imgui.SameLine()
    if primaryButton(u8(step < K.WIZ_STEPS and tr("wiz_next") or tr("wiz_finish")) .. "##wiznext",
                     imgui.ImVec2(px(100), 24)) then
        if step < K.WIZ_STEPS then App.Wizard.step = step + 1 else App.Wizard.finish() end
    end
end

local function drawGeneralTab()
    local myFaction = Factions.byId[cfg.main.factionId] or Factions.byId.si
    local currentTheme = Themes.byId[cfg.main.theme] or Themes.byId.si

    App.Ver.row()
    App.ifaceRow()

    -- cautare peste toate setarile din toate tab-urile
    State.searchBuf = State.searchBuf or new.char[64]()
    if State.icons then TC(DIM, fa.MAGNIFYING_GLASS) imgui.SameLine(0, 8) end
    imgui.PushItemWidth(-px(70))
    imgui.InputTextWithHint("##sihsearch", u8(tr("search_hint")), State.searchBuf, 64)
    imgui.PopItemWidth()
    local needle = ffi.string(State.searchBuf):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if needle ~= "" then
        imgui.SameLine()
        if imgui.Button("x##searchclr", imgui.ImVec2(px(24), 22)) then imgui.StrCopy(State.searchBuf, "") needle = "" end
    end
    imgui.Spacing()

    if needle ~= "" then
        Gen.results(needle)
        return
    end

    -- LIMBA
    local function langName(v) return (v == K.LANG_EN) and "English" or "Romana" end
    if Gen.section("lang", tr("sec_lang"), langName(cfg.main.uiLang) .. " / " .. langName(cfg.main.procLang)) then
        labeled(tr("ui_lang"))
        local pick = choiceButtons("uilang", LANG_OPTIONS, cfg.main.uiLang, 80)
        if pick then cfg.main.uiLang = pick saveCfg() end
        labeled(tr("proc_lang"))
        pick = choiceButtons("proclang", LANG_OPTIONS, cfg.main.procLang, 80)
        if pick then cfg.main.procLang = pick State.sicLang = pick saveCfg() end
        imgui.Dummy(imgui.ImVec2(0, px(4)))
    end

    -- FACTIUNE
    local facSummary = myFaction.label .. (myFaction.cities and ("  -  " .. tostring(cfg.main.faction)) or "")
    if Gen.section("faction", tr("sec_faction"), facSummary) then
        local secTop = imgui.GetCursorScreenPos().y
        labeled(tr("faction"))
        imgui.PushItemWidth(220)
        if imgui.BeginCombo("##factionId", u8(myFaction.label)) then
            for _, f in ipairs(Factions.list) do
                local r, g, b = hexToRgb(f.hex)
                imgui.PushStyleColor(imgui.Col.Text, V4(math.max(r, 0.35), math.max(g, 0.35), math.max(b, 0.35)))
                if imgui.Selectable(u8(f.label) .. "##fac" .. f.id, f.id == myFaction.id) then
                    App.setFaction(f.id)       -- tema si statia urmeaza factiunea; tema se poate schimba separat mai jos
                end
                imgui.PopStyleColor()
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
        local emblemLeft = imgui.GetItemRectMax().x
        if myFaction.cities then
            labeled(tr("city"))
            local pick = choiceButtons("faction", FACTION_OPTIONS, cfg.main.faction, 44)
            if pick then cfg.main.faction = pick saveCfg() end
        end
        local used, need = imgui.GetCursorScreenPos().y - secTop, px(K.FACTION_BADGE) + 8
        if used < need then imgui.Dummy(imgui.ImVec2(0, need - used)) end
        drawFactionEmblem(myFaction, emblemLeft, secTop, imgui.GetCursorScreenPos().y)
    end

    -- TASTELE MELE
    local nBinds = 0
    for _, a in ipairs(Actions.list) do
        local k = Keys.nameOf(a.id)
        if k and k ~= "None" then nBinds = nBinds + 1 end
    end
    for i = 1, Custom.count() do
        if Custom.get(i).key ~= "None" then nBinds = nBinds + 1 end
    end
    if Gen.section("keys", tr("sec_keys"), tr("binds_active", nBinds)) then
        Gen.keys()
        imgui.Dummy(imgui.ImVec2(0, px(4)))
    end

    -- FERESTRE SI TRIMITERE
    local winSummary = currentTheme.label_ro .. "  -  " .. (tonumber(cfg.main.queueDelay) or 1000) .. " ms  -  "
                       .. (tonumber(cfg.main.pagesize) or 15) .. " " .. tr("lines_short")
    if Gen.section("window", tr("sec_window"), winSummary) then
        local perRow, w = 4, (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x * 3) / 4
        for i, t in ipairs(Themes.list) do
            local active = (currentTheme == t)
            imgui.PushStyleColor(imgui.Col.Button, active and t.hover or t.btn)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, t.hover)
            imgui.PushStyleColor(imgui.Col.Border, active and t.raw or t.border)
            imgui.PushStyleColor(imgui.Col.Text, t.accent)
            if imgui.Button(u8(t.label_ro) .. "##theme" .. t.id, imgui.ImVec2(w, 24)) then
                cfg.main.theme = t.id
                saveCfg()
                applyTheme()
            end
            imgui.PopStyleColor(4)
            if i % perRow ~= 0 and i < #Themes.list then imgui.SameLine() end
        end
        imgui.Spacing()
        labeled(tr("delay"))
        if optInt("delay", buf.delay, 300, 2000, 50, "ms") then
            cfg.main.queueDelay = buf.delay[0]
            saveCfg()
        end
        if imgui.IsItemHovered() then TIP(u8(tr("delay_hint"))) end
        labeled(tr("pagesize"))
        optInt("pagesize", buf.pagesize, K.PAGESIZE_MIN, K.PAGESIZE_MAX, 1, nil)
        imgui.SameLine()
        if imgui.Button(u8(tr("apply")) .. "##pagesize", imgui.ImVec2(70, 22)) then
            cfg.main.pagesize = buf.pagesize[0]
            saveCfg()
            applyPagesize()
        end
        if imgui.IsItemHovered() then TIP(u8(tr("pagesize_hint"))) end
        imgui.Spacing()
        if toggleButton(u8(tr("reset_layout")) .. "##resetlayout", false, imgui.ImVec2(px(180), 24)) then
            App.resetLayout()
        end
        if imgui.IsItemHovered() then TIP(u8(tr("reset_layout_tip"))) end
        imgui.SameLine()
        if toggleButton(u8(tr("wiz_reopen")) .. "##wizopen", false, imgui.ImVec2(px(180), 24)) then
            App.Wizard.start(true)
        end
        if imgui.IsItemHovered() then TIP(u8(tr("wiz_reopen_tip"))) end
        imgui.Dummy(imgui.ImVec2(0, px(4)))
    end

    -- NOTITELE MELE
    if Gen.section("notes", tr("sec_notes"), tr("notes_count", Notes.total(), #Notes.data)) then
        if primaryButton(u8(tr("notes_open")) .. "##opennotes", imgui.ImVec2(px(170), 24)) then State.notes[0] = true end
        imgui.SameLine()
        TC(BLUE, "/notepad")
        imgui.SameLine()
        keyButton("a:note", Keys.nameOf("note"), false, K.KEY_W)
        imgui.SameLine()
        TC(DIM, u8(tr("notes_hint")))
        imgui.Dummy(imgui.ImVec2(0, px(4)))
    end

    -- COMENZI
    local deptCmds = App.PD ~= nil and App.PD.isDept()
    if Gen.section("cmds", tr("sec_cmds") .. "  " .. myFaction.label, tr("cmds_count", deptCmds and 20 or 21)) then
      if deptCmds then
        App.PD.drawGuide(guideLine)
        guideLine("/sih",               tr("g_sih"))
        guideLine("/notepad",           tr("g_notepad"))
        guideLine("/info <id>",         tr("g_info"))
        guideLine("/sicreset",          tr("g_sicreset"))
        imgui.Dummy(imgui.ImVec2(0, px(4)))
      else
        guideLine("/sic",               tr("g_sic"))
        guideLine("/sih",               tr("g_sih"))
        guideLine("/withme <id> <1-6>", tr("g_withme"))
        guideLine("/withme",            tr("g_withme0"))
        guideLine("/sxwas <id>",        tr("g_sxwas"))
        guideLine("/siccand <id>",      tr("g_siccand"))
        guideLine("/salut <id>",        tr("g_salut"))
        guideLine("/pa <id>",           tr("g_pa"))
        guideLine("/need <id>",         tr("g_need"))
        guideLine("/ok <id>",           tr("g_ok"))
        guideLine("/sicraport",         tr("g_sicraport"))
        guideLine("/notepad",           tr("g_notepad"))
        guideLine("/info <id>",         tr("g_info"))
        guideLine("/sicreset",          tr("g_sicreset"))
        guideLine("/sicpay",            tr("g_sicpay"))
        guideLine("/giveme <1-6>",      tr("g_giveme"))
        guideLine("/acc /rl /sl <id>",  tr("g_shorts1"))
        guideLine("/gw /gm /gs /gf /gfl", tr("g_shorts2"))
        guideLine("/sw /sm /ss /sf /sfl", tr("g_shorts3"))
        guideLine("/w1 /m1 /f1 /lsfl1",  tr("g_shorts4"))
        guideLine("/ffvr  /sfvr",       tr("f_fvrOn_tip"))
        imgui.Dummy(imgui.ImVec2(0, px(4)))
      end
    end
end

-- ============================================================
-- /sih - tab Tutorial: comenzile helperului + procedura fiecarei licente (din fisierul de date)
-- ============================================================
local function drawCommandsSection()
    local id, name = Candidate.get()
    TC(TEXT, u8(tr("candidate") .. ":"))
    imgui.SameLine()
    if id then
        TC(GREEN, u8((name ~= "" and name or "?") .. " (" .. id .. ")"))
    else
        TC(DIM, u8(tr("no_candidate")))
    end
    imgui.Spacing()

    -- in ordinea in care se folosesc: sxwas (jucator de pe strada) -> withme -> test
    guideLine("/sxwas <id>",        tr("g_sxwas"))
    guideLine("/withme <id> <1-6>", tr("g_withme"))
    guideLine("/withme",            tr("g_withme0"))
    guideLine("/siccand <id>",      tr("g_siccand"))
    guideLine("/sic",               tr("g_sic"))
    guideLine("/ffvr  /sfvr",       tr("f_fvrOn_tip"))
    imgui.Spacing()

    TC(TEXT, u8(tr("sec_lic") .. ":"))
    imgui.SameLine()
    for i, lic in ipairs(Licenses.list) do
        TC(BLUE, tostring(lic.number))
        imgui.SameLine(0, 3)
        TC(TEXT, lic.label)
        if i < #Licenses.list then imgui.SameLine(0, 12) end
    end
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, DIM)
    imgui.Bullet() TW(u8(tr("g_auto")))
    imgui.Bullet() TW(u8(tr("g_binds")))
    imgui.Bullet() TW(u8(tr("data_hint")))
    imgui.PopStyleColor()
    imgui.Spacing()
end

local function drawTutorialTab()
    if App.PD and App.PD.isDept() then
        if imgui.CollapsingHeader(u8(tr("sec_commands")) .. "##tutcmdpd", imgui.TreeNodeFlags.DefaultOpen) then
            imgui.Spacing()
            App.PD.drawGuide(guideLine)
            imgui.Spacing()
        end
        App.PD.drawTutorial()
        return
    end
    if imgui.CollapsingHeader(u8(tr("sec_commands")) .. "##tutcmd", imgui.TreeNodeFlags.DefaultOpen) then
        imgui.Spacing()
        drawCommandsSection()
    end

    local sections = Data.tutorial and (Data.tutorial[cfg.main.uiLang] or Data.tutorial[K.LANG_RO])
    if not sections or #sections == 0 then
        TC(RED, u8(tr("data_missing", dataError or "tutorial")))
        return
    end

    for i, section in ipairs(sections) do
        local flags = (i == 1) and imgui.TreeNodeFlags.DefaultOpen or 0
        if imgui.CollapsingHeader(u8(section.title) .. "##tut" .. i, flags) then
            imgui.Spacing()
            for _, line in ipairs(section.lines or {}) do
                local step = line:match("^%-%s*(.+)$")
                if step then
                    -- pas de urmat
                    imgui.PushStyleColor(imgui.Col.Text, TEXT)
                    imgui.Bullet() TW(u8(step))
                    imgui.PopStyleColor()
                elseif line:match("^[Pp]r[ei][tc]") then
                    -- linia cu preturi
                    imgui.PushStyleColor(imgui.Col.Text, AMBER)
                    TW(u8(line))
                    imgui.PopStyleColor()
                else
                    -- context (unde se face testul etc.)
                    imgui.PushStyleColor(imgui.Col.Text, BLUE)
                    TW(u8(line))
                    imgui.PopStyleColor()
                end
            end
            imgui.Spacing()
        end
    end
end

-- inchide toate ferestrele helperului (nu si HUD-urile)
function Actions.closeAll()
    Prompt.close()
    State.sih[0], State.sic[0], Report.open[0], State.notes[0] = false, false, false, false
    App.Info.open[0] = false
    if App.PD then App.PD.open[0] = false end
end

-- butonul "inchide tot" din capul ferestrelor: mic, discret, cu tooltip
function Actions.closeAllButton(id)
    imgui.PushStyleColor(imgui.Col.Button, V4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Border, BTN_BORDER)
    imgui.PushStyleColor(imgui.Col.Text, DIM)
    local label = State.icons and (fa.XMARK .. fa.XMARK) or "xx"
    if imgui.Button(label .. "##closeall" .. id, imgui.ImVec2(30, 20)) then Actions.closeAll() end
    imgui.PopStyleColor(3)
    if imgui.IsItemHovered() then TIP(u8(tr("close_all"))) end
end

-- ============================================================
-- /sih - fereastra
-- ============================================================
imgui.OnFrame(function() return State.focused and (State.sih[0] or State.sihFade.alpha > 0) end, function(player)
    player.HideCursor = State.cursorHeldWithWindow   -- tasta "Cursor" tinuta cu o fereastra deschisa: cursorul dispare, camera e a ta
    local alpha = Fade.step(State.sihFade, State.sih[0])
    local res = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), App.cond(), imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(px(680), px(740)), App.cond())

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    local facLabel = (Factions.byId[cfg.main.factionId] or Factions.byId.si).label
    imgui.Begin("SICHelper  v" .. VERSION .. "  -  " .. u8(facLabel) .. "##sih", State.sih, imgui.WindowFlags.NoCollapse)
    State.textInput = imgui.GetIO().WantTextInput

    -- bara de tab-uri, cu hint-ul ESC aliniat la dreapta
    tabButton(tr("tab_general"), 1, 100)
    imgui.SameLine()
    tabButton(tr("tab_features"), 2, 100)
    imgui.SameLine()
    tabButton(tr("tab_binds"), 3, 100)
    imgui.SameLine()
    tabButton(tr("tab_tutorial"), 4, 100)
    local hint = u8(tr("esc_hint"))
    imgui.SameLine(imgui.GetWindowWidth() - imgui.CalcTextSize(hint).x - 12 - 36)
    Actions.closeAllButton("sih")
    imgui.SameLine(imgui.GetWindowWidth() - imgui.CalcTextSize(hint).x - 12)
    TC(DIM, hint)
    imgui.Spacing()

    -- corpul lasa loc jos pentru semnatura
    local footerH = imgui.GetTextLineHeightWithSpacing() * 3 + 10
    imgui.BeginChild("##body", imgui.ImVec2(0, -footerH), false)
    if State.tab == 1 then drawGeneralTab()
    elseif State.tab == 2 then drawFeaturesTab()
    elseif State.tab == 3 then drawBindsTab()
    else drawTutorialTab() end
    imgui.EndChild()

    -- semnatura (watermark), centrata, discreta
    imgui.Separator()
    local w = imgui.GetWindowWidth()
    local line1 = u8(tr("wm_author"))
    imgui.SetCursorPosX((w - imgui.CalcTextSize(line1).x) / 2)
    TC(DIM, line1)
    local line2 = u8(tr("wm_bugs"))
    imgui.SetCursorPosX((w - imgui.CalcTextSize(line2).x) / 2)
    TC(V4(DIM.x, DIM.y, DIM.z, 0.7), line2)
    local line3 = u8(tr("wm_src"))
    imgui.SetCursorPosX((w - imgui.CalcTextSize(line3).x) / 2)
    TC(V4(DIM.x, DIM.y, DIM.z, 0.55), line3)

    imgui.End()
    imgui.PopStyleVar(1)
end)

-- ============================================================
-- FEREASTRA DE NOTITE (/notepad)
-- ============================================================
imgui.OnFrame(function() return State.focused and (State.notes[0] or State.notesFade.alpha > 0) end, function(player)
    player.HideCursor = State.cursorHeldWithWindow   -- tasta "Cursor" tinuta cu o fereastra deschisa
    local alpha = Fade.step(State.notesFade, State.notes[0])
    local res = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), App.cond(), imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(px(620), px(430)), App.cond())
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(px(430), px(240)), imgui.ImVec2(px(1200), px(900)))

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.Begin(u8(tr("notes_title")) .. "##sicnotes", State.notes, imgui.WindowFlags.NoCollapse)
    State.textInput = imgui.GetIO().WantTextInput
    Notes.draw()
    -- click in afara ferestrei: se inchide, iar ce era in editare se salveaza.
    -- se masoara pe dreptunghiul ferestrei: IsWindowHovered da "false" cat timp tii apasat pe un
    -- buton din ea, si fereastra s-ar inchide la orice click dinauntru
    local wp, ws = imgui.GetWindowPos(), imgui.GetWindowSize()
    imgui.End()
    if State.notes[0] and State.notesWasOpen and imgui.IsMouseClicked(0) then
        local m = imgui.GetMousePos()
        if m.x < wp.x or m.y < wp.y or m.x > wp.x + ws.x or m.y > wp.y + ws.y then
            Notes.commit()
            State.notes[0] = false
        end
    end
    State.notesWasOpen = State.notes[0]
    imgui.PopStyleVar(1)
end)

-- ============================================================
-- FEREASTRA /info - buletinul jucatorului
-- ============================================================
imgui.OnFrame(function() return State.focused and (App.Info.open[0] or App.Info.fade.alpha > 0) end, function(player)
    player.HideCursor = State.cursorHeldWithWindow
    local alpha = Fade.step(App.Info.fade, App.Info.open[0])
    local res = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), App.cond(), imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(px(700), px(480)), App.cond())
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(px(560), px(380)), imgui.ImVec2(px(1200), px(900)))

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.Begin(u8(tr("info_window")) .. "##sicinfo", App.Info.open, imgui.WindowFlags.NoCollapse)
    State.textInput = imgui.GetIO().WantTextInput
    App.Info.draw()
    imgui.End()
    imgui.PopStyleVar(1)
end)

-- ============================================================
-- GHIDUL DE PORNIRE (prima instalare)
-- ============================================================
imgui.OnFrame(function() return State.focused and (App.Wizard.open[0] or App.Wizard.fade.alpha > 0) end, function(player)
    player.HideCursor = State.cursorHeldWithWindow
    local alpha = Fade.step(App.Wizard.fade, App.Wizard.open[0])
    local res = imgui.GetIO().DisplaySize
    imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(px(520), px(380)), imgui.Cond.Always)

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.Begin(u8(tr("wiz_title")) .. "##sicwizard", App.Wizard.open,
                bit.bor(imgui.WindowFlags.NoCollapse, imgui.WindowFlags.NoResize))
    State.textInput = imgui.GetIO().WantTextInput
    App.Wizard.draw()
    imgui.End()
    imgui.PopStyleVar(1)
end)

-- ============================================================
-- Fereastra de intrebare (withme / cere ID) - in centrul ecranului
-- ============================================================
imgui.OnFrame(function() return State.focused and (Prompt.open[0] or Prompt.fade.alpha > 0) end, function(player)
    player.HideCursor = State.cursorHeldWithWindow   -- tasta "Cursor" tinuta cu o fereastra deschisa: cursorul dispare, camera e a ta
    -- apare cu fade peste orice alta fereastra (/sih ramane deschis)
    local alpha = Fade.step(Prompt.fade, Prompt.open[0])
    local res = imgui.GetIO().DisplaySize

    -- pozitia si marimea salvate (doar pentru fereastra de withme); altfel centrul ecranului
    local wx, wy = tonumber(cfg.main.wmPosX) or -1, tonumber(cfg.main.wmPosY) or -1
    local pw, ph = tonumber(cfg.main.wmW) or -1, tonumber(cfg.main.wmH) or -1
    local remember = Prompt.needLic
    if Prompt.center then
        if remember and wx >= 0 and wy >= 0 then
            imgui.SetNextWindowPos(imgui.ImVec2(wx, wy), imgui.Cond.Always)
        else
            imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), imgui.Cond.Always, imgui.ImVec2(0.5, 0.5))
        end
        if remember and pw >= 300 and ph >= 100 then
            imgui.SetNextWindowSize(imgui.ImVec2(pw, ph), imgui.Cond.Always)
        else
            imgui.SetNextWindowSize(imgui.ImVec2(px(330), px(Prompt.needLic and 215 or 110)), imgui.Cond.Always)
        end
        imgui.SetNextWindowFocus()
        Prompt.center = false
    end
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(px(300), px(100)), imgui.ImVec2(px(800), px(600)))

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.Begin(u8(Prompt.title) .. "##sicprompt", Prompt.open, imgui.WindowFlags.NoCollapse)
    State.textInput = imgui.GetIO().WantTextInput

    -- retinem unde a pus-o instructorul si cat de mare
    if remember then
        local pos, size = imgui.GetWindowPos(), imgui.GetWindowSize()
        if math.floor(pos.x) ~= wx or math.floor(pos.y) ~= wy
           or math.floor(size.x) ~= pw or math.floor(size.y) ~= ph then
            cfg.main.wmPosX, cfg.main.wmPosY = math.floor(pos.x), math.floor(pos.y)
            cfg.main.wmW, cfg.main.wmH = math.floor(size.x), math.floor(size.y)
            State.sicPosDirty = true   -- acelasi mecanism de salvare rara ca la /sic
        end
    end

    -- randul cu ID: [-] [camp] [+] [cel mai apropiat]   Nume
    TX(u8(tr("prompt_id")))
    imgui.SameLine(40)
    if imgui.Button("-##pidm", imgui.ImVec2(22, 22)) then Prompt.setId(stepConnected(Prompt.currentId(), -1)) end
    imgui.SameLine()
    imgui.PushItemWidth(52)
    if Prompt.focus then
        imgui.SetKeyboardFocusHere(0)
        Prompt.focus = false
    end
    local flags = bit.bor(imgui.InputTextFlags.CharsDecimal,
                          imgui.InputTextFlags.EnterReturnsTrue,
                          imgui.InputTextFlags.AutoSelectAll)
    local enter = imgui.InputText("##pid", Prompt.idBuf, 8, flags)
    imgui.PopItemWidth()
    imgui.SameLine()
    if imgui.Button("+##pidp", imgui.ImVec2(22, 22)) then Prompt.setId(stepConnected(Prompt.currentId(), 1)) end
    imgui.SameLine()
    local nearLabel = State.icons and fa.LOCATION_CROSSHAIRS or "N"
    if imgui.Button(nearLabel .. "##pidn", imgui.ImVec2(26, 22)) then
        local near = nearestPlayer()
        if near then Prompt.setId(near) else err(tr("no_near", K.NEAR_DISTANCE)) end
    end
    if imgui.IsItemHovered() then TIP(u8(tr("nearest"))) end

    local id = Prompt.currentId()
    local name = playerName(id)
    imgui.SameLine()
    if name then TC(GREEN, u8(name)) else TC(DIM, "?") end

    if Prompt.needLic then
        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()

        -- "Licente pentru NUME:"
        TC(TEXT, u8(tr("lic_for")))
        imgui.SameLine()
        TC(name and GREEN or DIM, u8(name or "?") .. ":")

        -- butoanele de licente (3 pe rand, pe toata latimea), selectie multipla, cele alese sunt evidentiate;
        -- randurile care nu mai incap (fereastra micsorata) nu se deseneaza
        local spacing = imgui.GetStyle().ItemSpacing.x
        local licW = (imgui.GetContentRegionAvail().x - spacing * 2) / 3
        local known = Candidate.licensesOf(id)   -- orele din dialogul /requestlicenses, daca e acelasi jucator
        for i, lic in ipairs(Licenses.list) do
            if i % 3 == 1 and imgui.GetContentRegionAvail().y < 24 + 26 + 8 then break end
            local label = (State.icons and (lic.icon .. " ") or "") .. lic.short
            local info = known and known[lic.id]
            if info and info.hours then label = label .. "  " .. info.hours .. "h" end
            -- culoarea textului dupa valabilitate: sub 50 h se poate da renew, peste nu, expirata = rosu
            local color = nil
            if info then
                if info.status:find("expir") then color = RED
                elseif info.hours and info.hours < K.RENEW_MAX_HOURS then color = GREEN
                elseif info.hours then color = AMBER end
            end

            local clicked = toggleButton(label .. "##plic" .. lic.id, Prompt.lics[lic.id] == true, imgui.ImVec2(licW, 24), color, color)

            if clicked then Prompt.toggleLic(lic.id) end
            if imgui.IsItemHovered() and info then
                TIP(u8(lic.label .. ": " .. info.status .. (info.hours and (" - " .. info.hours .. " " .. tr("hours")) or "")
                    .. "\n" .. (info.hours and info.hours < K.RENEW_MAX_HOURS and tr("renew_ok") or tr("renew_no"))))
            end
            if i % 3 ~= 0 and i < #Licenses.list then imgui.SameLine() end
        end

        -- subtotal pentru nivelul jucatorului ales (din scoreboard; /id il confirma la trimitere)
        imgui.Spacing()
        if imgui.GetContentRegionAvail().y < 18 + 26 + 8 then
            -- nu mai e loc: sarim peste subtotal
        elseif next(Prompt.lics) ~= nil then
            local level = playerLevel(id)
            TC(TEXT, u8(tr("subtotal")))
            imgui.SameLine(0, 4)
            if level then
                local total, base = subtotal(Prompt.lics, level)
                TC(DIM, u8("(" .. tr("level") .. " " .. level .. "):"))
                imgui.SameLine(0, 4)
                TC(AMBER, total and moneyWithBonus(total, base) or "-")
            else
                TC(DIM, u8("(" .. tr("level_unknown") .. ")"))
            end
        else
            TC(DIM, u8(tr("lic_needed")))
        end
    end

    -- butoanele Trimite / Anuleaza, lipite de marginea de jos
    local btnW = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
    local bottom = imgui.GetContentRegionAvail().y - 26
    if bottom > 0 then imgui.Dummy(imgui.ImVec2(0, bottom)) else imgui.Spacing() end
    if primaryButton(u8(tr("ok")), imgui.ImVec2(btnW, 26)) or enter then Prompt.submit() end
    imgui.SameLine()
    if imgui.Button(u8(tr("cancel")), imgui.ImVec2(btnW, 26)) then Prompt.close() end

    imgui.End()
    imgui.PopStyleVar(1)
end)

-- ============================================================
-- NOTIFICARI: cartonase in dreapta ecranului, la mijloc
-- intra cu swipe dinspre dreapta, ies cu swipe spre dreapta; se pot inchide (X sau bind)
-- ============================================================
K.NOTIFY_W      = 260         -- latimea minima a cartonasului
K.NOTIFY_W_MAX  = 420         -- latimea maxima: peste ea textul se rupe pe randuri (stil zioAdolf)
K.NOTIFY_BOTTOM_FRAC = 0.74   -- marginea de jos a stivei de notificari (fractiune din inaltimea ecranului): chiar deasupra radarului
K.NOTIFY_LEFT   = 14          -- distanta de la marginea din stanga (px)
K.NOTIFY_SLIDE  = 0.65   -- secunde pentru intrare / iesire (swipe lent)

Notify = {
    items = {},   -- { title, text, kind = "info"|"error", until_, x = deplasare (0 = la loc), closing }
}

function Notify.push(title, text, kind)
    table.insert(Notify.items, {
        title = title, text = text, kind = kind or "info",
        until_ = os.clock() + K.NOTIFY_SECONDS, x = 1.0, closing = false,   -- x: 1 = in afara ecranului
    })
    if #Notify.items > 4 then Notify.items[1].closing = true end
end

function Notify.error(text)
    Notify.push(tr("notify_error_title"), text, "error")
end

-- inchide o notificare (cea mai veche daca nu se da un index)
function Notify.dismiss(index)
    local n = Notify.items[index or 1]
    if n then n.closing = true end
end

-- trece filtrul de nivel din setari? (nivel necunoscut = trece)
local function notifyLevelAllowed(level)
    local mode = cfg.main.notifyLevel or K.NOTIFY_ANY
    if mode == K.NOTIFY_ANY or not level then return true end
    if mode == K.NOTIFY_LOW then return level < 50 end
    return level >= 50
end

function Notify.needlicense(id, name, ageSec, takenBy, level)
    if not feat("notifyOn") then return end
    level = level or playerLevel(id)
    if not notifyLevelAllowed(level) then return end
    local who = (name or "?") .. " (" .. id .. ")"
    local info = tr("notify_text") .. (level and ("  -  " .. tr("notify_level_short") .. " " .. level) or "")
    -- venit cat jocul era in bara: cat de demult
    if ageSec and ageSec >= 15 then info = info .. "  -  " .. tr("notify_ago", math.floor(ageSec / 60), math.floor(ageSec % 60)) end
    if takenBy then info = tr("notify_taken", takenBy) end
    Notify.push(who, info, "info")
    Notify.items[#Notify.items].needId = id   -- ca sa putem actualiza cartonasul daca cererea e preluata
    if takenBy then Notify.items[#Notify.items].until_ = os.clock() + K.NOTIFY_TAKEN_SECONDS end
end

-- expirarile se marcheaza ca "closing"; stergerea propriu-zisa se face dupa animatia de iesire
function Notify.update()
    local now = os.clock()
    for _, n in ipairs(Notify.items) do
        if not n.closing and n.until_ < now then n.closing = true end
    end
end

-- Cartonasele NU sunt ferestre imgui: se deseneaza direct pe ecran (draw list), dintr-un cadru mereu activ,
-- ca sa nu se creeze nicio fereastra si sa nu se schimbe nimic in imgui in momentul in care soseste pachetul.
-- X-ul si click-ul pe cartonas merg cand cursorul e activ (orice fereastra deschisa / tasta Cursor).
local notifyFrame = imgui.OnFrame(function() return State.focused end, function(player)
    player.HideCursor = true
    if #Notify.items == 0 then return end
    local res = imgui.GetIO().DisplaySize
    local dt = imgui.GetIO().DeltaTime
    if dt <= 0 or dt > 0.1 then dt = 0.016 end
    local step = dt / K.NOTIFY_SLIDE
    local interactive = isCursorActive()

    -- animatia: x merge spre 0 la intrare, spre 1 la iesire (usor incetinita la capat)
    for i = #Notify.items, 1, -1 do
        local n = Notify.items[i]
        if n.closing then
            n.x = n.x + step
            if n.x >= 1 then table.remove(Notify.items, i) end
        elseif n.x > 0 then
            n.x = math.max(0, n.x - step)
        end
    end
    if #Notify.items == 0 then return end

    -- pozitia: langa bara de iconite (vezi mai jos), altfel marginea din dreapta, la mijloc

    local PAD, GAP = px(16), px(10)
    local font, fs = imgui.GetFont(), imgui.GetFontSize()
    local dl = imgui.GetBackgroundDrawList()
    local mouse = imgui.GetMousePos()
    local click = interactive and imgui.IsMouseClicked(0)

    -- cartonasul creste cu textul: latimea urmeaza textul pana la NOTIFY_W_MAX, apoi se rupe pe randuri
    local widths, heights, total = {}, {}, 0
    for i, n in ipairs(Notify.items) do
        local body = u8(n.text)
        local tw = font:CalcTextSizeA(fs, math.huge, 0, body).x
        local W = math.max(px(K.NOTIFY_W), math.min(px(K.NOTIFY_W_MAX), tw + PAD * 2 + px(30)))
        local th = font:CalcTextSizeA(fs, math.huge, W - PAD * 2 - px(6), body).y
        widths[i] = W
        heights[i] = PAD + fs + px(6) + th + PAD + px(4)   -- + linia de timp de jos
        total = total + heights[i] + (i > 1 and GAP or 0)
    end

    -- coltul din stanga-jos, deasupra radarului (ca la Jade): cartonasele se stivuiesc in sus, cel mai nou jos;
    -- intra si ies prin stanga
    local y = res.y * K.NOTIFY_BOTTOM_FRAC - total
    local anchorRight, dir, x0 = false, -1, px(K.NOTIFY_LEFT)

    for i, n in ipairs(Notify.items) do
        local h, W = heights[i], widths[i]
        local ease = n.x * n.x
        local xOff = ease * (W + 24) * dir
        local left = (anchorRight and (x0 - W) or x0) + xOff
        local pMin, pMax = imgui.ImVec2(left, y), imgui.ImVec2(left + W, y + h)
        local isError = (n.kind == "error")
        local accent = isError and RED or GREEN
        local alpha = 1 - ease * 0.6
        local col = function(c, a) return imgui.GetColorU32Vec4(V4(c.x, c.y, c.z, a * alpha)) end

        -- cardul (stil zioAdolf): surface #0E1418 85%, colturi 6 px, bara de accent 3 px in stanga,
        -- titlu uppercase in accent, iconita de stare in dreapta, textul dedesubt, jos linia de timp
        dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(V4(0.055, 0.078, 0.094, 0.85 * alpha)), px(6))
        dl:AddRectFilled(pMin, imgui.ImVec2(left + px(3), y + h), col(accent, 1), px(3), bit.bor(imgui.DrawCornerFlags.TopLeft, imgui.DrawCornerFlags.BotLeft))
        local tx = left + PAD
        dl:AddText(imgui.ImVec2(tx, y + PAD), col(accent, 1), u8(string.upper(n.title)))
        if State.icons then
            local icon = isError and fa.TRIANGLE_EXCLAMATION or fa.CIRCLE_CHECK
            local iw = font:CalcTextSizeA(fs, math.huge, 0, icon).x
            dl:AddText(imgui.ImVec2(left + W - PAD - iw, y + PAD), col(accent, 1), icon)
        end
        dl:AddTextFontPtr(font, fs, imgui.ImVec2(left + PAD, y + PAD + fs + px(6)), col(TEXT, 0.95), u8(n.text), nil, W - PAD * 2 - px(6))
        -- linia de timp (cat mai ramane pe ecran), in stanga jos
        local remain = math.max(0, math.min(1, (n.until_ - os.clock()) / K.NOTIFY_SECONDS))
        local barW = px(90)
        dl:AddRectFilled(imgui.ImVec2(left + PAD, y + h - px(4)), imgui.ImVec2(left + PAD + barW * remain, y + h - px(2)), col(accent, 0.9), 1)

        -- click pe cartonas (oriunde) il inchide, cand cursorul e activ
        if click and not n.closing and mouse.x >= left and mouse.x <= left + W and mouse.y >= y and mouse.y <= y + h then
            n.closing = true
        end
        y = y + h + GAP
    end
end)

-- ============================================================
-- HUD-uri mutabile: pozitia se salveaza in ini (cfg.main.<key>X / <key>Y); se pot trage cand cursorul e activ
-- ============================================================
-- aseaza fereastra HUD: pozitia salvata, sau cea implicita (dreapta, la fractiunea data din inaltime)
local function hudPlace(key, defaultYFrac, width)
    local res = imgui.GetIO().DisplaySize
    local x, y = tonumber(cfg.main[key .. "X"]) or -1, tonumber(cfg.main[key .. "Y"]) or -1
    if x >= 0 and y >= 0 and x < res.x and y < res.y then
        imgui.SetNextWindowPos(imgui.ImVec2(x, y), App.cond())
    else
        imgui.SetNextWindowPos(imgui.ImVec2(res.x - 12, res.y * defaultYFrac), App.cond(), imgui.ImVec2(1, 0))
    end
    imgui.SetNextWindowSize(imgui.ImVec2(width, 0), imgui.Cond.Always)
end

-- flag-urile unui HUD: fara input cat timp cursorul nu e activ; cu cursor activ se poate trage
local function hudFlags()
    local flags = bit.bor(imgui.WindowFlags.NoDecoration, imgui.WindowFlags.NoSavedSettings,
                          imgui.WindowFlags.NoFocusOnAppearing, imgui.WindowFlags.NoBringToFrontOnFocus,
                          imgui.WindowFlags.NoNav, imgui.WindowFlags.AlwaysAutoResize)
    if not isCursorActive() then flags = bit.bor(flags, imgui.WindowFlags.NoInputs) end
    return flags
end

-- dupa Begin: retine pozitia daca a fost mutat
local function hudRemember(key)
    local pos = imgui.GetWindowPos()
    local x, y = math.floor(pos.x), math.floor(pos.y)
    if x ~= tonumber(cfg.main[key .. "X"]) or y ~= tonumber(cfg.main[key .. "Y"]) then
        cfg.main[key .. "X"], cfg.main[key .. "Y"] = x, y
        State.sicPosDirty = true
    end
end

-- ============================================================
-- Fereastra RAPORT SAPTAMANAL (in locul dialogului de la /raport)
-- ============================================================
local function progressRow(label, done, total, color)
    TC(TEXT, u8(label))
    local value = (done and total) and (done .. " / " .. total) or "-"
    -- latimea se masoara cu fontul mono (cel cu care se si deseneaza), aliniat la marginea din dreapta
    mono(function()
        local w = imgui.CalcTextSize(value).x
        imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - w)
        TC(GREEN, value)
    end)
    local frac = (done and total and total > 0) and math.min(1, done / total) or 0
    imgui.PushStyleColor(imgui.Col.PlotHistogram, color or GREEN)
    imgui.ProgressBar(frac, imgui.ImVec2(-1, 10), "")
    imgui.PopStyleColor()
end

imgui.OnFrame(function() return State.focused and (Report.open[0] or Report.fade.alpha > 0) end, function(player)
    player.HideCursor = State.cursorHeldWithWindow   -- tasta "Cursor" tinuta cu o fereastra deschisa: cursorul dispare, camera e a ta
    local alpha = Fade.step(Report.fade, Report.open[0])
    local res = imgui.GetIO().DisplaySize
    -- pozitia salvata (unde a pus-o jucatorul); prima data, centrul ecranului
    local rx, ry = tonumber(cfg.main.reportX) or -1, tonumber(cfg.main.reportY) or -1
    if rx >= 0 and ry >= 0 and rx < res.x and ry < res.y then
        imgui.SetNextWindowPos(imgui.ImVec2(rx, ry), App.cond())
    else
        imgui.SetNextWindowPos(imgui.ImVec2(res.x / 2, res.y / 2), App.cond(), imgui.ImVec2(0.5, 0.5))
    end
    imgui.SetNextWindowSize(imgui.ImVec2(px(360), 0), imgui.Cond.Always)

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.Begin(u8(tr("report_title")) .. "##sicreport", Report.open, bit.bor(imgui.WindowFlags.NoCollapse, imgui.WindowFlags.NoResize))
    hudRemember("report")   -- retine pozitia daca a fost mutata (se salveaza in ini)
    imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - 30)
    Actions.closeAllButton("report")

    local d = Report.data
    if not d then
        TC(DIM, u8(tr("report_none")))
    else
        -- timp ramas / rank up, in mono
        mono(function()
            TC(DIM, u8(tr("report_days_left")) .. ": ")
            imgui.SameLine(0, 0)
            TC(TEXT, tostring(d.daysLeft or "?"))
            if d.rankupDays then
                imgui.SameLine(0, 18)
                TC(DIM, u8(tr("report_rankup")) .. ": ")
                imgui.SameLine(0, 0)
                TC(TEXT, tostring(d.rankupDays))
            end
        end)
        imgui.Spacing()

        if d.progress then
            progressRow(tr("report_progress") .. (d.progress.status and ("  (" .. d.progress.status .. ")") or ""),
                d.progress.done, d.progress.total, GREEN)
        end
        imgui.Spacing()
        if d.bonus then
            progressRow(tr("report_bonus") .. (d.bonus.status and ("  (" .. d.bonus.status .. ")") or ""),
                d.bonus.done, d.bonus.total, AMBER)
        end
        imgui.Spacing()

        -- contoarele sesiunii: licente acceptate sub 50 / 50+
        local half = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
        imgui.BeginChild("##rep_low", imgui.ImVec2(half, 54), true)
        TC(DIM, "LEVEL 1-49")
        mono(function() TC(TEXT, tostring(Report.session.low)) end)
        imgui.EndChild()
        imgui.SameLine()
        imgui.BeginChild("##rep_high", imgui.ImVec2(0, 54), true)
        TC(DIM, "LEVEL 50+")
        mono(function() TC(TEXT, tostring(Report.session.high)) end)
        imgui.EndChild()
        TC(DIM, u8(tr("report_session_hint")))
    end

    imgui.Spacing()
    local w = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x) / 2
    if primaryButton(u8(tr("report_refresh")), imgui.ImVec2(w, 26)) then Queue.push("/raport") end
    imgui.SameLine()
    if imgui.Button(u8(tr("close")) .. "##rep", imgui.ImVec2(w, 26)) then Report.open[0] = false end

    imgui.End()
    imgui.PopStyleVar(1)
end)


-- ============================================================
-- HUD RAPORT cat esti on duty: "RAPORT 8/8  BONUS 85/30", se actualizeaza singur la fiecare licenta
-- ============================================================
local dutyHudFrame = imgui.OnFrame(function()
    return State.focused and feat("dutyHud") and Duty.state == true and Report.data ~= nil
end, function(player)
    player.HideCursor = true
    local d = Report.data
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local interactive = isCursorActive()
    local W, rowH = px(150), px(34)

    hudPlace("hudReport", 0.135, W)
    -- fara panou: valoarea mare in accent, eticheta cu majuscule mici dedesubt, iconita intr-un patratel la dreapta
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0, 0, 0, 0))      -- fara panou, niciodata
    imgui.PushStyleColor(imgui.Col.Border, V4(0, 0, 0, 0))        -- fara chenar; se poate trage / redimensiona oricum cand cursorul e activ
    imgui.Begin("##sicdutyhud", nil, hudFlags())
    hudRemember("hudReport")
    local dl, wp = imgui.GetWindowDrawList(), imgui.GetWindowPos()
    local font, fs = imgui.GetFont(), imgui.GetFontSize()
    local big, small, badge = fs * 1.25, fs * 0.78, px(22)
    local right = wp.x + W - px(8)
    local y = wp.y + px(4)
    local function stat(label, part, color, icon)
        local txt = part and ((part.done or 0) .. "/" .. (part.total or "?")) or "-"
        local full = part and part.total and (part.done or 0) >= part.total
        local c = full and OK_GREEN or color
        -- patratelul cu iconita
        local bx0, by0 = right - badge, y + (rowH - badge) / 2
        dl:AddRectFilled(imgui.ImVec2(bx0, by0), imgui.ImVec2(bx0 + badge, by0 + badge), imgui.GetColorU32Vec4(V4(0.05, 0.07, 0.08, 0.85)), px(5))
        dl:AddRect(imgui.ImVec2(bx0, by0), imgui.ImVec2(bx0 + badge, by0 + badge), imgui.GetColorU32Vec4(V4(c.x, c.y, c.z, 0.9)), px(5), 15, 1.2)
        if State.icons and icon then
            local is = font:CalcTextSizeA(small, math.huge, 0, icon)
            dl:AddTextFontPtr(font, small, imgui.ImVec2(bx0 + (badge - is.x) / 2, by0 + (badge - is.y) / 2), imgui.GetColorU32Vec4(c), icon)
        end
        -- valoarea (mare) si eticheta (mica), aliniate la dreapta langa patratel
        local vs = font:CalcTextSizeA(big, math.huge, 0, txt)
        local vx = bx0 - px(8) - vs.x
        dl:AddTextFontPtr(font, big, imgui.ImVec2(vx + 1, y + 1), imgui.GetColorU32Vec4(V4(0, 0, 0, 0.7)), txt)
        dl:AddTextFontPtr(font, big, imgui.ImVec2(vx, y), imgui.GetColorU32Vec4(c), txt)
        local ls = font:CalcTextSizeA(small, math.huge, 0, label)
        local lx = bx0 - px(8) - ls.x
        dl:AddTextFontPtr(font, small, imgui.ImVec2(lx + 1, y + vs.y + 1), imgui.GetColorU32Vec4(V4(0, 0, 0, 0.7)), label)
        dl:AddTextFontPtr(font, small, imgui.ImVec2(lx, y + vs.y), imgui.GetColorU32Vec4(V4(0.80, 0.84, 0.87, 0.95)), label)
        y = y + rowH + px(4)
    end
    stat(u8(string.upper(tr("report_progress"))) .. (d.fromIni and " *" or ""), d.progress, GREEN, fa.CLIPBOARD_CHECK)
    stat(u8(string.upper(tr("report_bonus"))), d.bonus, AMBER, fa.STAR)
    imgui.Dummy(imgui.ImVec2(W - px(16), (rowH + px(4)) * 2))
    imgui.End()
    imgui.PopStyleColor(2)
end)

-- ============================================================
-- Panoul CHECKLIST DOVEZI (HUD, dreapta sus, fara input)
-- ============================================================
local checklistFrame = imgui.OnFrame(function()
    return State.focused and feat("checklist") and Candidate.get() ~= nil and Check.forId == Candidate.get()
           and Check.hiddenFor ~= Candidate.get()   -- inchis cu X: ramane ascuns pentru acest candidat
end, function(player)
    player.HideCursor = true
    local res = imgui.GetIO().DisplaySize
    local id, name = Candidate.get()
    local done, total = Check.count()

    hudPlace("hudCheck", 0.20, px(250))
    imgui.Begin("##sicchecklist", nil, hudFlags())
    hudRemember("hudCheck")

    -- capul panoului: DOVEZI Â· Nume  ....  3/5
    local lic = ""
    if State.sicTab ~= K.TAB_LEVEL50 and Tests[State.sicTab] then lic = Licenses.byId[Tests[State.sicTab].licId].label end
    TC(DIM, u8(tr("check_title")) .. (lic ~= "" and (" - " .. string.upper(lic)) or ""))
    local counter = done .. "/" .. total
    mono(function()
        imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - imgui.CalcTextSize(counter).x)
        TC(done == total and OK_GREEN or GREEN, counter)
    end)
    TC(TEXT, u8((name ~= "" and name or "?") .. " (" .. id .. ")"))
    -- X de inchidere (apasabil cand cursorul e activ): ascunde panoul pana la urmatorul candidat
    imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - 16)
    imgui.PushStyleColor(imgui.Col.Button, V4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Border, V4(0, 0, 0, 0))
    imgui.PushStyleColor(imgui.Col.Text, DIM)
    if imgui.Button((State.icons and fa.XMARK or "x") .. "##chkclose", imgui.ImVec2(16, 16)) then Check.hiddenFor = id end
    imgui.PopStyleColor(3)
    imgui.Separator()

    for _, step in ipairs(CHECK_STEPS) do
        local isDone = Check.done[step]
        local mark = State.icons and (isDone and fa.CHECK or fa.CIRCLE) or (isDone and "x" or "o")
        TC(isDone and OK_GREEN or DIM, mark)
        imgui.SameLine(0, 8)
        TC(isDone and TEXT or DIM, u8(tr("check_" .. step)))
        if Check.shot[step] then
            imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - 16)
            TC(OK_GREEN, State.icons and fa.CAMERA or "SS")
        end
    end

    imgui.End()
end)

-- ============================================================
-- BARA DE ICONITE (dock) - mereu pe ecran, in stil "action bar" de RPG: sloturi patrate cu chenar in
-- culoarea temei, iconita in centru, tasta bind-ului in colt; slotul ferestrei deschise e aprins.
-- Click cand cursorul e activ (orice fereastra deschisa) sau cat tii apasata tasta "Cursor" din Bind-uri.
-- ============================================================
K.DOCK_ITEMS = {
    -- statia factiunii: /sic (instructori) sau /pdc (departamente, cu scutul)
    { id = "sic",    icon = "CLIPBOARD_LIST", iconDept = "SHIELD_HALVED",
      isOpen = function() return State.sic[0] or (App.PD ~= nil and App.PD.open[0]) end },
    { id = "wm",     icon = "USER_PLUS",      isOpen = function() return Prompt.open[0] end },
    { id = "raport", icon = "CHART_SIMPLE",   isOpen = function() return Report.open[0] end },
    { id = "sih",    icon = "GEAR",           isOpen = function() return State.sih[0] end },
    { id = "note",   icon = "NOTE_STICKY",    isOpen = function() return State.notes[0] end },
    -- duty: verde cand esti la datorie, rosu cand nu; click = /duty
    { id = "duty",   text = "DUTY",           isOpen = function() return Duty.state == true end,
      color = function() if Duty.state == true then return OK_GREEN elseif Duty.state == false then return RED end return nil end },
}

State.dockFrame = imgui.OnFrame(function() return State.focused and feat("dock") end, function(player)
    -- cursorul apare doar cat se tine tasta "Cursor" (fara ferestre deschise); altfel bara nu deranjeaza jocul
    player.HideCursor = not State.cursorHeldNoWindow
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local S, GAP, PAD = px(K.DOCK_SLOT), px(6), px(6)
    local interactive = isCursorActive()

    -- orientarea: "auto" = verticala, dar devine orizontala trasa langa marginea de sus / jos (cu histerezis);
    -- "vert" / "horiz" = fixa (Features -> Bara de iconite). Se retine in ini (dockHoriz / dockOrient).
    local res = imgui.GetIO().DisplaySize
    local orient = cfg.main.dockOrient or "auto"
    local horiz = (tonumber(cfg.main.dockHoriz) or 0) == 1
    local r = State.dockRect
    if orient == "vert" then horiz = false
    elseif orient == "horiz" then horiz = true
    elseif r then
        local nearEdge = r.y < K.DOCK_EDGE or (r.y + r.h) > res.y - K.DOCK_EDGE
        local farEdge  = r.y > K.DOCK_EDGE * 2 and (r.y + r.h) < res.y - K.DOCK_EDGE * 2
        if nearEdge and not horiz then horiz = true  cfg.main.dockHoriz = 1 State.sicPosDirty = true end
        if farEdge and horiz      then horiz = false cfg.main.dockHoriz = 0 State.sicPosDirty = true end
    end
    local n = #K.DOCK_ITEMS
    local winW = horiz and (n * S + (n - 1) * GAP + 10 + PAD * 2) or (S + PAD * 2)

    hudPlace("hudDock", 0.58, winW)   -- implicit: dreapta, in jumatatea de jos
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(PAD, PAD))
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowRounding, 8)
    imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 1)
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0.04, 0.05, 0.06, 0.78))
    imgui.PushStyleColor(imgui.Col.Border, V4(t.border.x, t.border.y, t.border.z, 0.9))
    imgui.Begin("##sicdock", nil, hudFlags())
    hudRemember("hudDock")
    do local wp, ws = imgui.GetWindowPos(), imgui.GetWindowSize()
       -- cand isi schimba forma (verticala <-> orizontala) nu are voie sa iasa din ecran
       local nx = math.max(0, math.min(wp.x, res.x - ws.x))
       local ny = math.max(0, math.min(wp.y, res.y - ws.y))
       if nx ~= wp.x or ny ~= wp.y then imgui.SetWindowPosVec2(imgui.ImVec2(nx, ny), imgui.Cond.Always) wp = imgui.ImVec2(nx, ny) end
       State.dockRect = { x = wp.x, y = wp.y, w = ws.x, h = ws.y, horiz = horiz } end   -- notificarile se aseaza langa bara

    local dl = imgui.GetWindowDrawList()
    -- "maner" de tras: doua liniute (sus la bara verticala, in stanga la cea orizontala)
    local gp = imgui.GetCursorScreenPos()
    local gripCol = imgui.GetColorU32Vec4(V4(t.border.x, t.border.y, t.border.z, 0.9))
    if horiz then
        dl:AddLine(imgui.ImVec2(gp.x + 2, gp.y + S / 2 - 8), imgui.ImVec2(gp.x + 2, gp.y + S / 2 + 8), gripCol, 1)
        dl:AddLine(imgui.ImVec2(gp.x + 5, gp.y + S / 2 - 8), imgui.ImVec2(gp.x + 5, gp.y + S / 2 + 8), gripCol, 1)
        imgui.Dummy(imgui.ImVec2(8, S))
        imgui.SameLine(0, 2)
    else
        dl:AddLine(imgui.ImVec2(gp.x + S / 2 - 8, gp.y + 2), imgui.ImVec2(gp.x + S / 2 + 8, gp.y + 2), gripCol, 1)
        dl:AddLine(imgui.ImVec2(gp.x + S / 2 - 8, gp.y + 5), imgui.ImVec2(gp.x + S / 2 + 8, gp.y + 5), gripCol, 1)
        imgui.Dummy(imgui.ImVec2(S, 8))
    end

    for i, item in ipairs(K.DOCK_ITEMS) do
        local a = Actions.byId[item.id]
        local open = item.isOpen()
        local stateCol = item.color and item.color() or nil   -- culoare de stare (duty): inlocuieste accentul temei
        local p = imgui.GetCursorScreenPos()
        local clicked = imgui.InvisibleButton("##dock" .. item.id, imgui.ImVec2(S, S))
        local hovered = interactive and imgui.IsItemHovered()
        local pMin, pMax = imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x + S, p.y + S)

        -- slotul: umplutura inchisa (mai deschisa la hover), o "lumina" in spate cand fereastra e deschisa
        if open or stateCol then
            dl:AddRectFilled(imgui.ImVec2(p.x - 3, p.y - 3), imgui.ImVec2(p.x + S + 3, p.y + S + 3),
                             imgui.GetColorU32Vec4(V4((stateCol or t.raw).x, (stateCol or t.raw).y, (stateCol or t.raw).z, 0.18)), 9)
        end
        local fill = open and t.hover or (hovered and V4(t.btn.x + 0.06, t.btn.y + 0.06, t.btn.z + 0.06, 1) or t.btn)
        dl:AddRectFilled(pMin, pMax, imgui.GetColorU32Vec4(fill), 6)
        -- bizou interior discret (linia de sus mai deschisa, ca o fateta)
        dl:AddLine(imgui.ImVec2(p.x + 4, p.y + 1.5), imgui.ImVec2(p.x + S - 4, p.y + 1.5),
                   imgui.GetColorU32Vec4(V4(1, 1, 1, 0.07)), 1)
        -- chenar: culoarea temei cand e deschis / hover, altfel chenarul neutru al temei
        local borderCol = stateCol or ((open or hovered) and t.raw or t.border)
        dl:AddRect(pMin, pMax, imgui.GetColorU32Vec4(borderCol), 6, 15, (open or stateCol) and 2 or 1.2)

        -- iconita in centru
        local iconName = (item.iconDept and App.PD and App.PD.isDept()) and item.iconDept or item.icon
        local glyph = (iconName and State.iconBig) and fa[iconName] or nil
        if glyph then
            local sz = px(K.DOCK_ICON)
            local ts = State.iconBig:CalcTextSizeA(sz, math.huge, 0, glyph)
            local iconCol = stateCol or (open and t.accent or (hovered and TEXT or IDLE_TEXT))
            dl:AddTextFontPtr(State.iconBig, sz, imgui.ImVec2(p.x + (S - ts.x) / 2, p.y + (S - ts.y) / 2 - 1),
                              imgui.GetColorU32Vec4(iconCol), glyph)
        else
            -- slot cu text in loc de iconita (ex. DUTY)
            local short = item.text or item.id:sub(1, 3):upper()
            local ts = imgui.CalcTextSize(short)
            local txtCol = stateCol or (open and t.accent or (hovered and TEXT or IDLE_TEXT))
            dl:AddText(imgui.ImVec2(p.x + (S - ts.x) / 2, p.y + (S - ts.y) / 2), imgui.GetColorU32Vec4(txtCol), short)
        end

        -- tasta bind-ului, mic, in coltul din dreapta jos
        local keyName = Keys.nameOf(item.id)
        if keyName and keyName ~= "None" and (tonumber(cfg.binds[item.id .. "_on"]) or 0) == 1 then
            local label = keyName:sub(1, 4)
            local ks = imgui.GetFont():CalcTextSizeA(10, math.huge, 0, label)
            dl:AddTextFontPtr(imgui.GetFont(), 10, imgui.ImVec2(p.x + S - ks.x - 4, p.y + S - ks.y - 2),
                              imgui.GetColorU32Vec4(V4(t.accent.x, t.accent.y, t.accent.z, 0.85)), label)
        end

        if hovered and a then TIP(u8(actionLabel(a))) end
        if clicked and interactive and a then a.run(a) end
        if i < #K.DOCK_ITEMS then
            if horiz then imgui.SameLine(0, GAP) else imgui.Dummy(imgui.ImVec2(S, GAP - imgui.GetStyle().ItemSpacing.y)) end
        end
    end

    imgui.End()
    imgui.PopStyleColor(2)
    imgui.PopStyleVar(3)
end)

-- HUD-urile nu au nevoie de cursor: se marcheaza la creare, nu la desenare, ca mimgui sa nu
-- porneasca cursorul cand una dintre ele se activeaza in timp ce jocul e minimizat (alt-tab)
notifyFrame.HideCursor    = true
dutyHudFrame.HideCursor   = true
checklistFrame.HideCursor = true
State.dockFrame.HideCursor = true

-- ============================================================
-- LEGENDA BIND-URILOR (stil "key hints": eticheta cu majuscule mici, tasta intr-un patratel cu chenar
-- in culoarea temei, aliniate la dreapta, fara panou). Mutabila cand cursorul e activ.
-- ============================================================
State.legendFrame = imgui.OnFrame(function()
    if not (State.focused and feat("bindLegend")) then return false end
    if State.checkpoint then return true end   -- randul cu checkpoint-ul
    local cid = Candidate.get()
    if cid then local okc, pedc = sampGetCharHandleBySampPlayerId(cid) if okc then return true end end   -- candidat langa noi
    for _, a in ipairs(Actions.list) do
        local key = Keys.nameOf(a.id)
        if key and key ~= "None" and (tonumber(cfg.binds[a.id .. "_on"]) or 0) == 1
           and (tonumber(cfg.binds[a.id .. "_hide"]) or 0) == 0 then return true end
    end
    for i = 1, Custom.count() do
        local b = Custom.get(i)
        if tostring(b.key) ~= "None" and b.on == 1 and (tonumber(cfg.custom["c" .. i .. "_hide"]) or 0) == 0 then return true end
    end
    return false
end, function(player)
    player.HideCursor = true
    local t = Themes.byId[cfg.main.theme] or Themes.byId.si
    local interactive = isCursorActive()
    -- latimea e a jucatorului (trage de coltul din dreapta-jos cand cursorul e activ); totul se scaleaza dupa ea
    local W = tonumber(cfg.main.hudLegendW) or px(K.LEGEND_BASE_W)
    local zoom = W / px(K.LEGEND_BASE_W)
    local rowH, badge = px(36) * zoom, px(27) * zoom

    -- randurile
    local rows = {}
    for _, a in ipairs(Actions.list) do
        local key = Keys.nameOf(a.id)
        if key and key ~= "None" and (tonumber(cfg.binds[a.id .. "_on"]) or 0) == 1
           and (tonumber(cfg.binds[a.id .. "_hide"]) or 0) == 0 then
            local short = (cfg.main.uiLang == K.LANG_EN) and a.short_en or a.short_ro
            table.insert(rows, { key = key, label = short or actionLabel(a) })
        end
    end
    for i = 1, Custom.count() do
        local b = Custom.get(i)
        if tostring(b.key) ~= "None" and b.on == 1 and (tonumber(cfg.custom["c" .. i .. "_hide"]) or 0) == 0 then
            table.insert(rows, { key = tostring(b.key), label = tostring(b.cmd) })
        end
    end

    hudPlace("hudLegend", 0.36, W)
    local extra = (State.checkpoint and 1 or 0)
    do local cid = Candidate.get() if cid then local okc = sampGetCharHandleBySampPlayerId(cid) if okc then extra = extra + 1 end end end
    local H = (#rows + extra) * rowH + px(12)   -- + randurile cu distante
    imgui.SetNextWindowSize(imgui.ImVec2(W, H), App.cond())
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(px(160), H), imgui.ImVec2(px(700), H))   -- inaltimea urmeaza randurile, latimea e libera
    -- fereastra e doar "rama" invizibila (ca sa poata fi trasa); continutul e desenat direct
    imgui.PushStyleColor(imgui.Col.WindowBg, V4(0, 0, 0, 0))      -- fara panou, niciodata
    imgui.PushStyleColor(imgui.Col.Border, V4(0, 0, 0, 0))        -- fara chenar; se poate trage / redimensiona oricum cand cursorul e activ
    local flags = bit.bor(imgui.WindowFlags.NoDecoration, imgui.WindowFlags.NoSavedSettings, imgui.WindowFlags.NoFocusOnAppearing,
                          imgui.WindowFlags.NoBringToFrontOnFocus, imgui.WindowFlags.NoNav, imgui.WindowFlags.NoScrollbar)
    if not interactive then flags = bit.bor(flags, imgui.WindowFlags.NoInputs) end
    imgui.Begin("##siclegend", nil, flags)
    do  -- latimea aleasa de jucator se retine (ca pozitia)
        local w = math.floor(imgui.GetWindowSize().x)
        if w ~= math.floor(W) then cfg.main.hudLegendW = w State.sicPosDirty = true end
    end
    hudRemember("hudLegend")
    do  -- daca a crescut latimea, fereastra ramane in ecran (altfel tastele ies in dreapta)
        local res, wp0, ws0 = imgui.GetIO().DisplaySize, imgui.GetWindowPos(), imgui.GetWindowSize()
        local nx = math.max(0, math.min(wp0.x, res.x - ws0.x))
        local ny = math.max(0, math.min(wp0.y, res.y - ws0.y))
        if nx ~= wp0.x or ny ~= wp0.y then imgui.SetWindowPosVec2(imgui.ImVec2(nx, ny), imgui.Cond.Always) end
    end
    local dl = imgui.GetWindowDrawList()
    local wp = imgui.GetWindowPos()
    local font, fs = imgui.GetFont(), imgui.GetFontSize()
    local small = fs * 0.98 * zoom
    local right = wp.x + W - px(8)
    local y = wp.y + px(6)
    for _, r in ipairs(rows) do
        -- patratelul cu tasta, la dreapta
        local keyTxt = tostring(r.key):sub(1, 6)
        local kw = math.max(badge, font:CalcTextSizeA(small, math.huge, 0, keyTxt).x + px(10))
        local bx0, by0 = right - kw, y + (rowH - badge) / 2
        dl:AddRectFilled(imgui.ImVec2(bx0, by0), imgui.ImVec2(bx0 + kw, by0 + badge), imgui.GetColorU32Vec4(V4(0.05, 0.07, 0.08, 0.85)), px(5))
        dl:AddRect(imgui.ImVec2(bx0, by0), imgui.ImVec2(bx0 + kw, by0 + badge), imgui.GetColorU32Vec4(V4(t.raw.x, t.raw.y, t.raw.z, 0.9)), px(5), 15, 1.2)
        local ks = font:CalcTextSizeA(small, math.huge, 0, keyTxt)
        dl:AddTextFontPtr(font, small, imgui.ImVec2(bx0 + (kw - ks.x) / 2, by0 + (badge - ks.y) / 2), imgui.GetColorU32Vec4(t.accent), keyTxt)
        -- eticheta, majuscule mici, aliniata la dreapta langa patratel, cu umbra fina pentru lizibilitate
        local label = r.label
        if #label > 26 then label = label:sub(1, 25) .. "..." end   -- etichetele lungi se scurteaza
        label = u8(string.upper(label))
        local ls = font:CalcTextSizeA(small, math.huge, 0, label)
        local lx, ly = bx0 - px(10) - ls.x, y + (rowH - ls.y) / 2
        dl:AddTextFontPtr(font, small, imgui.ImVec2(lx + 1, ly + 1), imgui.GetColorU32Vec4(V4(0, 0, 0, 0.7)), label)
        dl:AddTextFontPtr(font, small, imgui.ImVec2(lx, ly), imgui.GetColorU32Vec4(V4(0.88, 0.91, 0.93, 0.95)), label)
        y = y + rowH
    end

    -- randuri cu distante: (1) candidatul, daca e langa noi (streamat); (2) checkpoint-ul activ, orice ar fi
    -- (accept, misiune, /find...), cu numele zonei in care e
    -- un rand de distanta; click pe el (cu cursorul activ) il scoate de pe ecran
    local function distRow(labelText, distM, onClick)
        local valTxt = (distM >= 1000) and string.format("%.1f km", distM / 1000) or string.format("%d m", math.floor(distM + 0.5))
        local kw = font:CalcTextSizeA(small, math.huge, 0, valTxt).x + px(12)
        local bx0, by0 = right - kw, y + (rowH - badge) / 2
        local label = u8(string.upper(labelText))
        if #label > 30 then label = label:sub(1, 29) .. "..." end
        local ls = font:CalcTextSizeA(small, math.huge, 0, label)
        local lx, ly = bx0 - px(10) - ls.x, y + (rowH - ls.y) / 2
        -- click pe rand = il inchide (ca la notificari)
        local hot = interactive and imgui.IsMouseClicked(0)
        if hot then
            local m = imgui.GetMousePos()
            if m.x >= lx - px(6) and m.x <= bx0 + kw and m.y >= y and m.y <= y + rowH then
                if onClick then onClick() end
            end
        end
        local hovered = false
        if interactive then
            local m = imgui.GetMousePos()
            hovered = m.x >= lx - px(6) and m.x <= bx0 + kw and m.y >= y and m.y <= y + rowH
        end
        dl:AddRectFilled(imgui.ImVec2(bx0, by0), imgui.ImVec2(bx0 + kw, by0 + badge), imgui.GetColorU32Vec4(V4(0.05, 0.07, 0.08, 0.85)), px(5))
        dl:AddRect(imgui.ImVec2(bx0, by0), imgui.ImVec2(bx0 + kw, by0 + badge), imgui.GetColorU32Vec4(V4(t.raw.x, t.raw.y, t.raw.z, hovered and 1 or 0.9)), px(5), 15, hovered and 2 or 1.2)
        local vs = font:CalcTextSizeA(small, math.huge, 0, valTxt)
        dl:AddTextFontPtr(font, small, imgui.ImVec2(bx0 + (kw - vs.x) / 2, by0 + (badge - vs.y) / 2), imgui.GetColorU32Vec4(t.accent), valTxt)
        dl:AddTextFontPtr(font, small, imgui.ImVec2(lx + 1, ly + 1), imgui.GetColorU32Vec4(V4(0, 0, 0, 0.7)), label)
        dl:AddTextFontPtr(font, small, imgui.ImVec2(lx, ly), imgui.GetColorU32Vec4(V4(0.88, 0.91, 0.93, hovered and 1 or 0.95)), label)
        if hovered then
            local hint = u8(tr("legend_dist_close"))
            local hs = font:CalcTextSizeA(small * 0.85, math.huge, 0, hint)
            dl:AddTextFontPtr(font, small * 0.85, imgui.ImVec2(lx - px(10) - hs.x, ly + 1), imgui.GetColorU32Vec4(DIM), hint)
        end
        y = y + rowH
    end
    local mx, my, mz = getCharCoordinates(PLAYER_PED)
    local candId = Candidate.get()
    if candId and not State.hideCandDist then
        local ok, ped = sampGetCharHandleBySampPlayerId(candId)
        if ok and doesCharExist(ped) then
            distRow(tr("legend_dist") .. " " .. (Candidate.name ~= "" and Candidate.name or candId),
                    getDistanceBetweenCoords3d(mx, my, mz, getCharCoordinates(ped)),
                    function() State.hideCandDist = true end)
        end
    end
    local cp = State.checkpoint
    if cp then
        if cp.zone == nil then
            -- numele zonei, o singura data per checkpoint (din bucla de randare, nu din pachet)
            local okZ, zone = pcall(getNameOfZone, cp.x, cp.y, cp.z)
            local okG, disp = pcall(getGxtText, okZ and zone or "")
            cp.zone = (okG and disp and disp ~= "" and disp) or (okZ and zone) or false
        end
        local d = getDistanceBetweenCoords3d(mx, my, mz, cp.x, cp.y, cp.z)
        -- ajuns la checkpoint, sau prea vechi: dispare singur (serverul nu trimite mereu stergerea)
        if d < K.CP_REACHED or (cp.at and os.clock() - cp.at > K.CP_MAX_AGE) then
            State.checkpoint = nil
        else
            distRow("Checkpoint" .. (cp.zone and (" - " .. cp.zone) or ""), d, function() State.checkpoint = nil end)
        end
    end
    imgui.End()
    imgui.PopStyleColor(2)
end)
State.legendFrame.HideCursor = true

-- ============================================================
-- /sic - fereastra de teste (mica, dreapta jos, mutabila)
-- ============================================================
K.SIC_WIDTH, K.SIC_HEIGHT = 260, 350   -- marimea implicita; se poate schimba din colt
K.SIC_MIN_W, K.SIC_MIN_H = 240, 150    -- sub aceste marimi randurile care nu incap dispar

-- textul n al unui test, in limba din /sic si (pentru fly / sail) orasul ales
local function testText(test, n)
    local pack = test.texts or {}
    if test.city then pack = pack[State.sicCity] or pack[K.CITY_SF] or {} end
    local list = pack[State.sicLang] or pack[K.LANG_RO] or {}
    return list[n] or ("? " .. test.id .. " " .. n)
end

-- raspunsul asteptat la intrebarea n, sau nil daca nu e definit
local function testAnswer(test, n)
    if not test.answers then return nil end
    local list = test.answers[State.sicLang] or test.answers[K.LANG_RO] or {}
    return list[n]
end

-- eticheta unui tab din /sic (iconita sau text scurt) si numele lung pentru tooltip
local function sicTabLabel(test)
    if test == K.TAB_LEVEL50 then
        return State.icons and Licenses.byId[K.LIC_ALL].icon or "50", tr("tab_lvl50")
    end
    local lic = Licenses.byId[test.licId]
    return State.icons and lic.icon or lic.short, tr("tab_" .. test.id)
end

-- un rand de butoane egale pe toata latimea; onHover(i) se apeleaza cat timp butonul i e sub cursor
local function buttonRow(labels, height, onClick, onHover)
    local avail = imgui.GetContentRegionAvail().x
    local spacing = imgui.GetStyle().ItemSpacing.x
    local w = (avail - spacing * (#labels - 1)) / #labels
    for i, label in ipairs(labels) do
        if imgui.Button(label, imgui.ImVec2(w, height)) then onClick(i) end
        if onHover and imgui.IsItemHovered() then onHover(i) end
        if i < #labels then imgui.SameLine() end
    end
end

-- tooltip "intarziat": apare dupa K.HOVER_TIP_DELAY secunde de stat cu cursorul pe acelasi element
State.hoverTip = { key = nil, since = 0, frame = -1 }
function Tests.hoverLong(key)
    local frame = imgui.GetFrameCount()
    -- alt element, sau cursorul a lipsit macar un frame de pe el: numaratoarea o ia de la capat
    if State.hoverTip.key ~= key or frame - State.hoverTip.frame > 1 then State.hoverTip.key, State.hoverTip.since = key, os.clock() end
    State.hoverTip.frame = frame
    return os.clock() - State.hoverTip.since >= K.HOVER_TIP_DELAY
end

-- ce trimite in chat butonul n al testului (textele + raspunsurile), ca tooltip
function Tests.buttonTip(test, n)
    if not Tests.hoverLong(test.id .. n) then return end
    imgui.BeginTooltip()
    imgui.PushTextWrapPos(420)
    for k, textId in ipairs(test.buttons[n]) do
        if k > 1 then imgui.Spacing() end
        TC(BLUE, (test.channel == "chat") and "chat" or "/cw")
        imgui.SameLine(0, 6)
        TW(u8(testText(test, textId)))
        local answer = testAnswer(test, textId)
        if answer then
            local lines = type(answer) == "table" and answer or { answer }
            TC(GREEN, u8(tr("answer")) .. ":")
            imgui.SameLine(0, 6)
            TW(u8(lines[1]))
            for i = 2, #lines do TW(u8(lines[i])) end
        end
    end
    imgui.PopTextWrapPos()
    imgui.EndTooltip()
end

-- trimite pe /cw textele unui buton de test; daca vreun text contine /dl, dam si noi /dl;
-- la intrebari, arata instructorului (doar lui) raspunsul asteptat
-- arata instructorului (doar lui) raspunsul asteptat la intrebarea n
local function showAnswer(test, n)
    local answer = testAnswer(test, n)
    if not answer then return end
    -- un raspuns poate fi un text sau o lista de linii (ex. lista de arme)
    local lines = type(answer) == "table" and answer or { answer }
    for i, line in ipairs(lines) do
        local head = (i == 1) and (COLOR.DIM .. tr("answer") .. " " .. test.prefix .. n .. ": ") or ""
        chat(TAG.PREFIX .. head .. COLOR.TEXT .. line)
    end
end

local function sendTestButton(test, textIds, buttonIndex)
    local mentionsDl = false
    for _, n in ipairs(textIds) do
        local text = testText(test, n)
        Queue.push((test.channel == "chat") and text or ("/cw " .. text), test.delay)
        if text:find("/dl", 1, true) then mentionsDl = true end
        if (tonumber(cfg.main.showAnswers) or 0) == 1 then showAnswer(test, n) end
    end
    -- checklist: am pus intrebari / task-uri; la fly / sail ultimul task inseamna pasul "answer" facut
    local id = Candidate.get()
    if id then
        Check.markAsked(id)
        if test.prefix == "T" and buttonIndex == #test.buttons then Check.mark(id, "answer") end
    end
    if mentionsDl and (tonumber(cfg.main.autoDl) or 0) == 1 then
        -- /dl e o comanda a clientului SA:MP (etichete de debug pe vehicule), nu a serverului
        clientCommand("/dl")
    end
end

-- randul Give license / Failed, comun tuturor tab-urilor de test; lucreaza pe candidat
-- randul de jos: [screenshot] [Give license] [Failed / stoplesson]; Give / Failed lucreaza pe candidat
local function drawGiveFailRow(licId)
    local id = Candidate.get()
    local spacing = imgui.GetStyle().ItemSpacing.x

    if imgui.Button((State.icons and fa.CAMERA or "F8") .. "##shot", imgui.ImVec2(30, 26)) then takeScreenshot() end
    if imgui.IsItemHovered() then TIP(u8(tr("screenshot"))) end
    imgui.SameLine()

    -- iconitele sunt deja UTF-8: doar textul tradus trece prin u8()
    local giveLabel = (State.icons and (fa.CERTIFICATE .. " ") or "") .. u8(tr("give"))
    local failLabel = (State.icons and (fa.XMARK .. " ") or "") .. u8(tr("fail"))
    local w = (imgui.GetContentRegionAvail().x - spacing) / 2
    if primaryButton(giveLabel .. "##give", imgui.ImVec2(w, 26)) then
        if id then Give.withWithme(id, licId) else err(tr("no_candidate")) end
    end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_give"))) end
    imgui.SameLine()
    if imgui.Button(failLabel .. "##fail", imgui.ImVec2(w, 26)) then
        if id then stopLesson(id) else err(tr("no_candidate")) end
    end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_fail"))) end
end

K.GIVE_ROW_H = 26   -- randul de jos (screenshot / give / failed) e mereu pastrat

-- mai e loc pentru un rand de inaltimea h, pastrand randul de jos?
local function roomFor(h)
    return imgui.GetContentRegionAvail().y >= h + K.GIVE_ROW_H + imgui.GetStyle().ItemSpacing.y * 2
end

local function drawSicTestTab(test)
    local lic = Licenses.byId[test.licId]
    local theory = (test.prefix == "Q")

    -- Start lesson: butonul principal, pe toata latimea
    if roomFor(26) then
        local label = (State.icons and (fa.PLAY .. "  ") or "") .. u8(tr("startlesson"))
        if primaryButton(label .. "##startlesson", imgui.ImVec2(imgui.GetContentRegionAvail().x, 26)) then
            local id = Candidate.get()
            if id then startLesson(id, lic, theory) else err(tr("no_candidate")) end
        end
        if imgui.IsItemHovered() then TIP(u8(tr("tip_start"))) end
    end

    if test.city and roomFor(22) then
        local cityW = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x * 2) / 3
        local pick = choiceButtons("siccity", FACTION_OPTIONS, State.sicCity, cityW)
        if imgui.IsItemHovered() then TIP(u8(tr("tip_city"))) end
        if pick then State.sicCity = pick end
    end

    -- T1..Tn / Q1..Qn
    if roomFor(28) then
        local labels = {}
        for n = 1, #test.buttons do labels[n] = test.prefix .. n .. "##t" .. n end
        buttonRow(labels, 28, function(n) sendTestButton(test, test.buttons[n], n) end,
                  function(n) Tests.buttonTip(test, n) end)
    end

    -- HP-ul vehiculului candidatului (Flying / Sailing), rosu sub 950
    if test.city and feat("hpMonitor") and Lesson.practicalWith(Candidate.get()) and roomFor(16) then
        TC(DIM, u8(tr("hp_label")) .. ":")
        imgui.SameLine()
        if Vehicle.hp then
            TC(Vehicle.hp < K.HP_FAIL and RED or GREEN, string.format("%.0f", Vehicle.hp))
        else
            TC(DIM, "-")
        end
    end

    -- randul de jos
    local bottom = imgui.GetContentRegionAvail().y - K.GIVE_ROW_H
    if bottom > 0 then imgui.Dummy(imgui.ImVec2(0, bottom)) end
    drawGiveFailRow(test.licId)
end

local function drawSicLevel50Tab()
    local id, name = Candidate.get()
    if not id then
        TC(DIM, u8(tr("sic_no_candidate")))
        return
    end
    -- o singura linie: ce licente urmeaza din /withme (daca a fost anuntat) + nivel + suma; altfel candidatul
    local w = Withme.last
    if w and w.id == id then
        TC(DIM, u8(tr("sic_withme")) .. ":")
        imgui.SameLine()
        TC(BLUE, licenseShortList(w.lics) .. "  lvl " .. w.level)
        local total, base = subtotal(w.lics, w.level)
        if total then
            imgui.SameLine()
            TC(AMBER, moneyWithBonus(total, base))
        end
    else
        TC(GREEN, u8((name ~= "" and name or "?") .. " (" .. id .. ")"))
    end

    -- 5 licente pe doua randuri + "toate"
    local row1, row2 = {}, {}
    for i, lic in ipairs(Licenses.real) do
        local label = (State.icons and (lic.icon .. " ") or "") .. lic.short .. "##give" .. lic.id
        if i <= 3 then table.insert(row1, label) else table.insert(row2, label) end
    end
    -- randurile care nu mai incap (fereastra micsorata) nu se deseneaza
    local function fits() return imgui.GetContentRegionAvail().y >= 24 end
    local function licTip() TIP(u8(tr("tip_give_lic"))) end
    if fits() then buttonRow(row1, 24, function(i) Give.withWithme(id, Licenses.real[i].id) end, licTip) end
    if fits() then buttonRow(row2, 24, function(i) Give.withWithme(id, Licenses.real[i + 3].id) end, licTip) end
    if fits() and imgui.Button(u8(tr("sic_give_all")) .. "##giveall", imgui.ImVec2(imgui.GetContentRegionAvail().x, 24)) then
        Give.all(id)
    end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_give_all"))) end
end

imgui.OnFrame(function() return State.focused and (State.sic[0] or State.sicFade.alpha > 0) end, function(player)
    player.HideCursor = State.cursorHeldWithWindow   -- tasta "Cursor" tinuta cu o fereastra deschisa: cursorul dispare, camera e a ta
    local alpha = Fade.step(State.sicFade, State.sic[0])
    local res = imgui.GetIO().DisplaySize

    local sx, sy = tonumber(cfg.main.sicPosX) or -1, tonumber(cfg.main.sicPosY) or -1
    local pw, ph = tonumber(cfg.main.sicW) or -1, tonumber(cfg.main.sicH) or -1
    if sx < 0 or sy < 0 then
        imgui.SetNextWindowPos(imgui.ImVec2(res.x - 10, res.y - 10), App.cond(), imgui.ImVec2(1, 1))
    else
        imgui.SetNextWindowPos(imgui.ImVec2(sx, sy), App.cond())
    end
    if pw < K.SIC_MIN_W or ph < K.SIC_MIN_H then pw, ph = px(K.SIC_WIDTH), px(K.SIC_HEIGHT) end
    imgui.SetNextWindowSize(imgui.ImVec2(pw, ph), App.cond())
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(K.SIC_MIN_W, K.SIC_MIN_H), imgui.ImVec2(px(600), px(500)))


    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(8, 8))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(4, 4))
    imgui.Begin("SIC##sic", State.sic,
        bit.bor(imgui.WindowFlags.NoCollapse, imgui.WindowFlags.NoScrollbar))

    -- salvam pozitia si marimea cand se schimba
    local pos, size = imgui.GetWindowPos(), imgui.GetWindowSize()
    if math.floor(pos.x) ~= sx or math.floor(pos.y) ~= sy
       or math.floor(size.x) ~= pw or math.floor(size.y) ~= ph then
        cfg.main.sicPosX, cfg.main.sicPosY = math.floor(pos.x), math.floor(pos.y)
        cfg.main.sicW, cfg.main.sicH = math.floor(size.x), math.floor(size.y)
        State.sicPosDirty = true
    end

    -- bara de tab-uri (iconite) + comutatorul RO / EN, cu spatiu intre ele
    for i, test in ipairs(Tests) do
        local label, tip = sicTabLabel(test)
        if toggleButton(label .. "##sictab" .. i, State.sicTab == i, imgui.ImVec2(28, 24)) then State.sicTab = i end
        if imgui.IsItemHovered() then TIP(u8(tip)) end
        imgui.SameLine()
    end
    local label50, tip50 = sicTabLabel(K.TAB_LEVEL50)
    if toggleButton(label50 .. "##sictab50", State.sicTab == K.TAB_LEVEL50, imgui.ImVec2(28, 24), AMBER) then
        State.sicTab = K.TAB_LEVEL50
    end
    if imgui.IsItemHovered() then TIP(u8(tip50)) end
    imgui.SameLine(0, 14)
    if toggleButton(string.upper(State.sicLang) .. "##siclang", true, imgui.ImVec2(30, 24), BLUE) then
        State.sicLang = (State.sicLang == K.LANG_RO) and K.LANG_EN or K.LANG_RO
        -- comutatorul din /sic = "Limba mesajelor" din /sih (ultima schimbare conteaza); la candidat ramane limba lui
        cfg.main.procLang = State.sicLang
        saveCfg()
        Langs.remember(Candidate.get(), State.sicLang)
    end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_lang"))) end
    -- "inchide tot", in dreapta, pe acelasi rand cu tab-urile
    imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - 30)
    Actions.closeAllButton("sic")
    imgui.Separator()

    -- randul cu candidatul: ID [-][camp][+][cel mai apropiat]  Nume; se poate schimba oricand
    State.textInput = imgui.GetIO().WantTextInput
    local candNow = Candidate.get()
    if candNow ~= State.candShown then
        State.candShown = candNow
        imgui.StrCopy(State.candBuf, candNow and tostring(candNow) or "")
    end
    TC(DIM, "ID")
    imgui.SameLine()
    if imgui.Button("-##candm", imgui.ImVec2(20, 20)) then Candidate.set(stepConnected(candNow, -1)) end
    imgui.SameLine()
    imgui.PushItemWidth(40)
    if imgui.InputText("##candid", State.candBuf, 8, imgui.InputTextFlags.CharsDecimal) then
        local typed = tonumber(ffi.string(State.candBuf))
        if typed and sampIsPlayerConnected(typed) then
            Candidate.set(typed)
            State.candShown = typed
        end
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    if imgui.Button("+##candp", imgui.ImVec2(20, 20)) then Candidate.set(stepConnected(candNow, 1)) end
    imgui.SameLine()
    if imgui.Button((State.icons and fa.LOCATION_CROSSHAIRS or "N") .. "##candn", imgui.ImVec2(24, 20)) then
        local near = nearestPlayer()
        if near then Candidate.set(near) else err(tr("no_near", K.NEAR_DISTANCE)) end
    end
    if imgui.IsItemHovered() then TIP(u8(tr("nearest"))) end
    imgui.SameLine()
    local candName = playerName(candNow)
    if candName then TC(GREEN, u8(candName)) else TC(DIM, u8(tr("no_candidate"))) end
    if Candidate.locked and candNow then
        imgui.SameLine(0, 6)
        TC(DIM, State.icons and fa.LOCK or "[L]")
        if imgui.IsItemHovered() then TIP(u8(tr("cand_locked_tip"))) end
    end

    -- butonul de accept, pe doua randuri: "Nume - ID" / "Accepta ultimul /needlicense";
    -- tinta e ultimul /needlicense (nu candidatul): candidatul devine el abia dupa accept
    local needId = LastNeed.id
    local needName = needId and (LastNeed.name ~= "" and LastNeed.name or playerName(needId)) or nil
    local who = needId and ((needName or "?") .. " - " .. needId) or "-"
    local acceptLabel = who .. "\n" .. tr("accept_btn")
    -- [Accepta ultimul /needlicense] [RL]: request licenses pentru candidat, altfel cel mai apropiat, altfel eroare
    local rlW = 44
    if toggleButton(u8(acceptLabel) .. "##accept", needId ~= nil, imgui.ImVec2(imgui.GetContentRegionAvail().x - rlW - imgui.GetStyle().ItemSpacing.x, 36)) then
        trace("accept (buton) " .. tostring(needId))
        if not needId then err(tr("no_need"))
        else sendAccept(needId) end
    end
    if imgui.IsItemHovered() then TIP(u8(tr("tip_accept"))) end
    imgui.SameLine()
    local rlLabel = (State.icons and (fa.ID_CARD .. "\n") or "") .. "RL"
    if toggleButton(rlLabel .. "##reqlic", candNow ~= nil, imgui.ImVec2(rlW, 36)) then
        local target = candNow or nearestPlayer()
        if target then Queue.push("/requestlicenses " .. target)
        else err(tr("no_near", K.NEAR_DISTANCE)) end
    end
    if imgui.IsItemHovered() then TIP(u8(tr("reqlic_tip"))) end

    -- linia candidatului, ca in mockup: "Lv 27  Â·  Coada: Fly -> Sail" (ce a fost anuntat in /withme)
    if candNow then
        mono(function()
            local lvl = playerLevel(candNow)
            TC(DIM, "Lv ")
            imgui.SameLine(0, 0)
            TC(TEXT, lvl and tostring(lvl) or "?")
            local w = Withme.last
            if w and w.id == candNow then
                imgui.SameLine(0, 14)
                TC(DIM, u8(tr("queue")) .. ": ")
                imgui.SameLine(0, 0)
                TC(GREEN, (licenseShortList(w.lics):gsub(", ", " > ")))
            end
        end)
    end

    -- (starea de duty nu se mai scrie aici: o arata slotul DUTY din bara de iconite)
    imgui.Separator()

    -- continutul tab-ului
    imgui.BeginChild("##sicbody", imgui.ImVec2(0, -22), false, imgui.WindowFlags.NoScrollbar)
    if State.sicTab == K.TAB_LEVEL50 then
        drawSicLevel50Tab()
    else
        drawSicTestTab(Tests[State.sicTab] or Tests[1])
    end
    imgui.EndChild()

    -- ultimul mesaj trimis, ca sa nu te uiti in chat
    imgui.Separator()
    if feat("sicLastSent") then
        local last = Queue.lastSent or tr("sic_nothing")
        if #last > 38 then last = last:sub(1, 36) .. ".." end
        TC(DIM, u8(last))
    end



    imgui.End()
    imgui.PopStyleVar(3)
end)

-- ============================================================
-- MODULUL PENTRU DEPARTAMENTE (PD / FBI / NG): moonloader/SICHelper/pd.lua + config/SICHelper_pd.lua
-- Fisier separat: scriptul principal e aproape de limita de 200 de variabile locale a Lua.
-- Primeste aici tot ce foloseste; daca lipseste sau are o eroare, restul helperului merge normal.
-- ============================================================
K.PD_FILE = getWorkingDirectory() .. "\\SICHelper\\pd.lua"
do
    local ok, res = pcall(dofile, K.PD_FILE)
    if ok and type(res) == "function" then
        ok, res = pcall(res, {
            imgui = imgui, u8 = u8, new = new, ffi = ffi, bit = bit, fa = fa,
            cfg = cfg, saveCfg = saveCfg, tr = tr, K = K, trace = trace,
            Queue = Queue, msg = msg, err = err, usage = usage, nameTag = nameTag,
            idOnline = idOnline, playerName = playerName, nearestPlayer = nearestPlayer, stepConnected = stepConnected,
            playerLevel = playerLevel, rememberLevel = rememberLevel, Langs = Langs,
            App = App, State = State, Fade = Fade, Factions = Factions, Notify = Notify, Duty = Duty, FVR = FVR,
            takeScreenshot = takeScreenshot, closeAllButton = Actions.closeAllButton, guideLine = guideLine,
            toggleButton = toggleButton, primaryButton = primaryButton, TC = TC, TW = TW, TIP = TIP, px = px,
            theme = function() return Themes.byId[cfg.main.theme] or Themes.byId.si end,
            colors = { DIM = DIM, TEXT = TEXT, RED = RED, AMBER = AMBER, OK = OK_GREEN, BLUE = BLUE },
        })
    end
    if ok and type(res) == "table" then
        App.PD = res
        App.PD.addActions(Actions.list, Actions.byId, cfg.binds)
    else
        App.PDError = tostring(res)
        trace("modulul PD nu s-a incarcat: " .. App.PDError)
    end
end

-- ============================================================
-- EVENIMENTE SERVER
-- ============================================================
-- un /needlicense sosit: mesaj in chat + notificare. Cat jocul e in bara (alt-tab / minimizat) NU se prelucreaza
-- nimic - se pune in asteptare si se prelucreaza abia cand jocul e din nou in fata (din bucla principala):
-- cele mai vechi de K.NEED_MAX_AGE secunde se arunca, iar daca raman prea multe se pastreaza doar ultimele
-- K.NEED_MAX_SHOW (se sterg de la cea mai veche spre cea mai noua).
local Need = { queue = {} }   -- cererile amanate: { pid, at, takenBy }
-- partea a doua: linia din chat + cartonasul, cu nivelul cunoscut (sau "?" daca nu s-a putut afla)
function Need.finish(pid, nick, level, ageSec, takenBy)
    local mode = tonumber(cfg.main.needMode) or 0
    trace("needlicense " .. tostring(pid) .. " " .. tostring(nick) .. " nivel " .. tostring(level) .. " (3 chat)")
    -- mesaj clar in chat: cine, ce nivel, cum accepti
    local key = Keys.nameOf("acc")
    local how = (key and key ~= "None" and (tonumber(cfg.binds.acc_on) or 0) == 1)
        and tr("need_how_key", key) or tr("need_how_sic")
    local ago = (ageSec and ageSec >= 15) and (" " .. COLOR.DIM .. "(" .. tr("notify_ago", math.floor(ageSec / 60), math.floor(ageSec % 60)) .. ")") or ""
    local tail = takenBy and (" " .. COLOR.DIM .. tr("notify_taken", takenBy)) or (" " .. COLOR.DIM .. how)
    msg(tr("need_license", nameTag(pid, nick), level and tostring(level) or "?") .. ago .. tail)

    if mode == 3 then trace("needlicense (mod 3 gata)") return end
    trace("needlicense (4 notify)")
    Notify.needlicense(pid, nick, ageSec, takenBy, level)
    trace("needlicense (5 gata)")
end

function Need.handle(pid, ageSec, takenBy)
    -- /sicneed 0|1|2 : cat de mult face helperul la /needlicense (cautam ce anume crapa clientul)
    --   0 = tot (normal)   1 = doar linia din chat, fara nivel / notificare   2 = nimic (doar nota in urma)
    --   3 = linia completa din chat + nivel, fara cartonasul de notificare
    local mode = tonumber(cfg.main.needMode) or 0
    trace("needlicense " .. tostring(pid) .. " (mod " .. mode .. ")")
    if mode >= 2 then return end
    local nick = playerName(pid)
    LastNeed.id, LastNeed.name = pid, nick
    if mode == 1 then
        msg(tr("need_license", nameTag(pid, nick), "?"))
        trace("needlicense (mod 1 gata)")
        return
    end
    trace("needlicense (2 nivel)")
    local level = playerLevel(pid)          -- doar daca il stim deja dintr-un /id anterior
    if level then Need.finish(pid, nick, level, ageSec, takenBy) return end

    -- jucatorul e departe: nivelul se afla ca la AdeM, cu /id (raspunsul e ascuns); linia si cartonasul
    -- apar cand vine raspunsul, sau dupa K.NEED_ID_TIMEOUT secunde cu "?"
    Need.idPending = { pid = pid, nick = nick, ageSec = ageSec, takenBy = takenBy, at = os.clock() }
    Queue.pushFront("/id " .. pid)
    trace("needlicense (2b /id trimis)")
end

-- a venit un raspuns la /id cu nivelul (apelat din onServerLine); true daca l-am folosit noi (linia se ascunde)
function Need.onLevel(level)
    local p = Need.idPending
    if not p or os.clock() - p.at > K.NEED_ID_TIMEOUT then return false end
    Need.idPending = nil
    rememberLevel(p.pid, level)
    Need.finish(p.pid, p.nick, level, p.ageSec, p.takenBy)
    return true
end

-- fara raspuns la /id in timp util: aratam cererea cu nivel necunoscut (din bucla principala)
function Need.update()
    local p = Need.idPending
    if p and os.clock() - p.at > K.NEED_ID_TIMEOUT then
        Need.idPending = nil
        Need.finish(p.pid, p.nick, nil, p.ageSec, p.takenBy)
    end
end
-- cele amanate, prelucrate cand jocul e iar in fata (apelat din bucla principala)
function Need.flush()
    if #Need.queue == 0 or not gameInFront() then return end
    local now = os.time()
    local fresh = {}
    for _, e in ipairs(Need.queue) do
        -- o cerere preluata intre timp de alt instructor se mai arata doar K.NEED_TAKEN_AGE secunde
        local maxAge = e.takenBy and K.NEED_TAKEN_AGE or K.NEED_MAX_AGE
        if now - e.at <= maxAge and sampIsPlayerConnected(e.pid) then table.insert(fresh, e) end
    end
    Need.queue = {}
    while #fresh > K.NEED_MAX_SHOW do table.remove(fresh, 1) end   -- prea multe: cad cele mai vechi
    for _, e in ipairs(fresh) do Need.handle(e.pid, now - e.at, e.takenBy) end
end

-- alt instructor a acceptat cererea jucatorului dat: se noteaza in lista de asteptare si pe cartonasul
-- deja afisat (daca e), care mai ramane putin si spune cine a preluat-o
function Need.takenBy(instructor, playerName_)
    local pid = findPlayerByName(playerName_)
    for _, e in ipairs(Need.queue) do
        if e.pid == pid or (pid == nil and e.pid and sampGetPlayerNickname(e.pid) == playerName_) then e.takenBy = instructor end
    end
    for _, n in ipairs(Notify.items) do
        if n.needId and (n.needId == pid) and not n.closing then
            n.text = tr("notify_taken", instructor)
            n.kind = "info"
            trace("cerere preluata de " .. tostring(instructor) .. " (" .. tostring(playerName_) .. ")")
            n.until_ = math.min(n.until_, os.clock() + K.NOTIFY_TAKEN_SECONDS)
        end
    end
    if LastNeed.id == pid then LastNeed.takenBy = instructor end
    -- daca eu acceptasem cererea asta, checkpoint-ul de pe drum nu mai are rost: il sterg si il scot din legenda
    if pid and State.acceptedId == pid then
        State.acceptedId = nil
        if State.checkpoint then
            State.checkpoint = nil
            if feat("clearCp") then
                for _, c in ipairs(Data.clear_checkpoint or { "/killcp" }) do Queue.push(c) end
            end
            msg(tr("cp_cleared", tostring(instructor)))
        end
    end
end

-- prelucrarea unei linii de la server (corpul propriu-zis); e masurata mai jos ca sa vedem daca produce inghetari
local function onServerLine(color, text)
    -- modulul PD: cei prinsi de radar, raspunsurile la /id, duty-ul la departamente
    if App.PD then
        local okPd, errPd = pcall(App.PD.onServerLine, text)
        if not okPd then trace("pd: " .. tostring(errPd)) end
    end

    -- serverul anunta: ... /accept needlicense <id> ...
    local service, id = text:match(SERVER.ACCEPT_SERVICE)
    if service and id and service:lower() == "needlicense" then
        local pid = tonumber(id)
        -- limba jucatorului, daca a scris RO / EN in cerere (pentru sms, /w, teste)
        local lang = Langs.detect(text)
        if lang then Langs.remember(pid, lang) trace("needlicense " .. pid .. " limba " .. lang) end
        if gameInFront() then
            Need.handle(pid)
        else
            table.insert(Need.queue, { pid = pid, at = os.time() })   -- ceas real: in bara, os.clock() sta pe loc
            trace("needlicense " .. tostring(pid) .. " amanat (joc in fundal)")
        end
    end


    -- serverul ne-a oferit o licenta (la /giveme): o acceptam singuri
    do
        local plain = text:gsub("{%x%x%x%x%x%x}", "")
        for _, needle in ipairs(Data.license_offered or {}) do
            if plain:find(needle) then Give.meOffered() break end
        end
    end
    -- cererea a fost preluata de alt instructor (pattern-urile din fisierul de date); liniile cu "accept"
    -- se noteaza in urma ca sa putem afla formatul exact al serverului
    do
        local plain = text:gsub("{%x%x%x%x%x%x}", "")
        if plain:lower():find("accept", 1, true) and not plain:find("/accept", 1, true) then trace("srv: " .. plain) end
        for _, pattern in ipairs(Data.accepted_by or {}) do
            local instructor, who = plain:match(pattern)
            if instructor and who then Need.takenBy(instructor, who) break end
        end
    end

    -- raspunsul la /id: "... | Level: 37 ..."
    local level = text:match(SERVER.LEVEL_EN) or text:match(SERVER.LEVEL_RO)
    if level then
        if Withme.pending then Withme.onLevel(tonumber(level))
        elseif Need.onLevel(tonumber(level)) then return false end   -- /id-ul nostru automat: raspunsul nu se afiseaza
    end

    -- ORICE raspuns la /id, chiar daca nu l-am cerut din fereastra /info: retinem nivelul si
    -- factiunea jucatorului. De aici stim daca e dintr-o factiune aliata cand ii dam licenta.
    if App and App.Info and text:find("Ping:", 1, true) then
        local plain = text:gsub("{%x%x%x%x%x%x}", "")
        local d = App.Info.parse(plain)
        if d and d.name then
            d.at = os.clock()
            App.Info.cache[d.name] = d
            if d.id then App.Info.byId[d.id] = d end
        end
    end

    -- serverul ne trimite la /pin dupa o plata: o punem inapoi in coada si asteptam deblocarea
    if App and App.Ally and App.Ally.last and text:find("/pin", 1, true) then
        App.Ally.onPinNeeded()
    end

    -- deconectare: banii se blocheaza din nou pana la urmatorul /pin
    if text:find("Server closed the connection", 1, true) or text:find("Lost connection", 1, true) then
        State.pinOk = false
    end

    -- raspunsul la /id cerut de fereastra /info: il folosim noi si nu se mai afiseaza in chat
    if App and App.Info and App.Info.pending then
        if App.Info.onLine((text:gsub("{%x%x%x%x%x%x}", ""))) then return false end
    end

    -- erorile serverului ca notificare: din lista editabila, sau orice refuz la scurt timp dupa /accept needlicense
    do
        local low = text:gsub("{%x%x%x%x%x%x}", ""):lower()
        local isError = false
        for _, needle in ipairs(Data.notify_errors or {}) do
            if low:find(needle:lower(), 1, true) then isError = true break end
        end
        if not isError and State.acceptSentAt and os.clock() - State.acceptSentAt < 2
           and (low:find("cerer", 1, true) or low:find("request", 1, true)) and not low:find("acceptat", 1, true) then
            isError = true
        end
        if isError then
            Notify.error((text:gsub("{%x%x%x%x%x%x}", "")))
            if State.acceptSentAt and os.clock() - State.acceptSentAt < K.SMS_DELAY then Sms.cancel() end   -- accept refuzat: fara SMS
        end
    end

    -- /requestlicenses confirmat de server: pasul "request" din checklist
    if text:find("I-ai solicitat licentele", 1, true) then
        local candId = Candidate.get()
        if candId then Check.mark(candId, "request") Candidate.lock() end
    end

    -- raspunsul candidatului venit ca mesaj de server (ex. whisper): pasul "answer"
    do
        local candId, candName = Candidate.get()
        if candId and Check.asked and candName ~= "" and text:find(candName, 1, true)
           and not text:find("/cw ", 1, true) then
            Check.mark(candId, "answer")
        end
    end

    -- starea de duty
    for _, pattern in ipairs(SERVER.DUTY_ON) do
        if text:find(pattern, 1, true) then Duty.set(true) end
    end
    for _, pattern in ipairs(SERVER.DUTY_OFF) do
        if text:find(pattern, 1, true) then Duty.set(false) end
    end
    for _, pattern in ipairs(SERVER.NOT_ON_DUTY) do
        if text:find(pattern, 1, true) then
            Duty.set(false)
            Give.chain = nil   -- fara duty, lantul de licente nu mai are sens
        end
    end

    -- jucatorul a acceptat licenta: continuam lantul de la 50+ sau oprim lectia
    local accepted = nil
    for _, pattern in ipairs(SERVER.GAVE) do
        accepted = text:match(pattern)
        if accepted then break end
    end
    -- formulari noi ale serverului: orice linie despre o licenta acordata / oferita
    if not accepted and text:find("[Ll]icen") and (text:find("acordat") or text:find("You gave") or text:find("you gave")) then
        accepted = text
    end
    if accepted then Give.onAccepted(accepted) end

    -- schimbarea jobului (repair / refill)
    for _, pattern in ipairs(SERVER.JOB_CHANGED) do
        local job = text:match(pattern)
        if job then RR.onJob(job) break end
    end
    for _, pattern in ipairs(SERVER.NO_SWITCHJOB) do
        if text:find(pattern, 1, true) then RR.onNoSwitch() end
    end
end

function sampev.onServerMessage(color, text)
    local t0 = os.clock()
    local result = onServerLine(color, text)   -- false = linia nu se mai afiseaza (ex. raspunsul la /id-ul automat)
    local ms = (os.clock() - t0) * 1000
    -- daca prelucrarea unei linii dureaza peste 5 ms, notam (cautam sursa inghetarilor din chat)
    if ms > 5 then trace(string.format("lent: linie de server %.1f ms: %s", ms, (text:gsub("{%x%x%x%x%x%x}", "")))) end
    return result
end

-- dialogul de la /requestlicenses: retinem licentele si orele candidatului (dialogul ramane pe ecran)
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if not (title and text) then return end
    trace("dialog " .. tostring(dialogId) .. " style " .. tostring(style) .. ": " .. tostring(title))
    Candidate.parseLicenseDialog(title, text)
    -- /raport: aratam fereastra noastra si ascundem dialogul serverului
    if Report.parse(title, text) and feat("reportWindow") then
        Report.open[0] = true
        return false
    end
end

-- evenimente de fereastra / placa video, notate in urma (crash-urile la alt-tab)
addEventHandler("onD3DDeviceLost",  function() trace("d3d: device lost (alt-tab / minimizat)") end)
addEventHandler("onD3DDeviceReset", function() trace("d3d: device reset (inapoi in joc)") end)
-- ESC cu o fereastra a helperului deschisa: o inchidem NOI si oprim tasta inainte sa ajunga la joc,
-- ca sa nu se deschida meniul GTA peste. Se ruleaza la nivel de mesaj Windows (inaintea jocului).
-- Ordinea: fereastra de intrebare -> /sih -> /raport -> /sic. In chat / dialog / meniu nu intervenim.
function Actions.escCloses()
    if sampIsChatInputActive() or sampIsDialogActive() or isPauseMenuActive() then return false end
    if Keys.capturing then return false end          -- in modul de captura ESC e tratat in Keys.update
    if Prompt.open[0] then Prompt.close() return true end
    if State.sih[0] then State.sih[0] = false return true end
    if Report.open[0] then Report.open[0] = false return true end
    if State.sic[0] then State.sic[0] = false return true end
    if App.PD and App.PD.open[0] then App.PD.open[0] = false return true end
    if App.Wizard.open[0] then App.Wizard.open[0] = false return true end
    if App.Info.open[0] then App.Info.open[0] = false return true end
    -- ESC in timpul unei editari din /notepad: renunta la editare, fereastra ramane
    if State.notes[0] and (State.noteEdit or State.foldEdit) then State.noteEdit, State.foldEdit, State.noteBlur = nil, nil, nil return true end
    if State.notes[0] then State.notes[0] = false return true end
    return false
end

addEventHandler("onWindowMessage", function(msg, wparam, lparam)
    if msg == 0x0008 then State.focused = false trace("window: focus pierdut") end   -- WM_KILLFOCUS
    if msg == 0x0007 then State.focused = true  trace("window: focus primit") end    -- WM_SETFOCUS
    if (msg == 0x0100 or msg == 0x0104) and wparam == 0x1B then                      -- WM_KEYDOWN / WM_SYSKEYDOWN, VK_ESCAPE
        if Actions.escCloses() then
            consumeWindowMessage(true, true)   -- nici jocul, nici alte scripturi nu mai vad acest ESC
            State.escConsumed = true
        end
    end
    if (msg == 0x0101 or msg == 0x0105) and wparam == 0x1B and State.escConsumed then  -- WM_KEYUP / WM_SYSKEYUP
        State.escConsumed = false
        consumeWindowMessage(true, true)
    end
end)

-- dialogul de /raport prins la nivel de pachet, INAINTE sa fie afisat: fara clipire.
-- (hook-ul samp.events pentru onShowDialog nu se declanseaza pe acest server; citim pachetul noi)
addEventHandler("onReceiveRpc", function(id, bs)
    if id ~= RPC_SCRSHOWDIALOG or not feat("reportWindow") then return end
    local ok, result = pcall(function()
        local dialogId = raknetBitStreamReadInt16(bs)
        raknetBitStreamReadInt8(bs)                  -- style
        local title = raknetBitStreamReadString(bs, raknetBitStreamReadInt8(bs))
        raknetBitStreamReadString(bs, raknetBitStreamReadInt8(bs))   -- button1
        raknetBitStreamReadString(bs, raknetBitStreamReadInt8(bs))   -- button2
        local text = raknetBitStreamDecodeString(bs, 4096)
        raknetBitStreamResetReadPointer(bs)
        trace("dialog(rpc): " .. tostring(title))
        if Report.parse(title, text) then
            Report.lastDialogId = dialogId
            Report.open[0] = true
            -- serverul asteapta un raspuns: ii spunem ca am apasat Close, altfel retrimite dialogul
            -- raspunsul se trimite ca pachet brut (RPC DialogResponse), fara sa atingem dialogul clientului,
            -- care nu a fost niciodata afisat
            Defer.push(function()
                pcall(function()
                    local out = raknetNewBitStream()
                    raknetBitStreamWriteInt16(out, dialogId)   -- dialogul la care raspundem
                    raknetBitStreamWriteInt8(out, 1)           -- butonul 1 = Close
                    raknetBitStreamWriteInt16(out, 0)          -- niciun rand selectat
                    raknetBitStreamWriteInt8(out, 0)           -- text de raspuns gol
                    raknetSendRpc(RPC_DIALOGRESPONSE, out)
                    raknetDeleteBitStream(out)
                end)
            end)
            return true
        end
        return false
    end)
    if ok and result == true then return false end   -- pachet consumat: dialogul nu se mai afiseaza
end)


-- mesajul de distanta al serverului de pe ecran (gametext / textdraw), ascuns cand avem candidat si
-- legenda noastra arata deja distanta (Features -> "Ascunde distanta serverului"); textele se noteaza in urma
function Need.srvDistText(text)
    if type(text) ~= "string" then return false end
    local plain = text:gsub("~%a~", ""):gsub("{%x%x%x%x%x%x}", ""):lower()
    return plain:find("distan", 1, true) ~= nil
end
function Need.hideSrvDist()
    return feat("hideSrvDist") and feat("bindLegend") and State.checkpoint ~= nil
end
function sampev.onDisplayGameText(style, time, text)
    if Need.srvDistText(text) then
        trace("gametext: " .. tostring(text))
        if Need.hideSrvDist() then return false end
    end
end
function sampev.onShowTextDraw(id, data)
    if data and Need.srvDistText(data.text) then
        trace("textdraw " .. tostring(id) .. ": " .. tostring(data.text))
        if Need.hideSrvDist() then State.hiddenTextdraws[id] = true return false end
    end
end
function sampev.onTextDrawSetString(id, text)
    if Need.srvDistText(text) then
        if not State.hiddenTextdraws[id] then trace("textdraw " .. tostring(id) .. " set: " .. tostring(text)) end
        if Need.hideSrvDist() then State.hiddenTextdraws[id] = true return { id, "" } end
    end
end
function sampev.onTextDrawHide(id)
    State.hiddenTextdraws[id] = nil
end

-- checkpoint-ul pus de server (la accept, pe candidat): il tinem minte pentru distanta din legenda
function sampev.onSetCheckpoint(position, radius)
    State.checkpoint = { x = position.x, y = position.y, z = position.z, at = os.clock() }
end
function sampev.onDisableCheckpoint()
    State.checkpoint = nil
end
-- raspunsul candidatului in chat (pentru pasul "answer" din checklist)

-- comenzile trimise de tine: ne intereseaza doar /pin, ca sa stim cand ti-ai deblocat banii
function sampev.onSendCommand(command)
    if App.PD then pcall(App.PD.onSendCommand, command) end
    local c = tostring(command or ""):lower()
    if c:find("^/pin") and not State.pinOk then
        State.pinOk = true
        trace("pin introdus: platile catre aliati pot pleca")
        Defer.push(function() if App and App.Ally then App.Ally.flush() end end)
    end
end

function sampev.onPlayerChat(playerId, text)
    local id = Candidate.get()
    if id and playerId == id and Check.asked then Check.mark(id, "answer") end
end

-- ============================================================
-- COMENZI
-- ============================================================
local function registerCommands()
    -- /pdh: aceeasi fereastra de setari, cu numele obisnuit la departamente
    for _, name in ipairs({ "sih", "pdh" }) do
        sampRegisterChatCommand(name, function() State.sih[0] = not State.sih[0] end)
    end

    -- /sic: statia factiunii tale (la departamente, statia PD)
    sampRegisterChatCommand("sic", function()
        if App.PD and App.PD.isDept() then App.PD.toggle() return end
        State.sic[0] = not State.sic[0]
    end)

    sampRegisterChatCommand("siccand", function(arg)
        local id = tonumber(arg)
        if not id then usage("/siccand <id>") return end
        id = requireOnline(id)
        if not id then return end
        Candidate.set(id)
        msg(tr("candidate_is", nameTag(id, playerName(id))))
    end)

    -- /withme <id> <1-6> [1-6 ...]; fara argumente deschide fereastra
    sampRegisterChatCommand("withme", function(arg)
        local parts = {}
        for word in arg:gmatch("%S+") do table.insert(parts, word) end
        if #parts == 0 then
            Withme.ask(Candidate.get() or nearestPlayer())
            return
        end
        if #parts < 2 or not tonumber(parts[1]) then
            usage(tr("usage_withme"))
            usage(tr("lic_list"))
            return
        end
        -- cifrele 1-6 se convertesc imediat in identificatori LIC_*; mai departe nu circula numere
        local lics = {}
        for i = 2, #parts do
            local lic = Licenses.byNumber[tonumber(parts[i])]
            if not lic then
                err(tr("bad_lic"))
                usage(tr("lic_list"))
                return
            end
            lics[lic.id] = true
        end
        if lics[K.LIC_ALL] then lics = { [K.LIC_ALL] = true } end
        Withme.start(tonumber(parts[1]), lics)
    end)

    -- /giveme [1-6 ...]: licentele pentru tine; fara argumente deschide fereastra de selectie
    sampRegisterChatCommand("giveme", function(arg)
        local lics = {}
        for word in arg:gmatch("%S+") do
            local lic = Licenses.byNumber[tonumber(word)]
            if not lic then err(tr("bad_lic")) usage(tr("lic_list")) return end
            lics[lic.id] = true
        end
        if next(lics) == nil then
            local myId = myPlayerId()
            Prompt.show({
                title = "Giveme",
                id = myId,
                needLic = true,
                cb = function(_, chosen) Give.me(chosen) end,
            })
            return
        end
        Give.me(lics)
    end)
    sampRegisterChatCommand("sicraport", function() Report.open[0] = not Report.open[0] end)
    -- /info <id|nume>: fereastra noastra. Fara argument sau cu un argument necunoscut, comanda
    -- pleaca la server, ca inainte (serverul isi are propriul /info).
    sampRegisterChatCommand("info", function(arg)
        local a = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local id = tonumber(a)
        if not id and a ~= "" then id = findPlayerByName(a) end
        if id then App.Info.show(id) return end
        Queue.push("/info" .. (a ~= "" and (" " .. a) or ""))
    end)
    -- varianta care e mereu a helperului: fara argument ia candidatul sau cel mai apropiat jucator
    sampRegisterChatCommand("sicinfo", function(arg)
        local id = tonumber(arg) or findPlayerByName(tostring(arg or "")) or Candidate.get() or nearestPlayer()
        if not id then err(tr("no_candidate")) return end
        App.Info.show(id)
    end)
    sampRegisterChatCommand("sicwizard", function() App.Wizard.start(true) end)
    -- /sicpay: trimite acum platile catre aliati care asteptau deblocarea banilor
    sampRegisterChatCommand("sicpay", function()
        if #App.Ally.queue == 0 then msg(tr("ally_none_due")) return end
        State.pinOk = true
        App.Ally.flush()
    end)
    sampRegisterChatCommand("sicreset", function() App.resetLayout() end)
    -- notitele: aceeasi fereastra pe /notepad, /note sau /notite
    for _, name in ipairs({ "notepad", "note", "notite" }) do
        sampRegisterChatCommand(name, function() State.notes[0] = not State.notes[0] end)
    end
    -- diagnostic: cat de mult face helperul la /needlicense (0 tot, 1 doar chat, 2 nimic)
    sampRegisterChatCommand("sicneed", function(arg)
        local mode = tonumber(arg)
        if not mode or mode < 0 or mode > 3 then usage("/sicneed 0|1|2|3  (0 = tot, 1 = doar chat, 2 = nimic, 3 = chat + nivel, fara cartonas)") return end
        cfg.main.needMode = mode
        saveCfg()
        msg("needlicense: mod " .. mode .. " (" .. ({ [0] = "tot", [1] = "doar chat", [2] = "nimic", [3] = "chat + nivel, fara cartonas" })[mode] .. ")")
    end)
    sampRegisterChatCommand("ffvr", function() FVR.start() end)
    sampRegisterChatCommand("sfvr", function() FVR.stop() end)

    sampRegisterChatCommand("sxwas", function(arg)
        local id = tonumber(arg)
        if not id then usage(tr("usage_sxwas")) return end
        sxwas(id)
    end)
    -- mesaje catre candidat pe /w; fara id: candidatul (salut / pa) sau cel mai apropiat jucator (need)
    sampRegisterChatCommand("salut", function(arg) whisper("salut", tonumber(arg) or Candidate.get()) end)
    sampRegisterChatCommand("pa",    function(arg) whisper("pa",    tonumber(arg) or Candidate.get()) end)
    sampRegisterChatCommand("need",  function(arg) whisper("need",  tonumber(arg) or nearestPlayer()) end)
    sampRegisterChatCommand("ok",    function(arg) whisper("ok",    tonumber(arg) or Candidate.get()) end)

    -- ------------------------------------------------------------
    -- scurtaturile din SIHelper-ul lui AdeM (aceleasi nume), legate de logica noastra
    -- fara id: candidatul (la /acc: ultimul /needlicense)
    -- ------------------------------------------------------------
    local function idOrCandidate(arg)
        local id = tonumber(arg) or Candidate.get()
        if not id then err(tr("no_candidate")) end
        return id
    end
    sampRegisterChatCommand("acc", function(arg)
        local id = tonumber(arg) or LastNeed.id
        if not id then err(tr("no_need")) return end
        sendAccept(id)
    end)
    sampRegisterChatCommand("rl", function(arg) local id = idOrCandidate(arg) if id then Queue.push("/requestlicenses " .. id) end end)
    sampRegisterChatCommand("sl", function(arg)
        -- la departamente /sl e sanctiunea pentru ultimul prins de radar (ca in PDHelper)
        if App.PD and App.PD.isDept() then App.PD.SHORTS.sl(arg) return end
        local id = idOrCandidate(arg)
        if id then stopLesson(id) end
    end)
    -- give / start lesson pe licenta: gw gm gs gf gfl / sw sm ss sf sfl
    local licShort = { w = K.LIC_WEAPONS, m = K.LIC_MATERIALS, s = K.LIC_SAILING, f = K.LIC_FISHING, fl = K.LIC_FLYING }
    for short, licId in pairs(licShort) do
        sampRegisterChatCommand("g" .. short, function(arg) local id = idOrCandidate(arg) if id then Give.one(id, licId) end end)
        sampRegisterChatCommand("s" .. short, function(arg)
            local id = idOrCandidate(arg)
            if not id then return end
            local lic = Licenses.byId[licId]
            local theory = (licId ~= K.LIC_FLYING and licId ~= K.LIC_SAILING)
            startLesson(id, lic, theory)
        end)
    end
    -- textele testelor: w1..w5, m1..m4, f1..f4, lsfl1..3 / lvfl / sffl (Flying), lss1..2 / lvs / sfs (Sailing)
    local testShort = { weap = "w", mat = "m", fish = "f", fly = "fl", sail = "s" }
    for _, test in ipairs(Tests) do
        local short = testShort[test.id]
        if short then
            for n = 1, #test.buttons do
                local cities = test.city and { K.CITY_LS, K.CITY_LV, K.CITY_SF } or { false }
                for _, city in ipairs(cities) do
                    local name = (city and city:lower() or "") .. short .. n
                    sampRegisterChatCommand(name, function()
                        if city then State.sicCity = city end
                        sendTestButton(test, test.buttons[n], n)
                    end)
                end
            end
        end
    end
    -- /ccc: curata chatul (30 de linii goale), ca la AdeM
    sampRegisterChatCommand("ccc", function() for _ = 1, 30 do chat("") end end)
    -- scurtaturile generale ale lui AdeM (optionale, Features -> "Comenzi scurte generale"); se aplica la Ctrl+R
    if feat("shortsOn") then
        local shorts = {
            m = "/members", cm = "/clanmembers", missm = "/missed messages", missc = "/missed calls",
            sv = "/servicecalls", sj = "/switchjob", lpb = "/leavepaintball", rev = "/requestevent",
            ha = "/heal", sa = "/stopanim", sc = "/spawnchange", qh = "/questhelp", ma = "/maraton", ra = "/raport",
        }
        for name, command in pairs(shorts) do
            sampRegisterChatCommand(name, function() Queue.push(command) end)
        end
        sampRegisterChatCommand("cf", function() Queue.push("/cancel find") Queue.push("/killcp") end)
        sampRegisterChatCommand("gk", function(arg) local id = idOrCandidate(arg) if id then Queue.push("/givekey " .. id) end end)
    end
    -- statia PD (/pdc) si scurtaturile din PDHelper; la alte factiuni scurtaturile pleaca neschimbate la server
    if App.PD then App.PD.register(sampRegisterChatCommand, { sl = true }) end
end

-- ============================================================
-- MAIN
-- ============================================================
function main()
    while not isSampAvailable() do wait(0) end

    if Custom.count() == 0 then
        Custom.add()
    end

    registerCommands()
    saveCfg()

    trace("start v" .. VERSION)
    -- o linie si in moonloader.log: se vede ce versiune ruleaza si daca s-a incarcat partea PD
    print("SICHelper " .. VERSION .. (App.PD and (" + modul PD (" .. App.PD.command() .. ", /pdh)")
          or (" - modul PD neincarcat: " .. tostring(App.PDError))))
    if App.PD and App.PD.isDept() then
        msg("SICHelper " .. VERSION .. " incarcat. " .. COLOR.CMD .. App.PD.command() .. COLOR.TEXT .. " statia PD, "
            .. COLOR.CMD .. "/pdh" .. COLOR.TEXT .. " setari.")
    else
        msg("SICHelper " .. VERSION .. " incarcat. " .. COLOR.CMD .. "/sic" .. COLOR.TEXT .. " teste, "
            .. COLOR.CMD .. "/sih" .. COLOR.TEXT .. " setari.")
    end
    if dataError then err(tr("data_missing", dataError)) end
    if App.PDError then err(tr("pd_missing", App.PDError)) end
    if App.PD and App.PD.dataError then err(App.PD.t("data_error", App.PD.dataError)) end
    applyPagesize()
    Shots.init()
    Report.load()
    Notes.load()
    App.Info.loadPlayers()
    App.Ver.check()
    App.Wizard.start()

    local lastPosSave = 0
    while true do
        wait(0)
        -- fara ferestre deschise nu poate exista camp de text cu focus
        if not State.sih[0] and not Prompt.open[0] and not State.sic[0] and not State.notes[0]
           and not App.Info.open[0] and not App.Wizard.open[0] and not (App.PD and App.PD.open[0]) then State.textInput = false end
        -- in pcall: la reincarcarea altor scripturi, apelul poate cadea cu "cannot resume non-suspended coroutine"
        if type(isGameWindowForeground) == "function" then
            local okFg, fg = pcall(isGameWindowForeground)
            if okFg then State.focused = fg end
        end
        uiScaleUpdate()
        Defer.run()
        Keys.update()

        -- dialogurile serverului, citite direct (hook-ul RPC nu le prinde pe acest server)
        if sampIsDialogActive() then
            if not State.dialogSeen then
                State.dialogSeen = true
                local title, text = sampGetDialogCaption(), sampGetDialogText()
                trace("dialog(poll): " .. tostring(title))
                if title and text then
                    Candidate.parseLicenseDialog(title, text)
                    if Report.parse(title, text) and feat("reportWindow") then
                        -- butonul 1 = "Close" (stanga); cu 0 serverul retrimite dialogul la fiecare secunda
                        sampCloseCurrentDialogWithButton(1)
                        Report.open[0] = true
                    end
                end
            end
        else
            State.dialogSeen = false
        end
        Queue.update()
        Withme.update()
        Give.update()
        Sms.update()
        Need.flush()
        Need.update()
        RR.update()
        Notify.update()
        App.Ver.update()
        -- fontul de iconite din modpack e mai vechi decat cel din arhiva: o singura atentionare
        if State.fontOld and not State.fontWarned then
            State.fontWarned = true
            err(tr("font_old"))
        end
        Vehicle.update()
        Shots.update()
        FVR.update()
        if App.PD then
            local okPd, errPd = pcall(App.PD.update)
            if not okPd and App.PDLastError ~= tostring(errPd) then
                App.PDLastError = tostring(errPd)
                trace("pd update: " .. App.PDLastError)
            end
        end

        -- pozitia ferestrei /sic se salveaza rar, nu la fiecare pixel
        if State.sicPosDirty and os.clock() - lastPosSave > 2 then
            State.sicPosDirty = false
            lastPosSave = os.clock()
            saveCfg()
        end
    end
end
