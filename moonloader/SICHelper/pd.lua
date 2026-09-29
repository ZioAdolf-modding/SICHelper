-- ============================================================
-- SICHelper - modulul pentru departamente (Police Department / FBI / National Guard)
-- Copyright (C) 2026 ZioAdolf (Discord: vlandrewz)
--
-- Programul e liber: il poti redistribui si/sau modifica in termenii licentei
-- GNU General Public License, versiunea 3 sau (la alegerea ta) oricare versiune
-- ulterioara, publicata de Free Software Foundation. Vine FARA NICIO GARANTIE.
-- Vezi fisierul LICENSE sau <https://www.gnu.org/licenses/>.
--
-- Statia de control (/pdc): identifici suspectul (radar, ID, cel mai apropiat jucator), helperul
-- afla nivelul lui cu /id, iar fiecare buton trimite comenzile unei singure actiuni, potrivite
-- nivelului si regulamentului (config/SICHelper_pd.lua).
-- Nimic nu pleaca fara un click sau o tasta: nu exista arest, frisk sau cuff automat.
-- Comenzile scurte si randurile din dialogurile /ticket si /su vin din PDHelper V7.5 by TheTom.
--
-- E un fisier separat de SICHelper.lua: scriptul principal e aproape de limita de 200 de variabile
-- locale a Lua. Primeste de la el (ctx) tot ce are nevoie si intoarce tabela PD.
-- ============================================================

return function(ctx)

local imgui, u8, new, ffi, bit, fa = ctx.imgui, ctx.u8, ctx.new, ctx.ffi, ctx.bit, ctx.fa
local cfg, Queue = ctx.cfg, ctx.Queue
local C = ctx.colors
local TC, TW, TIP, px = ctx.TC, ctx.TW, ctx.TIP, ctx.px

local PD = {
    open    = new.bool(false),
    fade    = ctx.Fade.new(),
    tab     = 1,
    sus     = nil,     -- suspectul: { id, name }
    people  = {},      -- dupa nume: { som = { n, first, last }, friskAt, wanted }
    info    = {},      -- dupa id: { name, level, faction, rank } din /id
    radar   = { list = {}, stage = "off", fresh = nil, asks = { n = 0, last = 0 }, permit = { n = 0, first = 0, last = 0 } },
    patrol  = {},      -- dupa oras: { n, last }
    idBuf   = new.char[8](),
    zoneBuf = new.char[64](),
    lastSaid = nil,
}

-- ------------------------------------------------------------
-- DATELE (config/SICHelper_pd.lua)
-- ------------------------------------------------------------
PD.file = getWorkingDirectory() .. "\\config\\SICHelper_pd.lua"
do
    local ok, res = pcall(dofile, PD.file)
    if ok and type(res) == "table" then
        PD.D = res
    else
        PD.D = {}
        PD.dataError = tostring(res)
    end
end
local D = PD.D
D.cmd = D.cmd or {}
D.say = D.say or {}
D.radar = D.radar or {}
D.radar.say = D.radar.say or {}
D.speed = D.speed or {}
D.ticket = D.ticket or {}

PD.offById, PD.offByShort, PD.suById, PD.suByShort = {}, {}, {}, {}
for _, o in ipairs(D.offences or {}) do
    PD.offById[o.id] = o
    if o.shortcut then PD.offByShort[o.shortcut] = o end
end
for _, e in ipairs(D.su or {}) do
    PD.suById[e.id] = e
    if e.shortcut then PD.suByShort[e.shortcut] = e end
end

-- setarile tale (sectiunea [pd] din SIC_Helper.ini)
cfg.pd = cfg.pd or {}
cfg.pd.zone  = tostring(cfg.pd.zone or "")
cfg.pd.limit = tonumber(cfg.pd.limit) or 100
cfg.pd.city  = tostring(cfg.pd.city or "")
cfg.pd.pick  = tostring(cfg.pd.pick or "")
imgui.StrCopy(PD.zoneBuf, cfg.pd.zone)

-- ------------------------------------------------------------
-- TEXTE INTERFATA (ro / en)
-- ------------------------------------------------------------
local L = {
    ro = {
        window = "Statie PD", tab_road = "Rutier", tab_wanted = "Wanted", tab_control = "Control",
        tab_radar = "Radar", tab_disp = "Dispecerat",
        suspect = "SUSPECT", no_suspect = "Nu ai niciun suspect: alege-l din radar, dupa ID sau cel mai apropiat.",
        no_suspect_short = "fara suspect", near_tip = "Cel mai apropiat jucator devine suspectul.",
        nearby_tip = "Jucatorii din jurul tau (cel mai apropiat primul).", near_none = "Nimeni in jurul tau.",
        info_tip = "Deschide /info pe suspect (nivel, factiune, notitele tale).", clear_tip = "Renunta la suspect.",
        settings_tip = "Setarile helperului (/sih).", lang_tip = "Limba textelor spuse suspectului (RO / EN).",
        level = "Lv",
        br_warn = "1-%d: doar avertisment", br_choose = "%d-%d: alege amenda / permis", br_full = "%d+: amenda + permis",
        br_unknown = "nivel necunoscut - astept /id",
        dist = "%d m", far = "nu e langa tine", in_veh = "in %s",
        som_chip = "somatii %d/3", som_ago = "ultima acum %s", frisk_chip = "frisk acum %s", frisk_none = "fara frisk",
        radar_chip = "radar %d/%d (+%d)", cuffed = "cu catuse",
        choice_q = "%s alege:", choice_fine = "Amenda", choice_lic = "Permis %s", choice_seize = "Confiscare",
        choice_tip = "Trimite varianta aleasa de jucator.", choice_wait = "Astept raspunsul lui %s: alege din statie (Amenda / Permis).",
        suggest = "Propus: %s pentru %s", suggest_send = "Trimite", suggest_tip = "Deschide /su si alege motivul (nimic nu pleaca singur).",
        dismiss = "Renunta",
        speed_radar = "Viteza  %d/%d km/h (+%d)", speed_title = "VITEZA", road_title = "ABATERI RUTIERE",
        wanted_title = "WANTED (/su)", control_title = "CONTROL", contraband_title = "DUPA /FRISK",
        custody_title = "CUSTODIE", radar_title = "RADAR", list_title = "PRINSI DE RADAR",
        rules_title = "REGULAMENT (rezumat)",
        act_warn = "avertisment", act_fine = "amenda", act_lic = "permis %s", ["act_fine+lic"] = "amenda + permis %s",
        ["act_fine|lic"] = "alege: amenda / permis %s", act_seize = "confiscare", ["act_seize+fine"] = "confiscare + amenda",
        ["act_fine|seize"] = "alege: amenda / confiscare", act_level = "dupa nivel (/id)",
        preview = "Trimite:", preview_choice = "apoi alegi din statie:",
        level_wait = "Aflu nivelul lui %s (/id)...", level_timeout = "Nu am primit nivelul de la /id: sanctiunea NU a fost trimisa.",
        not_online = "Nu exista un jucator online cu id-ul %s.", sus_left = "Suspectul %s a iesit (sau id-ul e acum al altcuiva).",
        under_tol = "%d km/h la limita de %d: sub pragul de sanctionare (1-2 km/h peste limita nu se sanctioneaza).",
        no_radar_entry = "Nu am pe nimeni prins de radar.", not_in_list = "Jucatorul %s nu e printre cei prinsi de radar.",
        somatie = "Somatie", somatie_tip = "Pe /m: \"%s\"\nNumara somatiile (regulament: 3 in maxim 5 minute, apoi 30 s).",
        ms = "/ms", ms_tip = "Somatia serverului, pe jucatorul pe care ai /find (se numara la suspect).",
        som_count = "Somatia %d/3 pentru %s.", som_need = "Regulament: sunt necesare 3 somatii (ai %d).",
        som_window = "Regulament: cele 3 somatii trebuie sa fie in maxim 5 minute.",
        som_wait = "Regulament: mai asteapta %d s dupa ultima somatie.",
        frisk_need = "Regulament: drogurile se sanctioneaza doar cu dovada din /frisk (nu ai dat /frisk suspectului).",
        click_again = "Apasa din nou in 4 s ca sa trimiti oricum.", override = "Confirmat: trimis la cererea ta.",
        control = "Control de rutina", control_tip = "Spune: \"%s\"\napoi /frisk.\nControalele de rutina se fac doar cu masina departamentului.",
        reqlic = "Licente (/requestlicenses)", cuff = "Cuff", uncuff = "Uncuff", arrest = "Arrest", eject = "Eject",
        arrest_here = "Esti in zona de arrest (%s).", arrest_tip = "Trimite /arrest (nu aresteaza nimic singur).",
        find = "Find", cancelfind = "Cancel find", tazer = "Tazer", wanted_list = "/wanted", nearwanted = "/nearwanted",
        wanted_lvl = "Wanted:", custody = "Anunta custodia pe /d",
        gov = "Teren guvernamental", gov_tip = "Avertisment verbal: iesi de pe terenul guvernamental.",
        nefondat = "Nefondat pe /d", nefondat_tip = "Anunta pe /d: \"%s\". Apoi motivul \"Apel nefondat\" daca ai fost primul.",
        zone = "Zona", here = "Aici", here_tip = "Zona si orasul in care esti acum.", limit = "Limita", city = "Oras",
        own_city = "orasul tau", ask_free = "Zona libera? %d/%d", ask_free_tip = "Pe /d: \"%s\"\nRegulament: de 3 ori, la minim 10 s.",
        ask_wait = "Mai asteapta %d s intre intrebari (regulament: minim 10 s).", asked_done = "Ai intrebat de %d ori; poti porni radarul.",
        permit = "Acord %sPD %d/%d", permit_tip = "Pe /d: \"%s\"\nFara raspuns: poti pune radarul dupa 1 minut. Refuzat: astepti 5 minute.",
        permit_ago = "prima cerere acum %s", permit_ok = "a trecut 1 minut: poti pune radarul",
        radar_start = "Porneste radarul", radar_stop = "Opreste radarul", radar_stopfind = "Opreste + /find pe %s",
        radar_resume = "Reia radarul", radar_stop_only = "Doar stop", radar_toggle_tip = "Acelasi lucru face tasta Radar din /sih -> Bind-uri.",
        radar_moving = "Opreste masina si parcheaza regulamentar inainte de radar (regulament).",
        radar_not_asked = "Regulament: intreaba de 3 ori pe /d daca zona e libera (ai intrebat de %d ori).",
        radar_no_permit = "Regulament: radarul e in alt oras, cere acordul (/d) inainte.",
        radar_no_zone = "Scrie zona radarului (sau apasa Aici).",
        radar_caught = "Radar: %s, nivel %d, %d/%d km/h (+%d) -> %s.",
        radar_caught_short = "%d/%d km/h (+%d)", radar_state_on = "pornit", radar_state_off = "oprit", radar_state_stopped = "oprit (suspect)",
        pick = "Alege", sanction = "Sanctioneaza", ago_s = "%ds", ago_m = "%dm", list_empty = "Nimeni prins inca.",
        duty = "Duty (/pin /duty /heal)", fvr = "FVR (/r, /d)", patrol = "Patrulare %s %d/%d", patrol_tip = "Pe /d: \"%s\"",
        afk3 = "AFK suspect: 3 min", afk3_tip = "Pe /d: \"%s\", apoi numara 3 minute.", afk30 = "Numara 30 s",
        afk30_tip = "Pentru jucatorii AFK fara clepsidra.", timer_stop = "Stop", timer = "%s: %s",
        timer_done = "Au trecut %s (%s).", timer_afk = "AFK %s", timer_30 = "30 s",
        pick_title = "Dialogurile /ticket si /su", pick_press = "Alege si apasa", pick_select = "Doar selecteaza",
        pick_off = "Nu atinge", pick_tip = "Dupa /ticket sau /su helperul cauta randul potrivit in dialogul serverului.\nAlege si apasa: il alege si apasa butonul. Doar selecteaza: tu apesi Enter. Nu atinge: alegi tu.",
        dlg_pressed = "Ales in dialog: %s", dlg_selected = "Am selectat in dialog: %s - apasa Enter daca e bun.",
        dlg_check = "Randul nu a putut fi confirmat dupa text: am selectat \"%s\" - verifica si apasa Enter.",
        dlg_yourself = "Nu am gasit randul pentru \"%s\" in dialog: alege-l tu.", dlg_manual = "Alege tu randul pentru \"%s\" in dialog.",
        dlg_none = "Dialogul pentru \"%s\" nu a aparut.", dlg_fail = "Nu am putut selecta randul pentru \"%s\": alege-l tu.",
        data_file = "Datele (texte, comenzi, praguri): %s", data_error = "Fisierul de date PD lipseste sau are o eroare: %s",
        reload_hint = "Dupa ce il modifici: Ctrl+R.",
        cmds_title = "COMENZI SCURTE (ca in PDHelper)", gate = "Poarta: %s",
        no_gate = "Nu esti langa nicio poarta cunoscuta.", nothing = "nimic trimis inca",
        shot_tip = "Screenshot (F8), cu numele suspectului in fisier.",
        -- ghidul din /sih
        g_pdc = "statia PD: suspect, sanctiuni, wanted, control, radar, dispecerat", g_pdh = "setarile (acelasi lucru ca /sih)",
        g_san = "deschide statia pe jucator", g_sl = "sanctioneaza viteza ultimului prins de radar (sau a unuia din lista)", g_speed = "viteza, manual: sub 50 / peste 50 / peste 100",
        g_road = "abaterile rutiere", g_frisk = "arme, droguri, materiale", g_su = "wanted: neconformare, runner, atac, droguri, neplata, complice, nefondat",
        g_mm = "somatie / control de rutina / teren guvernamental", g_radar = "radar: zona libera? / acord LS-LV-SF / patrulare in alt oras",
        g_afk = "AFK: cu id anunta pe /d si numara 3 minute; fara id 30 s", g_duty = "duty (/pin /duty /heal) / doar /pin /duty",
        g_sto = "opreste / porneste radarul", g_nef = "nefondat pe /d",
        g_note = "Fara id: suspectul din statie. Nivelul se afla singur (/id) si decide sanctiunea.",
    },
    en = {
        window = "PD station", tab_road = "Traffic", tab_wanted = "Wanted", tab_control = "Search",
        tab_radar = "Radar", tab_disp = "Dispatch",
        suspect = "SUSPECT", no_suspect = "No suspect: pick one from the radar, by ID or the nearest player.",
        no_suspect_short = "no suspect", near_tip = "The nearest player becomes the suspect.",
        nearby_tip = "Players around you (nearest first).", near_none = "Nobody around you.",
        info_tip = "Opens /info on the suspect (level, faction, your notes).", clear_tip = "Drop the suspect.",
        settings_tip = "Helper settings (/sih).", lang_tip = "Language of what you say to the suspect (RO / EN).",
        level = "Lv",
        br_warn = "1-%d: warning only", br_choose = "%d-%d: ticket or license", br_full = "%d+: ticket + license",
        br_unknown = "level unknown - waiting for /id",
        dist = "%d m", far = "not next to you", in_veh = "in a %s",
        som_chip = "summons %d/3", som_ago = "last %s ago", frisk_chip = "frisked %s ago", frisk_none = "not frisked",
        radar_chip = "radar %d/%d (+%d)", cuffed = "cuffed",
        choice_q = "%s chooses:", choice_fine = "Ticket", choice_lic = "License %s", choice_seize = "Confiscate",
        choice_tip = "Sends the option the player chose.", choice_wait = "Waiting for %s to answer: pick in the station (Ticket / License).",
        suggest = "Suggested: %s for %s", suggest_send = "Send", suggest_tip = "Opens /su and picks the reason (nothing goes by itself).",
        dismiss = "Dismiss",
        speed_radar = "Speed  %d/%d km/h (+%d)", speed_title = "SPEED", road_title = "TRAFFIC OFFENCES",
        wanted_title = "WANTED (/su)", control_title = "SEARCH", contraband_title = "AFTER /FRISK",
        custody_title = "CUSTODY", radar_title = "RADAR", list_title = "CAUGHT BY THE RADAR",
        rules_title = "RULES (summary)",
        act_warn = "warning", act_fine = "ticket", act_lic = "license %s", ["act_fine+lic"] = "ticket + license %s",
        ["act_fine|lic"] = "choice: ticket / license %s", act_seize = "confiscate", ["act_seize+fine"] = "confiscate + ticket",
        ["act_fine|seize"] = "choice: ticket / confiscate", act_level = "by level (/id)",
        preview = "Sends:", preview_choice = "then you pick in the station:",
        level_wait = "Getting %s's level (/id)...", level_timeout = "No level from /id: the sanction was NOT sent.",
        not_online = "There is no online player with id %s.", sus_left = "The suspect %s left (or the id belongs to someone else now).",
        under_tol = "%d km/h with a %d limit: below the sanction threshold (1-2 km/h over is not sanctioned).",
        no_radar_entry = "Nobody caught by the radar yet.", not_in_list = "Player %s is not among those caught by the radar.",
        somatie = "Summon", somatie_tip = "On /m: \"%s\"\nCounts the summons (rules: 3 within 5 minutes, then 30 s).",
        ms = "/ms", ms_tip = "The server summon, on the player you /find (counted for the suspect).",
        som_count = "Summon %d/3 for %s.", som_need = "Rules: 3 summons are needed (you have %d).",
        som_window = "Rules: the 3 summons must be within 5 minutes.",
        som_wait = "Rules: wait %d more s after the last summon.",
        frisk_need = "Rules: drugs are sanctioned only with evidence from /frisk (you did not frisk the suspect).",
        click_again = "Click again within 4 s to send anyway.", override = "Confirmed: sent on your request.",
        control = "Routine check", control_tip = "Says: \"%s\"\nthen /frisk.\nRoutine checks only with a department vehicle.",
        reqlic = "Licenses (/requestlicenses)", cuff = "Cuff", uncuff = "Uncuff", arrest = "Arrest", eject = "Eject",
        arrest_here = "You are in an arrest zone (%s).", arrest_tip = "Sends /arrest (nothing is arrested by itself).",
        find = "Find", cancelfind = "Cancel find", tazer = "Tazer", wanted_list = "/wanted", nearwanted = "/nearwanted",
        wanted_lvl = "Wanted:", custody = "Announce custody on /d",
        gov = "Governmental area", gov_tip = "Verbal warning: leave the governmental area.",
        nefondat = "Unfounded on /d", nefondat_tip = "Announces on /d: \"%s\". Then the \"Unfounded call\" reason if you were first.",
        zone = "Zone", here = "Here", here_tip = "The zone and city you are in now.", limit = "Limit", city = "City",
        own_city = "your city", ask_free = "Zone free? %d/%d", ask_free_tip = "On /d: \"%s\"\nRules: 3 times, at least 10 s apart.",
        ask_wait = "Wait %d more s between questions (rules: at least 10 s).", asked_done = "You asked %d times; you can start the radar.",
        permit = "Approval %sPD %d/%d", permit_tip = "On /d: \"%s\"\nNo answer: you may set the radar after 1 minute. Refused: wait 5 minutes.",
        permit_ago = "first request %s ago", permit_ok = "1 minute passed: you may set the radar",
        radar_start = "Start the radar", radar_stop = "Stop the radar", radar_stopfind = "Stop + /find on %s",
        radar_resume = "Resume the radar", radar_stop_only = "Stop only", radar_toggle_tip = "The Radar key in /sih -> Binds does the same.",
        radar_moving = "Stop the car and park properly before the radar (rules).",
        radar_not_asked = "Rules: ask 3 times on /d whether the zone is free (you asked %d times).",
        radar_no_permit = "Rules: the radar is in another city, ask for approval (/d) first.",
        radar_no_zone = "Type the radar zone (or press Here).",
        radar_caught = "Radar: %s, level %d, %d/%d km/h (+%d) -> %s.",
        radar_caught_short = "%d/%d km/h (+%d)", radar_state_on = "on", radar_state_off = "off", radar_state_stopped = "off (suspect)",
        pick = "Pick", sanction = "Sanction", ago_s = "%ds", ago_m = "%dm", list_empty = "Nobody caught yet.",
        duty = "Duty (/pin /duty /heal)", fvr = "FVR (/r, /d)", patrol = "Patrol %s %d/%d", patrol_tip = "On /d: \"%s\"",
        afk3 = "AFK suspect: 3 min", afk3_tip = "On /d: \"%s\", then counts 3 minutes.", afk30 = "Count 30 s",
        afk30_tip = "For AFK players without the hourglass.", timer_stop = "Stop", timer = "%s: %s",
        timer_done = "%s passed (%s).", timer_afk = "AFK %s", timer_30 = "30 s",
        pick_title = "The /ticket and /su dialogs", pick_press = "Pick and press", pick_select = "Select only",
        pick_off = "Don't touch", pick_tip = "After /ticket or /su the helper looks for the right line in the server dialog.\nPick and press: selects it and presses the button. Select only: you press Enter. Don't touch: you pick.",
        dlg_pressed = "Picked in the dialog: %s", dlg_selected = "Selected in the dialog: %s - press Enter if it is right.",
        dlg_check = "The line could not be confirmed by its text: selected \"%s\" - check it and press Enter.",
        dlg_yourself = "Could not find the line for \"%s\" in the dialog: pick it yourself.", dlg_manual = "Pick the line for \"%s\" in the dialog yourself.",
        dlg_none = "The dialog for \"%s\" did not show up.", dlg_fail = "Could not select the line for \"%s\": pick it yourself.",
        data_file = "Data (texts, commands, thresholds): %s", data_error = "The PD data file is missing or has an error: %s",
        reload_hint = "After editing it: Ctrl+R.",
        cmds_title = "SHORT COMMANDS (as in PDHelper)", gate = "Gate: %s",
        no_gate = "You are not next to a known gate.", nothing = "nothing sent yet",
        shot_tip = "Screenshot (F8), with the suspect name in the file.",
        g_pdc = "the PD station: suspect, sanctions, wanted, search, radar, dispatch", g_pdh = "settings (same as /sih)",
        g_san = "opens the station on a player", g_sl = "speed sanction for the last one caught by the radar (or one from the list)", g_speed = "speed, manual: under 50 / over 50 / over 100",
        g_road = "traffic offences", g_frisk = "weapons, drugs, materials", g_su = "wanted: disobeying, runner, attack, drugs, unpaid, accomplice, unfounded",
        g_mm = "summon / routine check / governmental area", g_radar = "radar: zone free? / approval LS-LV-SF / patrol in another city",
        g_afk = "AFK: with id announces on /d and counts 3 minutes; without id 30 s", g_duty = "duty (/pin /duty /heal) / just /pin /duty",
        g_sto = "stop / start the radar", g_nef = "unfounded on /d",
        g_note = "No id: the suspect from the station. The level is fetched by itself (/id) and decides the sanction.",
    },
}

local function t(key, ...)
    local pack = L[cfg.main.uiLang] or L.ro
    local s = pack[key] or L.ro[key] or key
    if select("#", ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        return ok and out or s
    end
    return s
end
PD.t = t

-- ------------------------------------------------------------
-- AJUTOARE
-- ------------------------------------------------------------
-- un text din fisierul de date: sir simplu sau { ro = ..., en = ... }
local function pick(v, lang)
    if type(v) ~= "table" then return v end
    local r = v[lang or cfg.main.procLang] or v.ro or v.en
    if r == nil then return v end    -- o lista simpla, fara ro / en
    return r
end
-- {name}, {id}... inlocuite; ce nu e cunoscut (inclusiv codurile de culoare) ramane cum e
local function fill(s, vars)
    if type(s) ~= "string" then return "" end
    return (s:gsub("{(%w+)}", function(k)
        local v = vars and vars[k]
        if v == nil then return nil end
        return tostring(v)
    end))
end
PD.fill, PD.pick = fill, pick

local function icon(name)
    if not ctx.State.icons then return "" end
    local g = fa[name]
    return (g and g ~= "") and (g .. " ") or ""
end

local function theme() return ctx.theme() end

local function plain(text) return (tostring(text or ""):gsub("{%x%x%x%x%x%x}", "")) end

local function escapePattern(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- un cuvant cheie la inceput de cuvant, fara litere mari / mici
local function hasWord(line, list)
    local low = tostring(line or ""):lower()
    for _, n in ipairs(list or {}) do
        if low:find("%f[%w]" .. escapePattern(tostring(n):lower())) then return true end
    end
    return false
end
PD.hasWord = hasWord

-- "45s" / "3m"
local function ago(sec)
    sec = math.max(0, math.floor(sec))
    if sec < 60 then return t("ago_s", sec) end
    return t("ago_m", math.floor(sec / 60))
end
local function clock(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

function PD.isDept(fid)
    fid = fid or cfg.main.factionId
    for _, f in ipairs(D.factions or { "pd", "fbi", "ng" }) do
        if f == fid then return true end
    end
    return false
end

function PD.command() return "/" .. tostring((D.commands or { "pdc" })[1] or "pdc") end

function PD.langOf(id) return ctx.Langs.use(id) end

function PD.hoursText(n, lang)
    local set = (D.hours or {})[lang or cfg.main.procLang] or (D.hours or {}).ro or {}
    return fill(set[n] or set.other or "{n}h", { n = n })
end

function PD.person(id)
    local name = ctx.playerName(id)
    if not name then return nil end
    PD.people[name] = PD.people[name] or {}
    return PD.people[name]
end

function PD.level(id)
    if not id then return nil end
    local lvl = ctx.playerLevel(id)
    if lvl then return lvl end
    local d = ctx.App.Info.byId[id]
    if d and d.level and d.name and d.name == ctx.playerName(id) then return d.level end
    return nil
end

-- un text spus in chat (sau pe /d, /m); acelasi text de doua ori la rand se schimba putin,
-- ca serverul sa nu-l ia drept spam
function PD.say(text)
    if not text or text == "" then return end
    if text == PD.lastSaid then
        if text:sub(-1) == "." or text:sub(-1) == "!" then text = text:sub(1, -2) else text = text .. "." end
    end
    PD.lastSaid = text
    Queue.push(text)
end

function PD.queued(text)
    for _, item in ipairs(Queue.items) do
        if item.text == text then return true end
    end
    return false
end

-- ------------------------------------------------------------
-- SUSPECTUL
-- ------------------------------------------------------------
function PD.setSuspect(id, silent)
    id = tonumber(id)
    if not id or not ctx.idOnline(id) then
        if not silent then ctx.err(t("not_online", tostring(id or "?"))) end
        return false
    end
    local name = ctx.playerName(id) or "?"
    local same = PD.sus and PD.sus.id == id and PD.sus.name == name
    PD.sus = { id = id, name = name }
    imgui.StrCopy(PD.idBuf, tostring(id))
    PD.idShown = id
    if not same then
        if PD.suggest and PD.suggest.id ~= id then PD.suggest = nil end
        -- nivelul se afla singur, putin dupa alegere (ca sa nu trimitem /id pentru fiecare ID trecut)
        if not PD.level(id) then PD.identFor, PD.identAt = id, os.clock() + 0.7 end
    end
    return true
end

-- suspectul curent, daca inca e acelasi jucator
function PD.susId()
    local s = PD.sus
    if not s then return nil end
    if not ctx.idOnline(s.id) or ctx.playerName(s.id) ~= s.name then
        ctx.err(t("sus_left", s.name))
        PD.sus = nil
        return nil
    end
    return s.id
end

-- tinta unei actiuni: id-ul dat (devine suspectul) sau suspectul curent
function PD.target(id)
    id = tonumber(id)
    if id then
        if PD.setSuspect(id) then return id end
        return nil
    end
    local cur = PD.susId()
    if not cur then ctx.err(t("no_suspect")) end
    return cur
end

-- /id pentru nivel (raspunsul ramane in chat: e si dovada nivelului)
function PD.ask(id)
    PD.idWait = { id = id, at = os.clock() }
    Queue.pushFront(fill(D.cmd.id or "/id {id}", { id = id }))
    ctx.trace("pd: /id " .. tostring(id))
end

-- fn(nivel) acum, daca il stim; altfel dupa raspunsul la /id
function PD.withLevel(id, fn)
    local lvl = PD.level(id)
    if lvl then return fn(lvl) end
    PD.pending = { id = id, fn = fn, at = os.clock() }
    PD.ask(id)
    ctx.msg(t("level_wait", ctx.nameTag(id, ctx.playerName(id))))
end

-- raspunsul la /id (orice raspuns, nu doar al nostru): retinem nivelul si factiunea
function PD.onIdLine(text)
    if not text:find("Ping:", 1, true) then return end
    local d = ctx.App.Info.parse(text)
    if not d or not d.level then return end
    local w = PD.idWait
    local id = d.id
    if not id and w and d.name and d.name == ctx.playerName(w.id) then id = w.id end
    if not id then return end
    if w and w.id == id then PD.idWait = nil end
    ctx.rememberLevel(id, d.level)
    PD.info[id] = { name = d.name or ctx.playerName(id), level = d.level, faction = d.faction, rank = d.rank }
    local p = PD.pending
    if p and p.id == id then
        PD.pending = nil
        local ok, e = pcall(p.fn, d.level)
        if not ok then ctx.trace("pd: eroare dupa /id: " .. tostring(e)) end
    end
end

-- ------------------------------------------------------------
-- REGULILE: ce se intampla dupa nivel
-- ------------------------------------------------------------
function PD.actFor(rule, level)
    local list = (D.brackets or {})[rule]
    if type(list) ~= "table" then return nil end
    for _, b in ipairs(list) do
        if not b.max or (level and level <= b.max) then return b.act end
    end
    return nil
end

-- regula depinde de nivel? (un singur rand fara "max" = nu)
function PD.needsLevel(rule)
    local list = (D.brackets or {})[rule]
    return not (type(list) == "table" and #list == 1 and not list[1].max)
end

-- eticheta scurta a unei decizii ("amenda + permis o ora")
function PD.actLabel(act, hours, lang)
    if not act then return t("act_level") end
    return t("act_" .. act, PD.hoursText(hours or 1, lang))
end

-- insigna de langa nivel
function PD.bracket(level)
    local lv = D.levels or {}
    local w, c = tonumber(lv.warn_max) or 3, tonumber(lv.choose_max) or 7
    if not level then return t("br_unknown"), C.DIM end
    if level <= w then return t("br_warn", w), C.AMBER end
    if level <= c then return t("br_choose", w + 1, c), C.BLUE end
    return t("br_full", c + 1), C.RED
end

-- ------------------------------------------------------------
-- PLANUL UNEI SANCTIUNI: ce se spune si ce comenzi pleaca (aceeasi functie si pentru previzualizare)
-- spec: { rule, hours, ticket, item, say, outcome, vars, label, then_su }
-- ------------------------------------------------------------
function PD.vars(id, spec, level, lang)
    local v = { name = ctx.playerName(id) or "?", id = id, level = level or "?",
                hours = PD.hoursText(spec.hours or 1, lang), zone = cfg.pd.zone, limit = cfg.pd.limit }
    for k, val in pairs(spec.vars or {}) do v[k] = val end
    return v
end

function PD.plan(id, spec, level)
    local lang = PD.langOf(id)
    local act = PD.actFor(spec.rule, level)
    local vars = PD.vars(id, spec, level, lang)
    local out = { act = act, say = {}, cmds = {}, vars = vars, lang = lang }
    if not act then return out end
    local first = fill(pick(spec.say, lang), vars)
    if first ~= "" then table.insert(out.say, first) end
    local o = (spec.outcome and spec.outcome[act]) or (D.outcome or {})[act]
    if o then
        local line = fill(pick(o, lang), vars)
        if line ~= "" then table.insert(out.say, line) end
    end
    if act:find("|", 1, true) then
        out.choice = {}
        for opt in act:gmatch("[^|]+") do table.insert(out.choice, opt) end
    else
        out.cmds = PD.cmdsFor(id, act, spec)
    end
    return out
end

-- comenzile unei decizii; /ticket ultimul, pentru ca deschide un dialog
function PD.cmdsFor(id, act, spec)
    local has = {}
    for tok in tostring(act):gmatch("[^+|]+") do has[tok] = true end
    local list = {}
    if has.seize and spec.item then
        table.insert(list, { text = fill(D.cmd.seize or "/confiscate {id} {item}", { id = id, item = spec.item }) })
    end
    if has.lic then
        table.insert(list, { text = fill(D.cmd.license or "/confiscate {id} drivinglic {n}", { id = id, n = spec.hours or 1 }) })
    end
    if has.fine then
        table.insert(list, { text = fill(D.cmd.ticket or "/ticket {id}", { id = id }), dialog = "ticket",
                             entry = (D.ticket.lines or {})[spec.ticket] or {} })
    end
    return list
end

function PD.runCmds(list, label)
    for _, c in ipairs(list) do
        Queue.push(c.text)
        if c.dialog then PD.expectDialog(c.dialog, c.entry, label, c.text) end
    end
end

-- aplica sanctiunea (dupa ce nivelul e cunoscut, daca e nevoie)
function PD.execute(id, spec, level)
    local plan = PD.plan(id, spec, level)
    if not plan.act then ctx.err("rule? " .. tostring(spec.rule)) return end
    for _, line in ipairs(plan.say) do PD.say(line) end
    local name = ctx.playerName(id) or "?"
    if plan.choice then
        PD.choice = { id = id, name = name, opts = plan.choice, spec = spec, lang = plan.lang, vars = plan.vars, at = os.time() }
        ctx.msg(t("choice_wait", name))
        PD.open[0] = true
    else
        PD.runCmds(plan.cmds, spec.label)
    end
    if spec.then_su and PD.suById[spec.then_su] then
        PD.suggest = { id = id, name = name, su = spec.then_su }
    end
    PD.lastAction = spec.label
    ctx.trace("pd: sanctiune " .. tostring(spec.label) .. " -> " .. tostring(id) .. " nivel " .. tostring(level) .. " = " .. plan.act)
end

-- jucatorul a ales (Amenda / Permis / Confiscare)
function PD.resolve(opt)
    local c = PD.choice
    if not c then return end
    PD.choice = nil
    if not ctx.idOnline(c.id) or ctx.playerName(c.id) ~= c.name then ctx.err(t("sus_left", c.name)) return end
    local line = (D.picked or {})[opt]
    if line then PD.say(fill(pick(line, c.lang), c.vars)) end
    PD.runCmds(PD.cmdsFor(c.id, opt, c.spec), c.spec.label)
end

-- o previzualizare pentru tooltip: liniile care ar pleca acum
function PD.previewTip(id, spec)
    if not id then return end
    local level = PD.level(id)
    if PD.needsLevel(spec.rule) and not level then
        TW(u8(t("level_wait", ctx.playerName(id) or "?")))
        return
    end
    local plan = PD.plan(id, spec, level)
    TC(C.DIM, u8(t("preview")))
    for _, line in ipairs(plan.say) do TW(u8(line)) end
    for _, c in ipairs(plan.cmds) do TC(C.BLUE, u8(c.text)) end
    if plan.choice then
        TC(C.DIM, u8(t("preview_choice")))
        for _, opt in ipairs(plan.choice) do
            local cmds = PD.cmdsFor(id, opt, spec)
            local parts = {}
            for _, c in ipairs(cmds) do table.insert(parts, c.text) end
            TC(C.BLUE, u8(table.concat(parts, "  +  ")))
        end
    end
end

-- ------------------------------------------------------------
-- SANCTIUNILE (butoane, taste, comenzi scurte)
-- ------------------------------------------------------------
function PD.offenceSpec(off)
    return { rule = off.rule, hours = off.hours, ticket = off.ticket, item = off.item, say = off.say,
             outcome = off.outcome, then_su = off.then_su, label = pick(off.label, cfg.main.uiLang) }
end

function PD.offence(offId, id)
    local off = PD.offById[offId]
    if not off then return end
    id = PD.target(id)
    if not id then return end
    if off.needs == "frisk" and not PD.guard("frisk" .. offId .. id, PD.friskProblem(id)) then return end
    local spec = PD.offenceSpec(off)
    if not PD.needsLevel(spec.rule) then return PD.execute(id, spec, PD.level(id)) end
    PD.withLevel(id, function(level) PD.execute(id, spec, level) end)
end

-- viteza: dupa intrarea din radar (viteza si limita reale) sau manual, pe treapta aleasa
function PD.speedSpec(id, entry, tierIdx)
    local tiers = D.speed.tiers or {}
    local lang = PD.langOf(id)
    local tier, vars, say
    if entry then
        local over = entry.speed - entry.limit
        for _, tt in ipairs(tiers) do
            if over >= (tonumber(tt.over) or 0) then tier = tt end
        end
        if not tier then return nil, t("under_tol", entry.speed, entry.limit) end
        say = D.speed.say_radar
        vars = { speed = entry.speed, limit = entry.limit, zone = entry.zone, over = over }
    else
        tier = tiers[tierIdx]
        if not tier then return nil end
        say = D.speed.say_manual
        vars = { limit = cfg.pd.limit, zone = cfg.pd.zone, phrase = pick(tier.phrase, lang) }
    end
    return { rule = tier.rule, hours = tier.hours, ticket = tier.ticket, say = say, vars = vars,
             label = pick(tier.label, cfg.main.uiLang) }
end

function PD.speed(id, entry, tierIdx)
    id = PD.target(id)
    if not id then return end
    local spec, why = PD.speedSpec(id, entry, tierIdx)
    if not spec then if why then ctx.msg(why) end return end
    PD.withLevel(id, function(level) PD.execute(id, spec, level) end)
end

-- ultima intrare din radar pentru jucator (dupa id si nume)
function PD.radarEntry(id)
    local name = ctx.playerName(id)
    for _, e in ipairs(PD.radar.list) do
        if e.id == id and e.name == name then return e end
    end
    return nil
end

-- /sl [id]: viteza ultimului prins (sau a celui dat, daca e in lista)
function PD.speedLast(id)
    local e
    if id then
        e = PD.radarEntry(id)
        if not e then ctx.err(t("not_in_list", tostring(id))) return end
    else
        e = PD.radar.list[1]
        if not e then ctx.err(t("no_radar_entry")) return end
    end
    if not ctx.idOnline(e.id) or ctx.playerName(e.id) ~= e.name then ctx.err(t("sus_left", e.name)) return end
    PD.speed(e.id, e)
end

-- ------------------------------------------------------------
-- VERIFICARI DE REGULAMENT: nu blocheaza, dar cer o confirmare (al doilea click in 4 s)
-- ------------------------------------------------------------
function PD.guard(key, problem)
    if not problem then return true end
    local c = PD.confirm
    if c and c.key == key and os.clock() - c.at < 4 then
        PD.confirm = nil
        ctx.msg(t("override"))
        ctx.trace("pd: confirmat peste regulament: " .. tostring(key))
        return true
    end
    PD.confirm = { key = key, at = os.clock(), text = problem }
    ctx.err(problem .. " " .. t("click_again"))
    return false
end

function PD.somatieProblem(id)
    local p = PD.person(id)
    local s = p and p.som
    local n = s and s.n or 0
    if n < 3 then return t("som_need", n) end
    if s.last - s.first > (tonumber(D.somatie_window) or 300) then return t("som_window") end
    local wait = (tonumber(D.somatie_wait) or 30) - (os.time() - s.last)
    if wait > 0 then return t("som_wait", wait) end
    return nil
end

function PD.friskProblem(id)
    local p = PD.person(id)
    if p and p.friskAt and os.time() - p.friskAt <= (tonumber(D.frisk_valid) or 600) then return nil end
    return t("frisk_need")
end

-- ------------------------------------------------------------
-- WANTED (/su) SI ACTIUNILE DE TEREN
-- ------------------------------------------------------------
function PD.su(suId, id)
    local e = PD.suById[suId]
    if not e then return end
    id = PD.target(id)
    if not id then return end
    if e.needs == "somatie" and not PD.guard("su" .. suId .. id, PD.somatieProblem(id)) then return end
    if e.needs == "frisk" and not PD.guard("su" .. suId .. id, PD.friskProblem(id)) then return end
    local cmd = fill(D.cmd.su or "/su {id}", { id = id })
    Queue.push(cmd)
    PD.expectDialog("su", e, pick(e.label, cfg.main.uiLang), cmd)
    if PD.suggest and PD.suggest.id == id and PD.suggest.su == suId then PD.suggest = nil end
    ctx.trace("pd: /su " .. tostring(id) .. " " .. suId)
end

-- somatie pe /m (se numara; o serie noua dupa fereastra de 5 minute)
function PD.countSummon(id)
    local p = PD.person(id)
    if not p then return 0 end
    local now = os.time()
    local s = p.som
    if not s or now - s.first > (tonumber(D.somatie_window) or 300) then
        s = { n = 0, first = now, last = now }
        p.som = s
    end
    s.n, s.last = s.n + 1, now
    return s.n
end

function PD.summon(id)
    id = PD.target(id)
    if not id then return end
    local name = ctx.playerName(id)
    PD.say(fill(pick(D.say.somatie, PD.langOf(id)), { name = name, id = id }))
    ctx.msg(t("som_count", PD.countSummon(id), ctx.nameTag(id, name)))
end

function PD.serverSummon()
    Queue.push(D.cmd.ms or "/ms")
    local id = PD.sus and PD.susId()
    if id then ctx.msg(t("som_count", PD.countSummon(id), ctx.nameTag(id, ctx.playerName(id)))) end
end

function PD.control(id)
    id = PD.target(id)
    if not id then return end
    PD.say(fill(pick(D.say.control, PD.langOf(id)), { name = ctx.playerName(id), id = id }))
    Queue.push(fill(D.cmd.frisk or "/frisk {id}", { id = id }))
end

function PD.gov(id)
    id = PD.target(id)
    if not id then return end
    local lines = pick(D.say.gov, PD.langOf(id))
    if type(lines) == "string" then lines = { lines } end
    for _, line in ipairs(lines or {}) do PD.say(fill(line, { name = ctx.playerName(id), id = id })) end
end

-- o comanda simpla pe suspect (/cuff, /arrest, /find...)
function PD.simple(key, id)
    id = PD.target(id)
    if not id then return end
    local tpl = D.cmd[key]
    if not tpl then return end
    Queue.push(fill(tpl, { id = id }))
end

function PD.nefondat(id)
    id = PD.target(id)
    if not id then return end
    PD.say(fill(pick(D.say.nefondat, cfg.main.procLang), { name = ctx.playerName(id), id = id }))
end

function PD.custody(id)
    id = PD.target(id)
    if not id then return end
    local p = PD.person(id) or {}
    PD.say(fill(pick(D.say.custody, cfg.main.procLang),
        { name = ctx.playerName(id), id = id, wanted = p.wanted or "?", zone = PD.zoneHere() or "?" }))
end

-- ------------------------------------------------------------
-- POZITIE: zona, oras, zone de arrest, porti
-- ------------------------------------------------------------
function PD.zoneHere()
    local ok, x, y, z = pcall(getCharCoordinates, PLAYER_PED)
    if not ok or not x then return nil end
    local okZ, zone = pcall(getNameOfZone, x, y, z)
    local okG, disp = pcall(getGxtText, okZ and zone or "")
    return (okG and disp and disp ~= "" and disp) or (okZ and zone) or nil
end

PD.CITY_BY_NUM = { [1] = "LS", [2] = "SF", [3] = "LV" }
function PD.cityHere()
    local ok, n = pcall(getCityPlayerIsIn, PLAYER_HANDLE)
    if ok then return PD.CITY_BY_NUM[tonumber(n) or 0] end
    return nil
end

function PD.nearPoint(list)
    local ok, x, y = pcall(getCharCoordinates, PLAYER_PED)
    if not ok or not x then return nil end
    for _, p in ipairs(list or {}) do
        local dx, dy, r = x - p.x, y - p.y, tonumber(p.r) or 5
        if dx * dx + dy * dy <= r * r then return p end
    end
    return nil
end

function PD.gate()
    local g = PD.nearPoint(D.gates)
    if not g then ctx.err(t("no_gate")) return end
    Queue.push(g.cmd)
end

-- jucatorii din jur (cel mai apropiat primul); se recalculeaza de doua ori pe secunda
function PD.nearby()
    local c = PD.nearCache
    if c and os.clock() - c.at < 0.5 then return c.list end
    local list = {}
    local ok = pcall(function()
        local x, y, z = getCharCoordinates(PLAYER_PED)
        for _, ped in ipairs(getAllChars()) do
            if ped ~= PLAYER_PED then
                local okId, id = sampGetPlayerIdByCharHandle(ped)
                if okId then
                    local d = getDistanceBetweenCoords3d(x, y, z, getCharCoordinates(ped))
                    if d <= 80 then table.insert(list, { id = id, name = sampGetPlayerNickname(id), dist = d }) end
                end
            end
        end
    end)
    if not ok then list = {} end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    while #list > 10 do table.remove(list) end
    for _, e in ipairs(list) do e.veh = ctx.App.Info.near(e.id).vehName end
    PD.nearCache = { at = os.clock(), list = list }
    return list
end

-- ------------------------------------------------------------
-- RADAR
-- ------------------------------------------------------------
function PD.myCity() return tostring(cfg.main.faction or "LS") end
function PD.radarCity()
    local c = cfg.pd.city
    if c == "LS" or c == "SF" or c == "LV" then return c end
    return PD.myCity()
end

-- "..." / "... x2" / "... x3"
function PD.repeatText(text, n)
    if n <= 1 then return text end
    return text .. fill(D.radar.repeat_suffix or " x{n}", { n = n })
end

-- o serie de intrebari pe /d (zona libera / acord / patrulare), cu pauza minima intre ele
function PD.askSeries(state, text)
    local now = os.time()
    local times, gap = tonumber(D.radar.ask_times) or 3, tonumber(D.radar.ask_gap) or 10
    if state.n > 0 and now - state.last > 300 then state.n, state.first = 0, nil end   -- serie veche
    if state.n > 0 and now - state.last < gap then ctx.err(t("ask_wait", gap - (now - state.last))) return false end
    if state.n >= times then state.n, state.first = 0, nil end
    state.n = state.n + 1
    state.last = now
    state.first = state.first or now
    PD.say(PD.repeatText(text, state.n))
    return true
end

function PD.radarAsk()
    if cfg.pd.zone == "" then ctx.err(t("radar_no_zone")) return end
    local st = PD.radar.asks
    if PD.askSeries(st, fill(D.radar.say.free or "/d Este libera zona de radar {zone}?", { zone = cfg.pd.zone })) then
        if st.n >= (tonumber(D.radar.ask_times) or 3) then ctx.msg(t("asked_done", st.n)) end
    end
end

function PD.radarPermit(city)
    if cfg.pd.zone == "" then ctx.err(t("radar_no_zone")) return end
    city = city or PD.radarCity()
    local st = PD.radar.permit
    if st.city ~= city then st.n, st.first, st.city = 0, nil, city end
    PD.askSeries(st, fill(D.radar.say.permit or "/d {city}PD, imi permiteti sa amplasez radar in zona {zone}?",
                          { zone = cfg.pd.zone, city = city }))
end

function PD.patrolAsk(city)
    PD.patrol[city] = PD.patrol[city] or { n = 0, last = 0 }
    PD.askSeries(PD.patrol[city], fill(pick(D.say.patrol, cfg.main.procLang) or "", { city = city }))
end

-- viteza masinii tale (0 daca esti pe jos sau nu se poate citi)
function PD.mySpeed()
    local ok, v = pcall(function()
        if not isCharInAnyCar(PLAYER_PED) then return 0 end
        return getCarSpeed(storeCarCharIsInNoSave(PLAYER_PED))
    end)
    return (ok and tonumber(v)) or 0
end

function PD.radarStart(resume)
    if cfg.pd.zone == "" then ctx.err(t("radar_no_zone")) return end
    if PD.mySpeed() > 1.0 then ctx.err(t("radar_moving")) return end
    if not resume then
        local asks = PD.radar.asks
        local times = tonumber(D.radar.ask_times) or 3
        local asked = (asks.n >= times and os.time() - asks.last <= 300) and asks.n or 0   -- intrebarile vechi nu mai conteaza
        if asked < times and not PD.guard("radar_ask", t("radar_not_asked", asked)) then return end
        if PD.radarCity() ~= PD.myCity() then
            local p = PD.radar.permit
            if (p.n or 0) == 0 or p.city ~= PD.radarCity() then
                if not PD.guard("radar_permit", t("radar_no_permit")) then return end
            end
        end
    end
    if resume then Queue.push(D.cmd.cancelfind or "/cancel find") end
    Queue.push(fill(D.cmd.startradar or "/startradar {limit}", { limit = cfg.pd.limit }))
    local say = resume and D.radar.say.resume or D.radar.say.start
    if say then PD.say(fill(pick(say, cfg.main.procLang), { zone = cfg.pd.zone, limit = cfg.pd.limit })) end
    PD.radar.stage, PD.radar.fresh = "on", nil
end

function PD.radarStop(withFind)
    Queue.push(D.cmd.stopradar or "/stopradar")
    local e = PD.radar.fresh
    if withFind and e and ctx.idOnline(e.id) and ctx.playerName(e.id) == e.name then
        Queue.push(fill(D.cmd.find or "/find {id}", { id = e.id }))
        PD.setSuspect(e.id, true)
    end
    PD.radar.stage = (withFind and e) and "stopped" or "off"
    PD.radar.fresh = nil
end

-- tasta / butonul Radar: porneste -> (prins) opreste + find -> reia
function PD.radarToggle()
    local st = PD.radar.stage
    if st == "on" then PD.radarStop(PD.radar.fresh ~= nil)
    elseif st == "stopped" then PD.radarStart(true)
    else PD.radarStart(false) end
end

function PD.onRadar(name, id, level, speed, limit)
    id, level, speed, limit = tonumber(id), tonumber(level), tonumber(speed), tonumber(limit)
    if not (id and speed and limit) then return end
    local e = { id = id, name = name, level = level, speed = speed, limit = limit, over = speed - limit,
                zone = (cfg.pd.zone ~= "" and cfg.pd.zone) or PD.zoneHere() or "?", at = os.time() }
    table.insert(PD.radar.list, 1, e)
    while #PD.radar.list > (tonumber(D.radar.keep) or 8) do table.remove(PD.radar.list) end
    if level then ctx.rememberLevel(id, level) end
    PD.radar.fresh = e
    PD.radar.stage = "on"
    local spec = PD.speedSpec(id, e)
    local what = spec and PD.actLabel(PD.actFor(spec.rule, level), spec.hours) or t("act_warn")
    ctx.msg(t("radar_caught", ctx.nameTag(id, name), level or 0, speed, limit, e.over, what))
    ctx.Notify.push("Radar  " .. tostring(name) .. " (" .. id .. ")",
                    t("radar_caught_short", speed, limit, e.over) .. "  -  " .. what, "info")
end

-- ------------------------------------------------------------
-- DIALOGURILE /ticket SI /su: randul potrivit, gasit dupa text (sau pozitie)
-- ------------------------------------------------------------
function PD.pickMode()
    local m = cfg.pd.pick
    if m == "" then m = tostring(D.dialog_pick or "press") end
    if m ~= "press" and m ~= "select" and m ~= "off" then m = "press" end
    return m
end

function PD.expectDialog(kind, entry, label, cmd)
    if PD.pickMode() == "off" then ctx.msg(t("dlg_manual", tostring(label))) return end
    PD.dlg = { kind = kind, entry = entry or {}, label = tostring(label or kind), cmd = cmd, at = os.clock() }
end

-- randurile unui dialog cu lista (stilul 5 are si un rand de cap de tabel)
function PD.dialogItems(text, style)
    local items = {}
    for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(items, (plain(line):gsub("\t", "  "):gsub("^%s+", ""):gsub("%s+$", "")))
    end
    while #items > 0 and items[#items] == "" do table.remove(items) end
    if style == 5 and #items > 0 then table.remove(items, 1) end
    return items
end

-- intoarce (index de la 0, cat de sigur: "index" / "text" / "guess")
function PD.pickIndex(items, e)
    local function good(i)
        local line = items[i + 1]
        return line ~= nil and hasWord(line, e.find) and not hasWord(line, e.avoid)
    end
    local idx = tonumber(e.index)
    if idx and items[idx + 1] and (not e.find or good(idx)) then return idx, "index" end
    for i = 0, #items - 1 do
        if e.find and good(i) then return i, "text" end
    end
    if idx and items[idx + 1] then return idx, "guess" end
    return nil
end

function PD.dialogSig()
    local ok, active = pcall(sampIsDialogActive)
    if not ok or not active then return nil end
    return tostring(sampGetDialogCaption()) .. "\n" .. tostring(sampGetDialogText())
end

function PD.dialogUpdate()
    local w = PD.dlg
    if not w then return end
    local now = os.clock()
    if not w.sentAt then
        if PD.queued(w.cmd) then
            if now - w.at > 30 then PD.dlg = nil end
            return
        end
        w.sentAt, w.prev = now, PD.dialogSig()
        return
    end
    if not w.idx then
        if now - w.sentAt > 6 then PD.dlg = nil ctx.msg(t("dlg_none", w.label)) return end
        local sig = PD.dialogSig()
        if not sig or sig == w.prev then return end
        local okS, style = pcall(sampGetCurrentDialogType)
        style = okS and tonumber(style) or nil
        if style and style ~= 2 and style ~= 4 and style ~= 5 then
            PD.dlg = nil
            ctx.trace("pd: dialogul dupa " .. tostring(w.cmd) .. " nu e o lista (stil " .. tostring(style) .. ")")
            return
        end
        local items = PD.dialogItems(sampGetDialogText(), style)
        ctx.trace("pd: dialog " .. tostring(sampGetDialogCaption()) .. ": " .. table.concat(items, " | "))
        local idx, how = PD.pickIndex(items, w.entry)
        if not idx then PD.dlg = nil ctx.msg(t("dlg_yourself", w.label)) return end
        w.idx, w.how, w.item, w.setAt, w.tries = idx, how, items[idx + 1] or ("#" .. idx), now, 0
        pcall(sampSetCurrentDialogListItem, idx)
        return
    end
    -- randul e selectat? atunci apasam (sau lasam instructorul sa apese)
    local okG, cur = pcall(sampGetCurrentDialogListItem)
    if okG and tonumber(cur) == w.idx then
        PD.dlg = nil
        if w.how == "guess" then
            ctx.msg(t("dlg_check", w.item))
        elseif PD.pickMode() == "press" then
            pcall(sampCloseCurrentDialogWithButton, 1)
            ctx.msg(t("dlg_pressed", w.item))
        else
            ctx.msg(t("dlg_selected", w.item))
        end
        return
    end
    if now - w.setAt > 0.3 then
        w.tries = w.tries + 1
        if w.tries > 6 or not PD.dialogSig() then PD.dlg = nil ctx.err(t("dlg_fail", w.label)) return end
        pcall(sampSetCurrentDialogListItem, w.idx)
        w.setAt = now
    end
end

-- ------------------------------------------------------------
-- TIMERE (AFK)
-- ------------------------------------------------------------
function PD.afk(id)
    if id then
        id = PD.target(id)
        if not id then return end
        local name = ctx.playerName(id)
        PD.say(fill(pick(D.say.afk, cfg.main.procLang), { name = name, id = id }))
        PD.timer = { label = t("timer_afk", name), total = "3:00", until_ = os.time() + 180 }
    else
        PD.timer = { label = t("timer_30"), total = "0:30", until_ = os.time() + 30 }
    end
end

-- ------------------------------------------------------------
-- EVENIMENTE (apelate din SICHelper.lua)
-- ------------------------------------------------------------
function PD.onServerLine(text)
    local line = plain(text)
    for _, pat in ipairs(D.radar.catch or {}) do
        local name, id, level, speed, limit = line:match(pat)
        if name then PD.onRadar(name, id, level, speed, limit) break end
    end
    PD.onIdLine(line)
    if PD.isDept() then
        for _, p in ipairs(D.duty_on or {}) do if line:find(p, 1, true) then ctx.Duty.set(true) end end
        for _, p in ipairs(D.duty_off or {}) do if line:find(p, 1, true) then ctx.Duty.set(false) end end
    end
end

-- comenzile trimise (de noi sau tastate de tine): starea radarului, frisk-ul (dovada), catusele
function PD.onSendCommand(command)
    local c = tostring(command or ""):lower()
    if c:find("^/startradar") then PD.radar.stage = "on"
    elseif c:find("^/stopradar") then
        if PD.radar.stage == "on" then PD.radar.stage = "off" end
    end
    local fid = tonumber(c:match("^/frisk%s+(%d+)"))
    if fid then local p = PD.person(fid) if p then p.friskAt = os.time() end end
    local cid = tonumber(c:match("^/cuff%s+(%d+)"))
    if cid then local p = PD.person(cid) if p then p.cuffed = true end end
    local uid = tonumber(c:match("^/uncuff%s+(%d+)"))
    if uid then local p = PD.person(uid) if p then p.cuffed = false end end
end

-- din bucla principala
function PD.update()
    local now = os.clock()
    if PD.identFor and now >= PD.identAt then
        local id = PD.identFor
        PD.identFor = nil
        if PD.sus and PD.sus.id == id and not PD.level(id) and not PD.idWait and ctx.idOnline(id) then PD.ask(id) end
    end
    if PD.pending and now - PD.pending.at > 7 then
        PD.pending = nil
        ctx.err(t("level_timeout"))
    end
    if PD.idWait and now - PD.idWait.at > 7 then PD.idWait = nil end
    PD.dialogUpdate()
    if PD.timer and os.time() >= PD.timer.until_ then
        ctx.msg(t("timer_done", PD.timer.total, PD.timer.label))
        ctx.Notify.push(t("window"), t("timer_done", PD.timer.total, PD.timer.label), "info")
        PD.timer = nil
    end
    if PD.choice and os.time() - PD.choice.at > 300 then PD.choice = nil end
    -- suspectul pastrat in campul de ID cand se schimba din alta parte
    local sid = PD.sus and PD.sus.id
    if sid ~= PD.idShown then
        PD.idShown = sid
        imgui.StrCopy(PD.idBuf, sid and tostring(sid) or "")
    end
end

function PD.toggle(arg)
    local id = tonumber(arg)
    if id then PD.setSuspect(id) PD.open[0] = true return end
    PD.open[0] = not PD.open[0]
end

-- ------------------------------------------------------------
-- INTERFATA
-- ------------------------------------------------------------
PD.TABS = {
    { key = "tab_road",    icon = "CAR" },
    { key = "tab_wanted",  icon = "HANDCUFFS" },
    { key = "tab_control", icon = "MAGNIFYING_GLASS" },
    { key = "tab_radar",   icon = "GAUGE_HIGH" },
    { key = "tab_disp",    icon = "TOWER_BROADCAST" },
}

-- un rand de butoane egale; fiecare: { label, active, tip = function, run = function, color }
local function buttonRow(buttons, h)
    local spacing = imgui.GetStyle().ItemSpacing.x
    local w = (imgui.GetContentRegionAvail().x - spacing * (#buttons - 1)) / #buttons
    for i, b in ipairs(buttons) do
        local clicked
        if b.primary then clicked = ctx.primaryButton(b.label, imgui.ImVec2(w, h))
        else clicked = ctx.toggleButton(b.label, b.active == true, imgui.ImVec2(w, h), b.color, b.color) end
        if imgui.IsItemHovered() and b.tip then
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(px(420))
            b.tip()
            imgui.PopTextWrapPos()
            imgui.EndTooltip()
        end
        if clicked and b.run then b.run() end
        if i < #buttons then imgui.SameLine() end
    end
end

local function tipText(s) return function() TW(u8(s)) end end

local function sectionTitle(text)
    imgui.Spacing()
    TC(theme().accent, u8(text))
end

local function rulesNotes(group)
    local set = (D.rules or {})[cfg.main.uiLang] or (D.rules or {}).ro or {}
    local lines = set[group]
    if not lines or #lines == 0 then return end
    sectionTitle(t("rules_title"))
    imgui.PushStyleColor(imgui.Col.Text, C.DIM)
    for _, line in ipairs(lines) do imgui.Bullet() TW(u8(line)) end
    imgui.PopStyleColor()
end

-- capul ferestrei: tab-urile, RO / EN, setari, inchide tot
function PD.drawHeader()
    local spacing = imgui.GetStyle().ItemSpacing.x
    local right = 30 + 26 + 30 + spacing * 3
    local w = (imgui.GetContentRegionAvail().x - right - spacing * (#PD.TABS - 1)) / #PD.TABS
    for i, tab in ipairs(PD.TABS) do
        -- tab-uri inguste: doar iconita (numele apare la hover)
        local text = u8(t(tab.key))
        local label = icon(tab.icon) .. text
        if ctx.State.icons and imgui.CalcTextSize(label).x > w - 10 then label = icon(tab.icon) end
        if ctx.toggleButton(label .. "##pdtab" .. i, PD.tab == i, imgui.ImVec2(w, 24)) then PD.tab = i end
        if imgui.IsItemHovered() then TIP(text) end
        imgui.SameLine()
    end
    local lang = cfg.main.procLang
    if ctx.toggleButton(string.upper(tostring(lang)) .. "##pdlang", true, imgui.ImVec2(30, 24), C.BLUE) then
        cfg.main.procLang = (lang == "ro") and "en" or "ro"
        ctx.State.sicLang = cfg.main.procLang
        ctx.saveCfg()
        if PD.sus then ctx.Langs.remember(PD.sus.id, cfg.main.procLang) end
    end
    if imgui.IsItemHovered() then TIP(u8(t("lang_tip"))) end
    imgui.SameLine()
    if imgui.Button((ctx.State.icons and fa.GEAR or "S") .. "##pdsih", imgui.ImVec2(26, 24)) then ctx.State.sih[0] = true end
    if imgui.IsItemHovered() then TIP(u8(t("settings_tip"))) end
    imgui.SameLine()
    ctx.closeAllButton("pdc")
end

function PD.drawSuspect()
    local th = theme()
    local s = PD.sus
    TC(C.DIM, t("suspect"))
    imgui.SameLine()
    if imgui.Button("-##pdm", imgui.ImVec2(20, 20)) then PD.setSuspect(ctx.stepConnected(s and s.id, -1), true) end
    imgui.SameLine()
    imgui.PushItemWidth(42)
    if imgui.InputText("##pdid", PD.idBuf, 8, imgui.InputTextFlags.CharsDecimal) then
        local typed = tonumber(ffi.string(PD.idBuf))
        if typed and ctx.idOnline(typed) then PD.setSuspect(typed, true) end
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    if imgui.Button("+##pdp", imgui.ImVec2(20, 20)) then PD.setSuspect(ctx.stepConnected(s and s.id, 1), true) end
    imgui.SameLine()
    if imgui.Button((ctx.State.icons and fa.LOCATION_CROSSHAIRS or "N") .. "##pdnear", imgui.ImVec2(24, 20)) then
        local near = ctx.nearestPlayer()
        if near then PD.setSuspect(near) else ctx.err(ctx.tr("no_near", ctx.K.NEAR_DISTANCE)) end
    end
    if imgui.IsItemHovered() then TIP(u8(t("near_tip"))) end
    imgui.SameLine()
    imgui.PushItemWidth(24)
    if imgui.BeginCombo("##pdnearby", "") then
        local list = PD.nearby()
        if #list == 0 then TC(C.DIM, u8(t("near_none"))) end
        for _, e in ipairs(list) do
            local label = string.format("%s (%d)  -  %d m", tostring(e.name), e.id, math.floor(e.dist + 0.5))
            if e.veh then label = label .. "  -  " .. tostring(e.veh) end
            if imgui.Selectable(u8(label) .. "##pdnb" .. e.id, s ~= nil and s.id == e.id) then PD.setSuspect(e.id) end
        end
        imgui.EndCombo()
    end
    imgui.PopItemWidth()
    if imgui.IsItemHovered() then TIP(u8(t("nearby_tip"))) end
    imgui.SameLine()
    if not s then TC(C.DIM, u8(t("no_suspect_short"))) return end
    TC(th.accent, u8(s.name))
    imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - 52)
    if imgui.Button((ctx.State.icons and fa.ID_CARD or "i") .. "##pdinfo", imgui.ImVec2(24, 20)) then ctx.App.Info.show(s.id) end
    if imgui.IsItemHovered() then TIP(u8(t("info_tip"))) end
    imgui.SameLine()
    if imgui.Button((ctx.State.icons and fa.XMARK or "x") .. "##pdclr", imgui.ImVec2(24, 20)) then PD.sus = nil return end
    if imgui.IsItemHovered() then TIP(u8(t("clear_tip"))) end

    -- nivelul si ce inseamna el
    local lvl = PD.level(s.id)
    TC(C.DIM, t("level"))
    imgui.SameLine(0, 4)
    TC(C.TEXT, lvl and tostring(lvl) or "?")
    imgui.SameLine(0, 10)
    local brText, brCol = PD.bracket(lvl)
    TC(brCol, u8(brText))
    local inf = PD.info[s.id] or ctx.App.Info.byId[s.id]
    if inf and inf.faction and inf.name == s.name then
        imgui.SameLine(0, 10)
        local fac = tostring(inf.faction)
        if inf.rank then fac = fac .. " - " .. tostring(ctx.Factions.rankName(ctx.App.Info.factionId(inf.faction), inf.rank)) end
        TC(C.DIM, u8(fac))
    end

    -- starea: distanta / vehicul, somatii, frisk, radar
    local near = ctx.App.Info.near(s.id)
    local parts = {}
    table.insert(parts, near.streamed and t("dist", near.dist or 0) or t("far"))
    if near.vehName then table.insert(parts, t("in_veh", near.vehName)) end
    local p = PD.people[s.name] or {}
    if p.som then table.insert(parts, t("som_chip", p.som.n) .. " (" .. t("som_ago", ago(os.time() - p.som.last)) .. ")") end
    table.insert(parts, p.friskAt and t("frisk_chip", ago(os.time() - p.friskAt)) or t("frisk_none"))
    if p.cuffed then table.insert(parts, t("cuffed")) end
    local e = PD.radarEntry(s.id)
    if e then table.insert(parts, t("radar_chip", e.speed, e.limit, e.over)) end
    TC(C.DIM, u8(table.concat(parts, "  -  ")))
end

-- benzile de sub suspect: alegerea jucatorului, wanted-ul propus, confirmarea, timerul
function PD.drawStrips()
    local th = theme()
    local c = PD.choice
    if c then
        TC(C.AMBER, u8(t("choice_q", c.name)))
        imgui.SameLine()
        local buttons = {}
        for _, opt in ipairs(c.opts) do
            local label = (opt == "fine" and t("choice_fine")) or (opt == "lic" and t("choice_lic", PD.hoursText(c.spec.hours or 1, cfg.main.uiLang)))
                          or (opt == "seize" and t("choice_seize")) or opt
            table.insert(buttons, { label = u8(label) .. "##pdch" .. opt, primary = true, run = function() PD.resolve(opt) end,
                                    tip = tipText(t("choice_tip")) })
        end
        table.insert(buttons, { label = (ctx.State.icons and fa.XMARK or "x") .. "##pdchx", run = function() PD.choice = nil end,
                                tip = tipText(t("dismiss")) })
        buttonRow(buttons, 22)
    end
    local sg = PD.suggest
    if sg then
        local e = PD.suById[sg.su]
        TC(th.accent, u8(t("suggest", pick(e and e.label, cfg.main.uiLang) or sg.su, sg.name)))
        imgui.SameLine()
        buttonRow({
            { label = u8(t("suggest_send")) .. "##pdsg", primary = true, run = function() PD.su(sg.su, sg.id) end, tip = tipText(t("suggest_tip")) },
            { label = (ctx.State.icons and fa.XMARK or "x") .. "##pdsgx", run = function() PD.suggest = nil end, tip = tipText(t("dismiss")) },
        }, 22)
    end
    local cf = PD.confirm
    if cf and os.clock() - cf.at < 4 then
        imgui.PushStyleColor(imgui.Col.Text, C.RED)
        TW(u8(cf.text .. " " .. t("click_again")))
        imgui.PopStyleColor()
    end
    local tm = PD.timer
    if tm then
        TC(C.AMBER, u8(t("timer", tm.label, clock(tm.until_ - os.time()))))
        imgui.SameLine()
        if ctx.toggleButton(u8(t("timer_stop")) .. "##pdtmstop", false, imgui.ImVec2(px(60), 20)) then PD.timer = nil end
    end
end

-- butonul unei abateri: "Nume\nce se intampla la nivelul lui"
local function offenceButton(off, w, h)
    local sid = PD.sus and PD.sus.id
    local spec = PD.offenceSpec(off)
    local level = sid and PD.level(sid)
    local what = (sid and (level or not PD.needsLevel(spec.rule))) and PD.actLabel(PD.actFor(spec.rule, level), spec.hours, cfg.main.uiLang) or t("act_level")
    local label = u8(spec.label) .. "\n" .. u8(what) .. "##pdoff" .. off.id
    local col = nil
    if off.needs == "frisk" and sid and PD.friskProblem(sid) then col = C.AMBER end
    local clicked = ctx.toggleButton(label, false, imgui.ImVec2(w, h), col, col)
    if imgui.IsItemHovered() and sid then
        imgui.BeginTooltip()
        imgui.PushTextWrapPos(px(420))
        PD.previewTip(sid, spec)
        imgui.PopTextWrapPos()
        imgui.EndTooltip()
    end
    if clicked then PD.offence(off.id) end
end

local function offenceGrid(group)
    local list = {}
    for _, o in ipairs(D.offences or {}) do if o.group == group then table.insert(list, o) end end
    local spacing = imgui.GetStyle().ItemSpacing.x
    local w = (imgui.GetContentRegionAvail().x - spacing) / 2
    for i, o in ipairs(list) do
        offenceButton(o, w, px(38))
        if i % 2 == 1 and i < #list then imgui.SameLine() end
    end
end

function PD.drawRoad()
    local sid = PD.sus and PD.sus.id
    sectionTitle(t("speed_title"))
    local e = sid and PD.radarEntry(sid)
    if e then
        local spec, why = PD.speedSpec(sid, e)
        local what = spec and PD.actLabel(PD.actFor(spec.rule, PD.level(sid)), spec.hours, cfg.main.uiLang) or why
        local label = u8(t("speed_radar", e.speed, e.limit, e.over)) .. "\n" .. u8(what or "") .. "##pdspeedr"
        if ctx.primaryButton(label, imgui.ImVec2(imgui.GetContentRegionAvail().x, px(38))) then PD.speed(sid, e) end
        if imgui.IsItemHovered() and spec then
            imgui.BeginTooltip() imgui.PushTextWrapPos(px(420)) PD.previewTip(sid, spec) imgui.PopTextWrapPos() imgui.EndTooltip()
        end
    end
    local buttons = {}
    for i, tier in ipairs(D.speed.tiers or {}) do
        local spec = sid and PD.speedSpec(sid, nil, i)
        local lvl = sid and PD.level(sid)
        local what = (spec and lvl) and PD.actLabel(PD.actFor(spec.rule, lvl), spec.hours, cfg.main.uiLang) or t("act_level")
        table.insert(buttons, {
            label = u8(pick(tier.label, cfg.main.uiLang)) .. "\n" .. u8(what) .. "##pdtier" .. i,
            run = function() PD.speed(nil, nil, i) end,
            tip = spec and function() PD.previewTip(sid, spec) end or nil,
        })
    end
    if #buttons > 0 then buttonRow(buttons, px(38)) end
    sectionTitle(t("road_title"))
    offenceGrid("road")
    rulesNotes("road")
end

function PD.drawWanted()
    local sid = PD.sus and PD.sus.id
    sectionTitle(t("wanted_title"))
    local list = D.su or {}
    local spacing = imgui.GetStyle().ItemSpacing.x
    local w = (imgui.GetContentRegionAvail().x - spacing) / 2
    for i, e in ipairs(list) do
        local status, col = "", nil
        if e.needs == "somatie" and sid then
            local prob = PD.somatieProblem(sid)
            local p = PD.people[PD.sus.name] or {}
            status = t("som_chip", p.som and p.som.n or 0)
            col = prob and C.AMBER or C.OK
        elseif e.needs == "frisk" and sid then
            local prob = PD.friskProblem(sid)
            local p = PD.people[PD.sus.name] or {}
            status = p.friskAt and t("frisk_chip", ago(os.time() - p.friskAt)) or t("frisk_none")
            col = prob and C.AMBER or C.OK
        end
        local label = u8(pick(e.label, cfg.main.uiLang)) .. "\n" .. u8(status) .. "##pdsu" .. e.id
        if ctx.toggleButton(label, false, imgui.ImVec2(w, px(38)), col, col) then PD.su(e.id) end
        if imgui.IsItemHovered() and sid then TIP(u8(fill(D.cmd.su or "/su {id}", { id = sid }))) end
        if i % 2 == 1 and i < #list then imgui.SameLine() end
    end
    imgui.Spacing()
    local somText = sid and fill(pick(D.say.somatie, PD.langOf(sid)), { name = PD.sus.name, id = sid }) or ""
    local nefText = sid and fill(pick(D.say.nefondat, cfg.main.procLang), { name = PD.sus.name, id = sid }) or ""
    buttonRow({
        { label = icon("BULLHORN") .. u8(t("somatie")) .. "##pdwsom", run = function() PD.summon() end, tip = tipText(t("somatie_tip", somText)) },
        { label = u8(t("ms")) .. "##pdwms", run = function() PD.serverSummon() end, tip = tipText(t("ms_tip")) },
        { label = u8(t("nefondat")) .. "##pdwnef", run = function() PD.nefondat() end, tip = tipText(t("nefondat_tip", nefText)) },
        { label = u8(t("gov")) .. "##pdwgov", run = function() PD.gov() end, tip = tipText(t("gov_tip")) },
    }, 24)
    buttonRow({
        { label = u8(t("wanted_list")) .. "##pdwl", run = function() Queue.push(D.cmd.wanted or "/wanted") end },
        { label = u8(t("nearwanted")) .. "##pdnwl", run = function() Queue.push(D.cmd.nearwanted or "/nearwanted") end },
        { label = u8(t("tazer")) .. "##pdtz", run = function() Queue.push(D.cmd.tazer or "/tazer") end },
    }, 24)
    rulesNotes("wanted")
end

function PD.drawControl()
    local sid = PD.sus and PD.sus.id
    sectionTitle(t("control_title"))
    local ctrlText = sid and fill(pick(D.say.control, PD.langOf(sid)), { name = PD.sus.name, id = sid }) or ""
    buttonRow({
        { label = icon("MAGNIFYING_GLASS") .. u8(t("control")) .. "##pdctl", primary = true, run = function() PD.control() end,
          tip = tipText(t("control_tip", ctrlText)) },
        { label = u8(t("reqlic")) .. "##pdrl", run = function() PD.simple("reqlic") end },
    }, 26)
    sectionTitle(t("contraband_title"))
    offenceGrid("frisk")
    sectionTitle(t("custody_title"))
    local here = PD.nearPoint(D.arrest_points)
    buttonRow({
        { label = icon("HANDCUFFS") .. u8(t("cuff")) .. "##pdcuff", run = function() PD.simple("cuff") end },
        { label = u8(t("uncuff")) .. "##pduncuff", run = function() PD.simple("uncuff") end },
        { label = u8(t("arrest")) .. "##pdarr", active = here ~= nil, color = here and C.OK or nil, run = function() PD.simple("arrest") end,
          tip = tipText((here and (t("arrest_here", tostring(here.label)) .. "\n") or "") .. t("arrest_tip")) },
        { label = u8(t("eject")) .. "##pdej", run = function() PD.simple("eject") end },
    }, 24)
    TC(C.DIM, u8(t("wanted_lvl")))
    local p = sid and PD.person(sid)
    for n = 1, 6 do
        imgui.SameLine()
        if ctx.toggleButton(tostring(n) .. "##pdwv" .. n, p ~= nil and p.wanted == n, imgui.ImVec2(24, 20)) and p then
            p.wanted = (p.wanted == n) and nil or n
        end
    end
    imgui.SameLine()
    local custText = sid and fill(pick(D.say.custody, cfg.main.procLang),
        { name = PD.sus.name, id = sid, wanted = (p and p.wanted) or "?", zone = PD.zoneHere() or "?" }) or ""
    if ctx.toggleButton(u8(t("custody")) .. "##pdcust", false, imgui.ImVec2(imgui.GetContentRegionAvail().x, 20)) then PD.custody() end
    if imgui.IsItemHovered() then TIP(u8(custText)) end
    buttonRow({
        { label = u8(t("find")) .. "##pdfind", run = function() PD.simple("find") end },
        { label = u8(t("cancelfind")) .. "##pdcf", run = function() Queue.push(D.cmd.cancelfind or "/cancel find") end },
    }, 22)
    rulesNotes("control")
end

function PD.drawRadar()
    local th = theme()
    sectionTitle(t("radar_title") .. "  -  " .. t("radar_state_" .. PD.radar.stage))
    -- zona
    TC(C.DIM, u8(t("zone")))
    imgui.SameLine(px(60))
    imgui.PushItemWidth(imgui.GetContentRegionAvail().x - px(70))
    if imgui.InputText("##pdzone", PD.zoneBuf, 64) then
        cfg.pd.zone = ffi.string(PD.zoneBuf)
        PD.radar.asks.n = 0
        ctx.State.sicPosDirty = true
    end
    imgui.PopItemWidth()
    imgui.SameLine()
    if ctx.toggleButton(u8(t("here")) .. "##pdhere", false, imgui.ImVec2(px(62), 20)) then
        local z = PD.zoneHere()
        if z then
            cfg.pd.zone = z
            imgui.StrCopy(PD.zoneBuf, z)
            PD.radar.asks.n = 0
        end
        local c = PD.cityHere()
        if c then cfg.pd.city = c end
        ctx.saveCfg()
    end
    if imgui.IsItemHovered() then TIP(u8(t("here_tip"))) end
    -- limita
    TC(C.DIM, u8(t("limit")))
    imgui.SameLine(px(60))
    for i, lim in ipairs(D.speed.limits or { 100, 130, 160 }) do
        if ctx.toggleButton(tostring(lim) .. "##pdlim" .. i, cfg.pd.limit == lim, imgui.ImVec2(px(52), 20)) then
            cfg.pd.limit = lim
            ctx.saveCfg()
        end
        imgui.SameLine()
    end
    imgui.NewLine()
    -- orasul radarului
    TC(C.DIM, u8(t("city")))
    imgui.SameLine(px(60))
    local rc = PD.radarCity()
    for _, c in ipairs({ "LS", "SF", "LV" }) do
        if ctx.toggleButton(c .. "##pdcity" .. c, rc == c, imgui.ImVec2(px(52), 20)) then
            cfg.pd.city = c
            ctx.saveCfg()
        end
        imgui.SameLine()
    end
    TC(C.DIM, u8("(" .. t("own_city") .. ": " .. PD.myCity() .. ")"))

    -- intrebarile pe /d
    local asks = PD.radar.asks
    local times, gap = tonumber(D.radar.ask_times) or 3, tonumber(D.radar.ask_gap) or 10
    local wait = asks.n > 0 and (gap - (os.time() - asks.last)) or 0
    local askLabel = t("ask_free", math.min(asks.n, times), times) .. ((wait > 0 and asks.n < times) and ("  (" .. wait .. "s)") or "")
    local freeText = fill(D.radar.say.free or "", { zone = cfg.pd.zone })
    local buttons = {
        { label = u8(askLabel) .. "##pdask", active = asks.n >= times, color = (asks.n >= times) and C.OK or nil,
          run = function() PD.radarAsk() end, tip = tipText(t("ask_free_tip", freeText)) },
    }
    if rc ~= PD.myCity() then
        local pm = PD.radar.permit
        local n = (pm.city == rc) and pm.n or 0
        local permitText = fill(D.radar.say.permit or "", { zone = cfg.pd.zone, city = rc })
        local extra = ""
        if n > 0 and pm.first then
            local since = os.time() - pm.first
            extra = (since >= (tonumber(D.radar.permit_wait) or 60)) and ("\n" .. t("permit_ok")) or ("\n" .. t("permit_ago", ago(since)))
        end
        table.insert(buttons, { label = u8(t("permit", rc, math.min(n, times), times) .. extra) .. "##pdpermit",
                                active = n > 0, run = function() PD.radarPermit(rc) end, tip = tipText(t("permit_tip", permitText)) })
    end
    buttonRow(buttons, px(34))

    -- butonul mare
    local st = PD.radar.stage
    local big
    if st == "on" and PD.radar.fresh then big = t("radar_stopfind", PD.radar.fresh.name)
    elseif st == "on" then big = t("radar_stop")
    elseif st == "stopped" then big = t("radar_resume")
    else big = t("radar_start") end
    local row = { { label = icon("GAUGE_HIGH") .. u8(big) .. "##pdradar", primary = true, run = function() PD.radarToggle() end,
                    tip = tipText(t("radar_toggle_tip")) } }
    if st == "on" and PD.radar.fresh then
        table.insert(row, { label = u8(t("radar_stop_only")) .. "##pdrstop", run = function() PD.radarStop(false) end })
    end
    buttonRow(row, 28)

    -- lista
    sectionTitle(t("list_title"))
    if #PD.radar.list == 0 then TC(C.DIM, u8(t("list_empty"))) end
    for i, e in ipairs(PD.radar.list) do
        local tierCol = C.TEXT
        local spec = PD.speedSpec(e.id, e)
        if spec then tierCol = (spec.rule == "fine") and C.AMBER or C.RED else tierCol = C.DIM end
        TC(C.DIM, ago(os.time() - e.at))
        imgui.SameLine(px(44))
        TC(th.accent, u8(tostring(e.name) .. " (" .. e.id .. ")"))
        imgui.SameLine(0, 8)
        TC(C.DIM, "Lv " .. tostring(e.level or "?"))
        imgui.SameLine(0, 8)
        TC(tierCol, t("radar_caught_short", e.speed, e.limit, e.over))
        imgui.SameLine(imgui.GetWindowWidth() - imgui.GetStyle().WindowPadding.x - px(170))
        if ctx.toggleButton(u8(t("pick")) .. "##pdrp" .. i, PD.sus ~= nil and PD.sus.id == e.id, imgui.ImVec2(px(70), 20)) then
            PD.setSuspect(e.id)
        end
        imgui.SameLine()
        if ctx.primaryButton(u8(t("sanction")) .. "##pdrs" .. i, imgui.ImVec2(px(92), 20)) then
            if ctx.idOnline(e.id) and ctx.playerName(e.id) == e.name then PD.speed(e.id, e) else ctx.err(t("sus_left", e.name)) end
        end
        if imgui.IsItemHovered() and spec then
            imgui.BeginTooltip() imgui.PushTextWrapPos(px(420)) PD.previewTip(e.id, spec) imgui.PopTextWrapPos() imgui.EndTooltip()
        end
    end
    rulesNotes("radar")
end

function PD.drawDispatch()
    sectionTitle(t("tab_disp"))
    buttonRow({
        { label = u8(t("duty")) .. "##pdduty", primary = true, run = function()
            for _, c in ipairs(D.cmd.duty or { "/duty" }) do Queue.push(c) end
        end },
        { label = u8(t("fvr")) .. "##pdfvr", run = function() ctx.FVR.start() end },
    }, 26)
    -- patrulare in alt oras
    local row = {}
    for _, c in ipairs({ "LS", "SF", "LV" }) do
        if c ~= PD.myCity() then
            local st = PD.patrol[c] or { n = 0 }
            local text = fill(pick(D.say.patrol, cfg.main.procLang) or "", { city = c })
            table.insert(row, { label = u8(t("patrol", c, st.n or 0, tonumber(D.radar.ask_times) or 3)) .. "##pdpat" .. c,
                                active = (st.n or 0) > 0, run = function() PD.patrolAsk(c) end, tip = tipText(t("patrol_tip", text)) })
        end
    end
    buttonRow(row, 24)
    local afkText = (PD.sus and fill(pick(D.say.afk, cfg.main.procLang), { name = PD.sus.name, id = PD.sus.id })) or ""
    buttonRow({
        { label = u8(t("afk3")) .. "##pdafk", tip = tipText(t("afk3_tip", afkText)),
          run = function() if PD.sus then PD.afk(PD.sus.id) else ctx.err(t("no_suspect")) end end },
        { label = u8(t("afk30")) .. "##pdafk30", run = function() PD.afk(nil) end, tip = tipText(t("afk30_tip")) },
    }, 24)
    local gate = PD.nearPoint(D.gates)
    if gate then
        if ctx.primaryButton(u8(t("gate", tostring(gate.label or gate.cmd))) .. "##pdgate", imgui.ImVec2(imgui.GetContentRegionAvail().x, 24)) then
            Queue.push(gate.cmd)
        end
    end

    -- dialogurile
    sectionTitle(t("pick_title"))
    local mode = PD.pickMode()
    local modes = { { "press", "pick_press" }, { "select", "pick_select" }, { "off", "pick_off" } }
    for i, m in ipairs(modes) do
        if ctx.toggleButton(u8(t(m[2])) .. "##pdpick" .. m[1], mode == m[1], imgui.ImVec2(px(130), 22)) then
            cfg.pd.pick = m[1]
            ctx.saveCfg()
        end
        if imgui.IsItemHovered() then TIP(u8(t("pick_tip"))) end
        if i < #modes then imgui.SameLine() end
    end

    -- comenzile scurte
    sectionTitle(t("cmds_title"))
    PD.drawGuide(ctx.guideLine)

    imgui.Spacing()
    if PD.dataError then
        imgui.PushStyleColor(imgui.Col.Text, C.RED)
        TW(u8(t("data_error", PD.dataError)))
        imgui.PopStyleColor()
    end
    imgui.PushStyleColor(imgui.Col.Text, C.DIM)
    TW(u8(t("data_file", "moonloader/config/SICHelper_pd.lua") .. "  " .. t("reload_hint")))
    imgui.PopStyleColor()
end

-- lista de comenzi (in statie si in /sih -> General -> Comenzi)
function PD.drawGuide(line)
    local cmd = PD.command()
    line(cmd .. " [id]", t("g_pdc"))
    line("/pdh", t("g_pdh"))
    if D.shortcuts == false then return end
    line("/san <id>", t("g_san"))
    line("/sl [id]  /last", t("g_sl"))
    line("/aa /aa50 /aa100", t("g_speed"))
    line("/faruri /car /alc15 /alc30", t("g_road"))
    line("/nos /con /parc /hidra", t("g_road"))
    line("/arme /dr /cdr /matslic /mats", t("g_frisk"))
    line("/nec /run /cat /wdr /notp /comp /nef", t("g_su"))
    line("/mm /cl /tg [id]", t("g_mm"))
    line("// [id]", t("g_nef"))
    line("/ll /potls /patls", t("g_radar"))
    line("/sto  /sta [limita]", t("g_sto"))
    line("/afk [id]  /stopafk", t("g_afk"))
    line("/hdt  /dt", t("g_duty"))
    imgui.PushStyleColor(imgui.Col.Text, C.DIM)
    TW(u8(t("g_note")))
    imgui.PopStyleColor()
end

function PD.drawBottom()
    local sid = PD.sus and PD.sus.id
    local p = sid and PD.people[PD.sus.name] or {}
    local somN = p.som and p.som.n or 0
    local somText = sid and fill(pick(D.say.somatie, PD.langOf(sid)), { name = PD.sus.name, id = sid }) or ""
    local here = PD.nearPoint(D.arrest_points)
    local spacing = imgui.GetStyle().ItemSpacing.x
    if imgui.Button((ctx.State.icons and fa.CAMERA or "F8") .. "##pdshot", imgui.ImVec2(30, 26)) then
        local name = PD.sus and PD.sus.name or "PD"
        ctx.takeScreenshot("PD_" .. name .. (PD.lastAction and ("_" .. PD.lastAction) or ""))
    end
    if imgui.IsItemHovered() then TIP(u8(t("shot_tip"))) end
    imgui.SameLine()
    local w = (imgui.GetContentRegionAvail().x - spacing * 3) / 4
    local somCol = (somN >= 3) and C.OK or (somN > 0 and C.AMBER or nil)
    if ctx.toggleButton(icon("BULLHORN") .. u8(t("somatie") .. " " .. somN .. "/3") .. "##pdbsom", false, imgui.ImVec2(w, 26), somCol, somCol) then PD.summon() end
    if imgui.IsItemHovered() then TIP(u8(t("somatie_tip", somText))) end
    imgui.SameLine()
    if ctx.toggleButton(icon("MAGNIFYING_GLASS") .. u8(t("control")) .. "##pdbctl", false, imgui.ImVec2(w, 26)) then PD.control() end
    imgui.SameLine()
    if ctx.toggleButton(icon("HANDCUFFS") .. u8(t("cuff")) .. "##pdbcuff", false, imgui.ImVec2(w, 26)) then PD.simple("cuff") end
    imgui.SameLine()
    if ctx.toggleButton(u8(t("arrest")) .. "##pdbarr", here ~= nil, imgui.ImVec2(w, 26), here and C.OK or nil) then PD.simple("arrest") end
    if imgui.IsItemHovered() then TIP(u8((here and (t("arrest_here", tostring(here.label)) .. "\n") or "") .. t("arrest_tip"))) end
    local last = Queue.lastSent or t("nothing")
    if #last > 60 then last = last:sub(1, 58) .. ".." end
    TC(C.DIM, u8(last))
end

PD.DRAW_TAB = { "drawRoad", "drawWanted", "drawControl", "drawRadar", "drawDispatch" }

function PD.draw()
    PD.drawHeader()
    imgui.Separator()
    PD.drawSuspect()
    PD.drawStrips()
    imgui.Separator()
    imgui.BeginChild("##pdbody", imgui.ImVec2(0, -(px(26) + imgui.GetTextLineHeightWithSpacing() + 12)), false)
    local fn = PD[PD.DRAW_TAB[PD.tab] or "drawRoad"]
    local ok, e = pcall(fn)
    if not ok then
        if PD.drawError ~= tostring(e) then
            PD.drawError = tostring(e)
            ctx.trace("pd: eroare la desenare: " .. PD.drawError)
        end
        imgui.PushStyleColor(imgui.Col.Text, C.RED)
        TW(u8(PD.drawError))
        imgui.PopStyleColor()
    end
    imgui.EndChild()
    imgui.Separator()
    PD.drawBottom()
end

PD.frame = imgui.OnFrame(function() return ctx.State.focused and (PD.open[0] or PD.fade.alpha > 0) end, function(player)
    player.HideCursor = ctx.State.cursorHeldWithWindow
    local alpha = ctx.Fade.step(PD.fade, PD.open[0])
    local res = imgui.GetIO().DisplaySize
    local x, y = tonumber(cfg.main.pdcX) or -1, tonumber(cfg.main.pdcY) or -1
    local w, h = tonumber(cfg.main.pdcW) or -1, tonumber(cfg.main.pdcH) or -1
    if x < 0 or y < 0 or x >= res.x or y >= res.y then
        imgui.SetNextWindowPos(imgui.ImVec2(res.x - 10, res.y / 2), ctx.App.cond(), imgui.ImVec2(1, 0.5))
    else
        imgui.SetNextWindowPos(imgui.ImVec2(x, y), ctx.App.cond())
    end
    if w < px(380) or h < px(300) then w, h = px(500), px(640) end
    imgui.SetNextWindowSize(imgui.ImVec2(w, h), ctx.App.cond())
    imgui.SetNextWindowSizeConstraints(imgui.ImVec2(px(420), px(360)), imgui.ImVec2(px(1000), px(1000)))

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
    imgui.Begin(u8(t("window")) .. "##pdc", PD.open, imgui.WindowFlags.NoCollapse)
    ctx.State.textInput = imgui.GetIO().WantTextInput
    local pos, size = imgui.GetWindowPos(), imgui.GetWindowSize()
    if math.floor(pos.x) ~= x or math.floor(pos.y) ~= y or math.floor(size.x) ~= w or math.floor(size.y) ~= h then
        cfg.main.pdcX, cfg.main.pdcY = math.floor(pos.x), math.floor(pos.y)
        cfg.main.pdcW, cfg.main.pdcH = math.floor(size.x), math.floor(size.y)
        ctx.State.sicPosDirty = true
    end
    PD.draw()
    imgui.End()
    imgui.PopStyleVar(1)
end)

-- ------------------------------------------------------------
-- TASTE (in /sih -> Bind-uri, grupul "Departamente")
-- ------------------------------------------------------------
PD.ACTIONS = {
    { id = "pdc", label_ro = "Arata / ascunde statia PD", label_en = "Toggle the PD station", short_ro = "Statia PD", short_en = "PD station",
      run = function() PD.toggle() end },
    { id = "pd_radar", label_ro = "Radar: porneste / opreste + find / reia", label_en = "Radar: start / stop + find / resume",
      short_ro = "Radar", short_en = "Radar", hint = "/startradar", run = function() PD.radarToggle() end },
    { id = "pd_near", label_ro = "Suspect = cel mai apropiat jucator", label_en = "Suspect = nearest player",
      short_ro = "Suspect aproape", short_en = "Nearest suspect",
      run = function() local n = ctx.nearestPlayer() if n then PD.setSuspect(n) else ctx.err(ctx.tr("no_near", ctx.K.NEAR_DISTANCE)) end end },
    { id = "pd_som", label_ro = "Somatie suspect (/m)", label_en = "Summon suspect (/m)", short_ro = "Somatie", short_en = "Summon",
      hint = "/m", run = function() PD.summon() end },
    { id = "pd_ms", label_ro = "Somatia serverului (/ms)", label_en = "Server summon (/ms)", hint = "/ms", run = function() PD.serverSummon() end },
    { id = "pd_ctrl", label_ro = "Control de rutina (/frisk)", label_en = "Routine check (/frisk)", short_ro = "Control", short_en = "Check",
      hint = "/frisk", run = function() PD.control() end },
    { id = "pd_cuff", label_ro = "Cuff suspect", label_en = "Cuff suspect", hint = "/cuff", run = function() PD.simple("cuff") end },
    { id = "pd_arrest", label_ro = "Arrest suspect", label_en = "Arrest suspect", hint = "/arrest", run = function() PD.simple("arrest") end },
    { id = "pd_tazer", label_ro = "Tazer", label_en = "Tazer", hint = "/tazer", run = function() Queue.push(D.cmd.tazer or "/tazer") end },
    { id = "pd_wanted", label_ro = "Lista wanted", label_en = "Wanted list", hint = "/wanted", run = function() Queue.push(D.cmd.wanted or "/wanted") end },
    { id = "pd_nearwanted", label_ro = "Wanted in apropiere", label_en = "Nearby wanted", hint = "/nearwanted",
      run = function() Queue.push(D.cmd.nearwanted or "/nearwanted") end },
    { id = "pd_gate", label_ro = "Poarta (cand esti langa)", label_en = "Gate (when next to it)", hint = "/opengate", run = function() PD.gate() end },
}

function PD.addActions(list, byId, binds)
    for _, a in ipairs(PD.ACTIONS) do
        a.group = "pd"
        a.hint = a.hint or PD.command()
        a.show = PD.isDept
        table.insert(list, a)
        byId[a.id] = a
        if binds[a.id .. "_key"] == nil then binds[a.id .. "_key"] = "None" end
        if binds[a.id .. "_on"] == nil then binds[a.id .. "_on"] = 1 end
    end
end

-- ------------------------------------------------------------
-- COMENZI
-- ------------------------------------------------------------
local function argId(arg) return tonumber(tostring(arg or ""):match("^%s*(%d+)")) end

PD.SHORTS = {
    san    = function(a) local id = argId(a) if id then PD.toggle(id) else ctx.usage("/san <id>") end end,
    sl     = function(a) PD.speedLast(argId(a)) end,
    last   = function()
        if #PD.radar.list == 0 then ctx.msg(t("list_empty")) return end
        for i, e in ipairs(PD.radar.list) do
            ctx.msg(string.format("%d. %s  Lv %s  %s  %s", i, ctx.nameTag(e.id, e.name), tostring(e.level or "?"),
                    t("radar_caught_short", e.speed, e.limit, e.over), ago(os.time() - e.at)))
        end
    end,
    aa     = function(a) PD.speed(argId(a), nil, 1) end,
    aa50   = function(a) PD.speed(argId(a), nil, 2) end,
    aa100  = function(a) PD.speed(argId(a), nil, 3) end,
    mm     = function(a) PD.summon(argId(a)) end,
    cl     = function(a) PD.control(argId(a)) end,
    tg     = function(a) PD.gov(argId(a)) end,
    ["/"]  = function(a) PD.nefondat(argId(a)) end,
    afk    = function(a) PD.afk(argId(a)) end,
    stopafk = function() PD.timer = nil end,
    ll     = function() PD.radarAsk() end,
    potls  = function() PD.radarPermit("LS") end,
    potlv  = function() PD.radarPermit("LV") end,
    potsf  = function() PD.radarPermit("SF") end,
    patls  = function() PD.patrolAsk("LS") end,
    patlv  = function() PD.patrolAsk("LV") end,
    patsf  = function() PD.patrolAsk("SF") end,
    hdt    = function() for _, c in ipairs(D.cmd.duty or { "/duty" }) do Queue.push(c) end end,
    dt     = function() Queue.push("/pin") Queue.push("/duty") end,
    sto    = function() PD.radarStop(false) end,
    sta    = function(a)
        local lim = argId(a)
        if lim then cfg.pd.limit = lim end
        PD.radarStart(PD.radar.stage == "stopped")
    end,
}
for short, o in pairs(PD.offByShort) do
    PD.SHORTS[short] = function(a) PD.offence(o.id, argId(a)) end
end
for short, e in pairs(PD.suByShort) do
    PD.SHORTS[short] = function(a) PD.su(e.id, argId(a)) end
end

-- reg = sampRegisterChatCommand; skip = numele deja folosite de helper (le trateaza el)
function PD.register(reg, skip)
    skip = skip or {}
    for _, name in ipairs(D.commands or { "pdc" }) do
        pcall(reg, name, function(arg) PD.toggle(arg) end)
    end
    if D.shortcuts == false then return end
    for name, fn in pairs(PD.SHORTS) do
        if not skip[name] then
            pcall(reg, name, function(arg)
                -- alta factiune: comanda pleaca la server neschimbata, ca si cum helperul n-ar exista
                if not PD.isDept() then
                    local a = tostring(arg or "")
                    Queue.push("/" .. name .. (a ~= "" and (" " .. a) or ""))
                    return
                end
                fn(arg)
            end)
        end
    end
end

-- /info: butoanele de jos pentru un departament (in locul celor de instructor)
function PD.infoButtons(id, name)
    local bw = (imgui.GetContentRegionAvail().x - imgui.GetStyle().ItemSpacing.x * 3) / 4
    if ctx.primaryButton(u8(t("suspect")) .. "##ipds", imgui.ImVec2(bw, 24)) and id then PD.setSuspect(id) PD.open[0] = true end
    imgui.SameLine()
    if ctx.toggleButton(u8(t("control")) .. "##ipdc", false, imgui.ImVec2(bw, 24)) and id then PD.control(id) end
    imgui.SameLine()
    if ctx.toggleButton(u8(t("somatie")) .. "##ipdm", false, imgui.ImVec2(bw, 24)) and id then PD.summon(id) end
    imgui.SameLine()
    if ctx.toggleButton(u8(ctx.tr("info_copy")) .. "##ipcp", false, imgui.ImVec2(bw, 24)) then
        imgui.SetClipboardText(name)
        ctx.msg(ctx.tr("notes_copied", name))
    end
end

-- tab-ul Tutorial din /sih, pentru departamente: regulile scurte, pe grupuri
function PD.drawTutorial()
    local set = (D.rules or {})[cfg.main.uiLang] or (D.rules or {}).ro or {}
    local groups = { { "road", "tab_road" }, { "wanted", "tab_wanted" }, { "control", "tab_control" }, { "radar", "tab_radar" } }
    for i, g in ipairs(groups) do
        local lines = set[g[1]]
        if lines and imgui.CollapsingHeader(u8(t(g[2])) .. "##pdtut" .. i, (i == 1) and imgui.TreeNodeFlags.DefaultOpen or 0) then
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Text, C.TEXT)
            for _, line in ipairs(lines) do imgui.Bullet() TW(u8(line)) end
            imgui.PopStyleColor()
            imgui.Spacing()
        end
    end
end

function PD.tags() return D.player_tags end

return PD
end
