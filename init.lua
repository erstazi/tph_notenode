--[[
(C) TPH/tph9677/TubberPupperHusker/TubberPupper/Damotrix
MIT License
https://opensource.org/license/mit

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

local amn = core.get_current_modname() -- active mod's name
-- `amn` should be `tph_notenode` - unless you've changed the `mod.conf`
local amnpf = amn..":" -- intended for prefix

-- get_current_modname but provides a string on nil
local function get_cmn()
    return core.get_current_modname() or "??"
end

-- quicker than `string..string2`, uses `table.concat`
-- `sep` can be nil or string, intended for the "separator" argument of `table.concat`
local function csg(sep, ...) -- `concat_strings`, shortened
    sep = type(sep) == "string" and sep or ""
    return table.concat({...}, sep)
end

-- used to quickly make an unwritable metatable data
-- indexing is a table to be indexed
-- indexingdesc is the name/description of the table (unnecessary to provide if errmsg is specified)
-- errmsg is not required if indexingname is specified
-- IF hastables (has table values), then clone for pairs() functionality
local function create_unwritable(indexing, indexingdesc, errmsg, hastables)
    errmsg = errmsg or csg(" ", "writing to", indexingdesc, "is unsupported")
    errmsg = csg(" ", amnpf, errmsg) -- prefix
    return setmetatable({},{
        __index = function(t, key)
            return indexing[key]
        end,
        __newindex = function(t, key, value)
            error(csg(" ", "Blocked write from mod:", get_cmn()) )
        end,
        -- use https://content.luanti.org/packages/TPH/metatable_metamethods/ for iteration
        -- indexing has table values, ensure to return a copy instead!
        __pairs = hastables and function(t)
            return pairs( table.copy(indexing) )
        end or
        -- doesn't have table values, just do as normal
        function(t)
            -- won't return actual table, so can't be modified
            return pairs(indexing)
        end
    })
end

tph_notenode = {}

-- translator functionality
local S = core.get_translator(amn)

-- mod support
-- these are only ever used as truthy and should not be used for non-boolean purposes
local depends = {
    -- games
    default = core.get_modpath("default"), -- minetest, mesecraft
    mineclonia = core.get_modpath("mcl_redstone"),
    voxelibre = core.get_modpath("mcl_sounds"),
    nodecore = core.get_modpath("nc_optics"),
    exile = core.get_modpath("minimal") and core.get_modpath("crafting") and core.get_modpath("tech"),
    aom = core.get_modpath("aom_wire"), -- age of mending
    hades = core.get_modpath("hades_core"),
    rpx = core.get_modpath("rp_default"), -- repixture
    -- mods
    mesecons = core.get_modpath("mesecons"),
    ncbells = core.get_modpath("ncbells"), -- nodecore bells
    aom_sounds = core.get_modpath("aom_sounds") -- possibly not always included?
}

depends.exilev4 = depends.exile and core.get_modpath("mapchunk_shepherd")

local NLC = (depends.nodecore or depends.exile or depends.aom or depends.rpx) and true or false -- non-luanti crafting
depends.NLC = NLC

-- add to tph_notenode for mod usage, prevent writing
-- indexing, indexingname, errmsg
tph_notenode.depends = create_unwritable(depends, nil,
  "writing to depends table is unsupported. Please contact TPH or the mod author for adding new depends.")


-- notes 1 to 12
local notenames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
-- for use by noteparticle function
local notecolours = {"#ff0000","#ff8000","#ffff00","#80ff00","#00ff00","#00ff80","#00ffff", -- C - F
  "#0080ff","#0000ff","#7f00ff","#ff00ff","#ff0080"} -- F# to B

-- make notesdata metatable
do
    local notesdata = {}
    -- notes 1 to 12 (C to B), indexed in such a way
    notesdata.names = create_unwritable(notenames, "notesdata.names")
    -- colours associated to the named notes
    notesdata.colours = create_unwritable(notecolours, "notesdata.colours")
    -- now to metatable notesdata
    tph_notenode.notesdata = setmetatable({}, {
        __index = function(t, key)
            local value = key == "names" and notenames or
              key == "colours" and notecolours or
              notesdata[key]
            return type(value) == "table" and table.copy(value) or value
        end,
        __newindex = function(t, key, value)
            error(csg(" ", amnpf, "writing to notesdata table is unsupported. Blocked write from mod:",
              get_cmn()) )
        end,
        -- use https://content.luanti.org/packages/TPH/metatable_metamethods/ for iteration
        __pairs = function(t)
            -- return copy as we have tables that CAN be modified
            return pairs( table.copy(notesdata) )
        end
    })
end

-- colours that we let external API modify
local modifiablecolours = {
    -- for - and + symbols - red and green
    minus = "#de1c02", plus = "#02de19"
}
-- make metatable for changing modifiable colours
do
    tph_notenode.colours = setmetatable({}, {
        __index = function(t, key)
            return modifiablecolours[key]
        end,
        -- ensure purification of passed colour value
        -- must be hex (can be without hash or be incompleted)
        __newindex = function(t, key, value)
            if not modifiablecolours[key] then return end -- fail, can't add new colours
            if type(value) ~= "string" then
                error(csg("", amnpf, " attempting to set colour '",key,"' to non-string type: '",type(value),"'. ",
                  "Blocked write from mod: ", get_cmn() ) )
            end
            -- add # if not exist at first index
            if value:sub(1,1) ~= "#" then
                value = csg("", "#", value)
            end
            -- get length of value
            local vallen = #value
            -- too long! clip it!
            if vallen > 9 then
                value = value:sub(1, 9)
            end
            -- too short, add some f's
            if vallen < 7 then
                for i=vallen, 6 do
                    value = csg("", value, "f")
                end
            -- you were TRYING to make a transparency but oof'd it!
            elseif vallen == 8 then
                value = csg("", value, "f")
            end
            -- ensure proper value
            -- $ means string must start with hash
            -- square brackets are used to individualize sequences
            -- %d means any number
            -- letters afterwards mean any of those individual characters
            -- + means matching 1 or more in any of said places
            local proper = value:match("[$#][%dabcdef]+")
            -- if does not equal, there was a problem houston!
            if value ~= proper then
                error(csg("", amnpf, " issue setting colour '",key,"'. Invalid hex parameters ",
                  "(uses more letters than f - or uppercase letters, or has other non-numbers). Got '", value,
                  "'. Blocked write from mod: ", get_cmn() ) )
            end
            -- NOW to ACTUALLY set it!
            modifiablecolours[key] = value
        end,
        -- use https://content.luanti.org/packages/TPH/metatable_metamethods/ for iteration
        __pairs = function(t)
            -- won't return actual table, so can't be modified
            return pairs(modifiablecolours)
        end
    })
end




-- registered unique instruments
local instruments = {} -- raw data
-- public access variant of the above
local public_instruments = {}

-- lowers the priority of all base instruments by 3 if an external mod registers an instrument
local lpoem -- lower priority on external mod
lpoem = function()
    for name, data in pairs(instruments) do
        local cprty = data.choice_priority
        cprty = cprty or 0
        data.choice_priority = cprty + 3
    end
    lpoem = nil -- erase ourself now that we've done this
end

-- setting a metatable prevents iteration
tph_notenode.registered_instruments = create_unwritable(public_instruments)

-- list of instruments to play for specific groups
local playing_groups = {}
-- make a protected metatable
tph_notenode.playing_groups = create_unwritable(playing_groups, "playing_groups")

------------------------------------------
-- register an instrument

-- name can be nil as it can be derived from sound file's name minus the mod's name

-- def can be the sound file string, otherwise must be a table with `sound` as an index

-- groups is a custom table of group names, used to check the node below to determine what instrument ot play

-- noteC is a custom table to be used for providing the hertz of the middle C
-- noteC is not required and will be set automatically otherwise

local function register_instrument(name, def, groups, noteC)
    name = type(name) == "string" and name or "unknown"
    -- basic definition (requires sound)
    def = type(def) == "string" and {sound=def} or type(def) == "table" and def
    if not (def and type(def.sound) == "string") then
        error(csg("", amnpf, " instrument '", name, "' lacks a sound! Please provide a sound file as 2nd parameter",
          " or as the 'sound' index in definition"))
    end
    def.mod_origin = core.get_current_modname()
    -- be weird and derive name from sound
    name = name == "unknown" and def.sound:gsub(def.mod_origin.."_","") or name
    -- if found in instruments, do error
    if instruments[name] then
        error(csg("", amnpf, " '",name,"' is an already registered instrument! Please name your instrument something else."))
    end
    -- volume
    def.gain = type(def.gain) == "number" and def.gain or type(def.vol) == "number" and def.vol
    if def.vol then def.vol = nil end -- remove vol from definition
    -- if def.gain, check if over 0, then be gain or default to 0.6
    def.gain = def.gain and def.gain > 0 and def.gain or 0.6
    -- noteC (middle C note)
    noteC = type(noteC) == "table" and noteC or {}
    -- hertz! be sure you properly tune it to be C!
    noteC.hertz = type(noteC.hertz) == "number" and (noteC.hertz > 0 and noteC.hertz) or 261.6256
    noteC.octave = type(noteC.octave) == "number" and noteC.octave or 1
    noteC.val, noteC.num = 1, 1 -- actual pitch, note ID
    -- create other base notes (positive pitch)
    noteC.name = "C"
    local basenotes = {}
    basenotes[1] = table.copy(noteC)
    -- calculate each note in scale
    for i=2,12 do
        local name = notenames[i]
        -- hertz calculation is middle C * 2^(semitone/12)
        -- https://en.wikipedia.org/wiki/Musical_note#Pitch_frequency_in_hertz
        local info = {hertz = noteC.hertz * 2^((i-1)/12), octave=noteC.octave, name=name, num = i}
        info.val = info.hertz/noteC.hertz
        basenotes[#basenotes + 1] = info -- add to list
    end
    def.basenotes = basenotes -- list of notes to be used as a base (base octave)
    -- produce octave range and specific octaves
    -- use positive integers to determine how low and high the octave range should be
    -- for lower, will be subtracted from middle octave, for higher, will be added to middle octave
    -- use math.abs and math.ceil to prevent negative numbers and only permit integers
    -- use math.min to clamp below a difference of 10
    local octrange = def.octrange or def.octave_range or {}
    -- lower octave (default: -2) -- ensure you use a positive number when defining it though!
    octrange[1] = type(octrange[1]) == "number" and math.min(math.abs(math.ceil(octrange[1])), 10) or 2
    -- higher octave (default: +2)
    octrange[2] = type(octrange[2]) == "number" and math.min(math.abs(math.ceil(octrange[2])), 10) or 2
    -- fill the notes
    -- there can only be a total of 252 notes, below param2's max of 256
    local notes = {}
    -- lower fill
    if octrange[1] ~= 0 then
        for i=octrange[1],1,-1 do -- go down
            local oct = noteC.octave - i -- octave for this particular round
            for _,note in ipairs(basenotes) do
                -- hertz is base hertz divided by 2 ^ i times
                -- repeat note name and add current octave to octave
                local new = {hertz=note.hertz/(2^i), name=note.name, octave=oct, num=note.num} -- new note
                new.val = new.hertz/noteC.hertz -- calculate val (for pitch modification)
                notes[#notes + 1] = new
            end
        end
    end
    -- middle fill
    for _,note in ipairs(basenotes) do
        notes[#notes + 1] = table.copy(note)
    end
    -- higher fill
    if octrange[2] ~= 0 then
        for i=1, octrange[2] do -- go up
            local oct = noteC.octave + i -- ditto
            for _,note in ipairs(basenotes) do
                -- hertz is base hertz times 2 ^ i
                -- ditto
                local new = {hertz=note.hertz*(2^i), name=note.name, octave=oct, num=note.num} -- new note
                new.val = new.hertz/noteC.hertz -- calculate val (for pitch modification)
                -- engine doesn't support pitches over 10x, break production
                if new.val > 10.2 then
                    -- cap octave range
                    octrange[2] = octrange[2] - (octrange[2] - i)
                    break
                end
                notes[#notes + 1] = new
            end
        end
    end
    -- finally calculate octave range
    octrange[1] = noteC.octave - octrange[1]
    octrange[2] = noteC.octave + octrange[2]
    -- figure out groups if specified
    groups = type(groups) == "string" and {groups} or groups
    -- add to playing_groups
    if type(groups) == "table" then
        -- choice priority (higher numbers = less likely to be picked if a lower number or none exists)
        local lowprty = groups.lowprty
        if lowprty then
            def.choice_priority = lowprty
            groups.lowprty = nil
        end
        -- iterate through specified groups
        for _,grpname in ipairs(groups) do
            -- play this instrument for this group
            -- as long as it doesn't start with `tph_notenode` (active mod name, AMN)
            if type(grpname) == "string" and grpname:sub(1,12) ~= amn then
                local oldstrument = playing_groups[grpname] -- if another instrument exists here
                oldstrument = oldstrument and instruments[oldstrument]
                -- we'll be replacing the group's instrument with ours
                -- make a warn log
                if oldstrument then
                    core.log("warn", csg("", "tph_notenode: replacing instrument '", oldstrument,
                      "' with '", name, "' for group '", grpname, "'") )
                end
                -- add or replace the group with ourselves
                playing_groups[grpname] = name
            end
        end
    end
    -- add ourself to playing groups
    local instgrpname = csg("", amn, "_", name) -- instrument group name
    playing_groups[instgrpname] = name
    -- low priority mechanics
    def.choice_priority = type(def.choice_priority) == "number" and def.choice_priority > 0 and def.choice_priority or
      nil
    -- clear some stuff
    def.octrange = nil
    -- finalizing
    def.notes = notes
    def.name = name
    def.octave_range = octrange
    instruments[name] = def
    -- create a "public definition" to prevent any potential overwrites while allowing instrument access
    -- make this public definition unwritable
    public_instruments[name] = setmetatable({}, {
        __index = function(t, key)
            local value = def[key]
            -- copy table to prevent modifications due to Lua 5.1 issues with length getting and iterating
            return type(value) == "table" and table.copy(value) or value
        end,
        __newindex = function(t, key, value)
            error(csg("", amnpf," registered_instruments violation; not permitted to write to '", name,
              "' instrument. Blocked write from mod: ", get_cmn()) )
        end,
        -- use https://content.luanti.org/packages/TPH/metatable_metamethods/ for iteration
        __pairs = function(t)
            -- has table values that can be modified, return copy!
            return pairs( table.copy(def) )
        end
    })
    -- lower the priority of all base instruments by 3
    -- if an external mod uses the register_instrument functionality
    if def.mod_origin ~= amn and lpoem then
        lpoem()
    end
end

-- need this because the good 'ol `ipairs` doesn't like it when something is false for some reason (or whatever is going on??)
-- whatever it is, it doesn't like my `depends.something and "thisthing"`
-- just better automates the `register_instrument` groups parameter that I use below
-- has `lowprty` argument to shorten the need to type out `choice_priority`
--- adequately and reliably permits boolean argument strings in the creation of a numbered array
--- used for creating playing groups for an instrument reliably
--- @param lowprty? number|string optional, if specified (as number), indicates instrument's priority below other instruments (the higher, the less priority)
local function cigt(lowprty, ...) -- create instrument groups table
    local groups = {}
    local params = {...} -- turn it into a table!!!
    -- just another parameter (not a number, a string!), add to params
    if type(lowprty) == "string" then
        table.insert(params, 1, lowprty)
        lowprty = nil -- and erase
    end
    -- had a note about not using ipairs, seems to be fine now??
    for _,param in ipairs(params) do
        -- only add to numbered index table if a string
        if type(param) == "string" then
            groups[#groups + 1] = param
        end
    end
    -- add low priority if number
    if type(lowprty) == "number" then
        groups.lowprty = lowprty
    end
    -- using these
    return groups
end
-- namespace
tph_notenode.create_instruments_group_table = cigt

-- name, groups, noteC
-- name can be nil and grabbed from sound, groups is expected to be filled with group strings, noteC can be nil
-- sound can be a definition table, if so, must have {sound=sound_name}
-- lowprty can be specified in groups for it to be overriden by another instrument in choice making

-- simple bling-like synthy sound, springy (made from a spring inside of a mouse)
register_instrument(nil, "tph_notenode_donk") -- base instrument
-- clacky kinda sound (made from scratching a plastic battery pack)
-- was "klalk"
register_instrument(nil, "tph_notenode_clack", "glass")
-- metallic-ish sound (made from hitting a metal pole)
-- was "couke"
register_instrument(nil, "tph_notenode_metal", cigt(3, "metal", "metallic", "lodey",
  "ironstone", depends.rpx and "ingot"))
-- weird artificial bassy sound (made from hitting the top of a nutella plastic lid)
-- was "dwoite"
register_instrument(nil, {sound="tph_notenode_tin", vol=1}, cigt("refined_tin", depends.nodecore and "adobe"))
-- wobbly bassy song (made from playing a spread-out shoelace)
-- was "bvogne"
register_instrument(nil, {sound="tph_notenode_stringbass", vol=1}, cigt(6, "tree", "log"))
-- simple hit sound (made from dragging a finger across a zipper)
-- was "blipck"
register_instrument(nil, {sound="tph_notenode_stone", vol=1}, cigt(12, "stone", "material_stone", "boulder",
  "cobble", "ore", depends.exile and "masonry"))
-- bamboo-y (made from hitting actual bamboo)
-- was "ghlick"
register_instrument(nil, {sound="tph_notenode_bamboo", gain=1}, cigt("sapling", "bamboo_block", "woody_plant"))
-- watery (made from moving around in a bathtub of water)
-- was "llorlk"
register_instrument(nil, {sound="tph_notenode_water", vol=0.8}, "water")
-- air-y (made from blowing into a glass bottle, 2x pitch)
-- was "oouve"
register_instrument(nil, "tph_notenode_bottleflute", cigt("clay", "flutey"))
-- bell-ish (made from flicking at a glass bottle)
-- was "gliurk"
register_instrument(nil, "tph_notenode_xylophone", cigt("refined_gold", depends.aom and "gilded"))
-- soft mallet/pluck sound (made from pulling finger tightly out of a glass bottle)
register_instrument(nil, "tph_notenode_doap", cigt("rail", "pumpkin", depends.aom and "item_arlior_growth",
  depends.aom and "item_arlior_growth_purple"))
-- metallic clank sound/cowbell-ish (made from softly banging two ceramic bowls together)
-- was "claen"
register_instrument(nil, "tph_notenode_bowlhit", cigt("ice", "pottery", depends.aom and "terracotta"))
-- whistley sound (made from me blowing a whistly sound with my mouth)
-- was "mwuu"
register_instrument(nil, "tph_notenode_airwhistle", "air")
-- papery percussion sound, snare-ish (made from me hitting a paper recyclable bag)
-- was "ktaut"
register_instrument(nil, {sound="tph_notenode_snarepaper", vol=0.4}, cigt("gravel", "item_gravel"))
-- metallic twang kinda sound, made from flicking at a small cooking pot
-- was "tintling"
register_instrument(nil, "tph_notenode_metallictwang", "copper")
-- synthetic ding/telephone-like sound (made from banging bits of my thermos and heavy editing)
-- was "pbauve"
register_instrument(nil, {sound="tph_notenode_sonar", vol=0.4}, cigt("snowy", "snow"))
-- metal whack sound, like a "celeste at home" (made from banging metal coathangers together)
-- was "shieng"
register_instrument(nil, {sound="tph_notenode_metallicpile", vol=0.35}, depends.aom and {"granite"})
-- guitar-y - similar to bvogne (made from playing a strand of falling-apart sock)
-- was "dvogne"
register_instrument(nil, {sound="tph_notenode_string", vol=1}, cigt(8, "material_wood", "wood", "planks"))
-- soft brassy trumpet-ish sound (made from shaping a blowing of air with my mouth)
-- was "oauwre"
register_instrument(nil, "tph_notenode_hornsoft", cigt(3, "flora", "fibrous_plant", depends.rpx and "plant"))
-- ringing chime/bell sound (made from finger-flicking a small iron horseshoe)
-- was "taong"
register_instrument(nil, "tph_notenode_bell", cigt("chime", depends.aom and "scaffolding"))
-- bassy organ-like sound (made from me humming weirdly, but heavily edited)
-- was "bvauouve"
register_instrument(nil, "tph_notenode_organ", cigt("coalblock", "coalstone", "organ", depends.aom and "item_compost"))
-- sawtooth sound (made from me humming with my teeth, heavily edited)
-- was "bveap"
register_instrument(nil, "tph_notenode_sawtooth", cigt("meseblock", depends.aom and "glow_rock",
  depends.nodecore and "lux_emit"))
-- game-specific instruments
if depends.exile then
    register_instrument("exilebell", "artifacts_bell")
end
if depends.exilev4 then
    register_instrument("exilesingstone", "artifacts_singing_stone", {hertz=260})
end
-- mod-specific instruments
if depends.ncbells then
    register_instrument("ncbell",
      {sound="ncbells_ding",
      -- low, high
      octrange={4,3}
      })
end

-- add to global
tph_notenode.register_instrument = register_instrument

-- for debugging purposes, gets notenodes to ONLY play notes within a certain chord
local chords = {
    Cm = {"C", "D", "D#", "F", "G", "G#", "A"},
    ["C#m"] = {"C#", "D#", "E", "F#", "G", "A", "B"},
    Dm = {"D#","F,","F#","G#","A#","B","C#"},
    allhash = {"C#", "D#", "F#", "G#", "A#"},
    whole = {"C", "D", "E", "F", "G", "A", "B"},
    tetris = {"A", "B", "C", "D", "E", "F"},
}

local default_instrument = "donk"

-- pos, node, and ndef must be what is BELOW the note node
-- node definition is the only requirement but yea
--- returns instrument table on success, otherwise nil on failure
--- @param pos? vector3 not required if node or ndef are provided, position of node to grab instrument from
--- @param node? table not required if position or ndef is provided, core.get_node result of pos
--- @param ndef? table not required if position or node is provided, registered node table of node to grab instrument from
local function get_instrument_raw(pos, node, ndef)
    if not (ndef or node) then
        node = node or core.get_node(pos)
    end
    ndef = ndef or node and core.registered_items[node.name]
    if not ndef then return end
    -- will play any instrument specified and if said instrument exists
    do
        -- prioritized
        local foundstrument = tph_notenode.registered_instruments[ndef.tph_notenode_instrument] -- found instrument
        if foundstrument then
            return foundstrument
        end
    end
    -- could not find a specified instrument, aight!
    -- check groups
    local groups = ndef.groups
    if type(groups) ~= "table" then return end -- oops, no groups, no instrumento!
    local cinstrument -- chosen instrument
    for grpname, grpnum in pairs(groups) do
        local instrument = playing_groups[grpname] -- instrument name
        -- only set playing instrument if found successfully
        if instrument and grpnum > 0 then
            instrument = tph_notenode.registered_instruments[instrument] -- get actual instrument definition
            -- no chosen instrument yet
            if not cinstrument then
                cinstrument = instrument
            end
            -- old (low) priority, current (low) priority
            local oprty, cprty = cinstrument.choice_priority, instrument.choice_priority or 0
            -- not to continue looking for more instruments if no low priority specified, break
            if cprty == 0 then
                return instrument -- we choose the one with no low priority specified (higher priority)
            end
            -- replace with higher priority (lower number)
            if cprty < oprty then
                cinstrument = instrument
            end
        end
    end
    return cinstrument
end
-- added so that you can do more specific functionality - but `tph_notenode.get_instrument` is more recommended
tph_notenode.raw_get_instrument = get_instrument_raw

-- ditto to the above function, except this returns a default instrument on failure
--- utilizes raw_get_instrument function to get instrument table, except returns default instrument on failure to retrieve
--- @param pos? vector3 not required if node or ndef are provided, position of node to grab instrument from
--- @param node? table not required if position or ndef is provided, core.get_node result of pos
--- @param ndef? table not required if position or node is provided, registered node table of node to grab instrument from
local function get_instrument(pos, node, ndef)
    local inst = get_instrument_raw(pos, node, ndef)
    if not inst then
        -- get default instrument
        inst = tph_notenode.registered_instruments[default_instrument]
        -- add a new default instrument in case of failure
        if not inst then
            default_instrument = next(instruments)
            inst = tph_notenode.registered_instruments[default_instrument]
        end
    end
    return inst
end
-- you should ONLY use this for getting an instrument (as it provides default on failure)
tph_notenode.get_instrument = get_instrument


--- spawns a little eighth note above position, y position and colour can be adjusted
--- @param pos vector3 position to spawn note at
--- @param note? table note table containing valid 'num' and 'octave', not required for producing particle
--- @param instrument? table instrument table containing valid 'basenotes', required for octave-dependent colour shading, requires note table being provided
--- @param y? number how much to add to Y axis to position, defaults to 0.75 if not specified
--- @param colour? string if provided, must be hexadecimal colour string
--- @param plusminus? boolean if true, add a + symbol, if false, add a - symbol, otherwise do not add one
local function noteparticle(pos, note, instrument, y, colour, plusminus)
    pos = vector.new(pos)
    pos.y = pos.y + (type(y) == "number" and y or 0.75)
    -- randomize position to prevent zindex fighting
    local range = 100
    pos.x, pos.z = pos.x + (math.random(-range,range)/1000), pos.z + (math.random(-range,range)/1000)
    local texture = "tph_notenode_note_eighth.png"
    -- figure out colour (if provided, needs to be hex colour)
    colour = type(colour) == "string" and colour:sub(1,1) == "#" and
      -- regular or alpha colour variants only
      (#colour == 7 or #colour == 9) and colour or nil
    local has_note = type(note) == "table" -- close enough
    -- derive colour from note's num (which should be between 1 and 12!)
    if (has_note and note.num) and not colour then
        colour = notecolours[note.num]
    end
    -- format
    colour = colour and csg("", "^[multiply:", colour) or nil
    -- check instrument (ONLY IF COLOUR EXISTS AND NOTE HAS OCTAVE)
    if colour and has_note and type(note.octave) == "number" then
        instrument = type(instrument) == "string" and tph_notenode.registered_instruments[instrument] or instrument
        -- instrument must be a table with a `basenotes` table - of which must have a number octave
        instrument = type(instrument) == "table" and
          (type(instrument.basenotes) == "table" and type(instrument.basenotes[1]) == "table" and
          type(instrument.basenotes[1].octave) == "number") and instrument or nil
        -- add darkness or lightness!
        if instrument and colour then
            -- get octaves
            local octave, midoctave = note.octave, instrument.basenotes[1].octave
            -- only add to if octave does not equal mid octave (base octave)
            if octave ~= midoctave then
                local divideby = midoctave+10
                -- higher, add lightness
                if octave > midoctave then
                    octave = octave-midoctave -- difference between octave and base octave
                    octave = math.ceil(200*(octave/divideby)) -- round up
                    colour = csg("", colour, "^[colorize:#ffffff:", octave)
                -- lower, add darkness
                elseif octave < midoctave then
                    octave = midoctave - octave
                    octave = math.ceil(200*(octave/divideby))
                    colour = csg("", colour, "^[colorize:#000000:", octave)
                end
            end
        end
    end
    -- add to texture now
    texture = csg("", texture, colour)
    -- add symbol if boolean
    if type(plusminus) == "boolean" then
        texture = csg("", texture, "^(",
          -- do + symbol and colouration
          plusminus and csg("", "tph_notenode_plus.png^[multiply:", modifiablecolours.plus)
          -- do - symbol and colouration
          or csg("", "tph_notenode_minus.png^[multiply:", modifiablecolours.minus), ")")
    end
    -- add particle!
    core.add_particle({
        pos = pos,
        texture = texture,
        size = 6,
        -- vertical, glow, lifetime
        vertical = true,
        glow = 10,
        expirationtime = 0.5,
        -- up and still
        velocity = {x=0, y=2, z=0},
        drag = {x=0, y=7, z=0},
    })
end
-- add to global
tph_notenode.produce_note_particle = noteparticle


--- convert raw node param2 to a tangible playable note table
--- @param param2 table core.get_node() table's param2
--- @param instrument table|string instrument name/table, table containing 'notes'
local function get_note(param2, instrument)
    if type(param2) ~= "number" then
        error("tph_notenode.convert_param2_to_note: provided param2 is NOT a number! "..type(param2))
    end
    -- instrument should be the instrument you get from `tph_notenode.registered_instruments`
    instrument = type(instrument) == "string" and tph_notenode.registered_instruments[instrument] or instrument
    -- errors
    if type(instrument) ~= "table" then
        error("tph_notenode.convert_param2_to_note: provided instrument (table/string name) does not exist! "..dump(instrument))
    end
    if type(instrument.notes) ~= "table" then
        error("tph_notenode.convert_param2_to_note: instrument lacks 'notes' table. Error with "..
          (type(instrument.name) == "string" and instrument.name or dump(instrument)) )
    end
    -- instrument notes, will be used for clamping
    local instnotes = instrument.notes
    local notesamt = #instnotes -- notes amount (amount of notes)
    -- no numbered indexes, you gave me a faulty one!
    if not notesamt then
        error("tph_notenode.get_node: instrument's notes does NOT have numbered indexes! Error with "..
          (type(instrument.name) == "string" and instrument.name or dump(instrument)) )
    end
    if not notesamt then return end -- no numbered indexes, you gave me a faulty one!
    -- +1 as lua tables start with 1 not 0
    param2 = param2 + 1
    -- clamp param2
    local clamped -- 2nd return, tells you which way it was clamped to
    -- too low, start high
    if param2 < 1 then
        param2 = notesamt
        clamped = "high" -- was too low, clamped to high!
    -- too high, start low
    elseif param2 > notesamt then
        param2 = 1
        clamped = "low" -- was too high, clamped to low!
    end
    -- should never be nil unless you messed up your copy of the instrument
    -- 2nd return "clamped" is either "high", "low", or nil if it wasn't clamped
    return instnotes[param2], clamped
end

-- if given a param2 and instrument (or instrument name), returns playable note
tph_notenode.convert_param2_to_note = get_note


--- convert note table back to param2
--- @param note table note table containing valid 'octave' and 'num'
--- @param instrument table|string instrument name/table, table containing valid 'octave_range' and 'notes'
local function convert_note(note, instrument)
    instrument = type(instrument) == "string" and tph_notenode.registered_instruments[instrument] or instrument
    -- oops!
    if type(note) ~= "table" then
        error("tph_notenode.convert_note_to_param2: provided note is NOT table! "..type(note))
    end
    if type(instrument) ~= "table" then
        error("tph_notenode.convert_note_to_param2: provided instrument does not exist! (string name, or needs to be table)")
    end
    local instnotes = instrument.notes -- instrument notes
    local octrange = instrument.octave_range
    -- oops! x2
    if type(note.octave) ~= "number" then
        error("tph_notenode.convert_note_to_param2: provided note table does not have an 'octave' number! "..type(note.octave))
    end
    if not (type(instnotes) == "table" and type(octrange) == "table") then
        error("tph_notenode.convert_note_to_param2: provided instrument does not have 'notes' or 'octave_range'!")
    end
    -- clamp octave
    -- too low, go to first note's param2 equivalent
    if note.octave < octrange[1] then
        return 0
    -- too high, go to last note and subtract for proper param2
    elseif note.octave > octrange[2] then
        return #instnotes-1
    end
    local param2 = 0 -- always return a number
    -- iterate over instrument's notes to match
    for ind,snote in ipairs(instnotes) do -- index, selected note
        if snote.octave == note.octave and snote.num == note.num then
            param2 = ind-1 -- subtract 1 for a proper param2
        end
    end
    return param2
end

-- if given a note table and an instrument, returns a saveable param2
tph_notenode.convert_note_to_param2 = convert_note

----------
-- more node-ish functions

-- requires 5.5+ because of vector functions
--- get cartesian coordinate in string (-X, +X, -Z, +Z, -Y, +Y), Y will be upwards-downwards, from pointed_thing
--- @param pointed_thing table pointed_thing produced by node callbacks
local function get_pointed_thing_node_face(pointed_thing)
    -- get our informative errors out of the way
    if type(pointed_thing) ~= "table" then
        error("tph_notenode.get_pointed_thing_node_face: given improper pointed thing, not a table! Type: "
          ..type(pointed_thing))
    end
    -- bad, BAD!
    if pointed_thing.type ~= "node" then
        error("tph_notenode.get_pointed_thing_node_face: pointed thing is NOT a node!")
    end
    -- how, how did you screw this up???
    if not (pointed_thing.under and pointed_thing.above) then
        error("tph_notenode.get_pointed_thing_node_face: pointed thing lacks under and above positions")
    end
    -- shorthand for comparison
    local pos = pointed_thing.under
    -- figure out face position
    local face = (pointed_thing.above + pos)/2
    -- GET *the* face!
    face = face.x == (pos.x - 0.5) and "-X" or face.x == (pos.x + 0.5) and "+X" or
      face.z == (pos.z - 0.5) and "-Z" or face.z == (pos.z + 0.5) and "+X" or
      face.y == (pos.y - 0.5) and "-Y" or face.y == (pos.y + 0.5) and "+Y"
    -- oops
    if not face then
        error("tph_notenode.get_pointed_thing_node_face: improper under and above positions for pointed_thing"..
          ", could not get face")
    end
    return face
end
-- so you can use this too for auxiliary purposes!!! :3
tph_notenode.get_pointed_thing_node_face = get_pointed_thing_node_face


--- get whether or not provided "thing" value translates to a treble or bass clef, with options for "bottom" and "top"
--- @param thing table expected pointed_thing table, but can be string result from get_pointed_thing_node_face
--- @param clefonly? boolean if true, do not return "bottom" or "top", instead returning nil
local function get_clef_from_pointed_thing(thing, clefonly)
    -- permit result from above function (string)
    if type(thing) ~= "string" then
        -- don't wanna do crashing errors in this household
        local success, errinfo = pcall(function()
            thing = get_pointed_thing_node_face(thing)
            thing = thing:lower()
        end)
    end
    -- couldn't get a face
    if type(thing) ~= "string" then return end
    -- figure out clef now! and return!
    return (thing == "-x" or thing == "-z") and "treble" or
      (thing == "+x" or thing == "+z") and "bass" or
      -- return top or bottom if clefonly isn't specified
      not clefonly and (thing == "-y" and "bottom" or thing == "+y" and "top") or
      nil
end
-- so that you can check too!
tph_notenode.get_clef_from_pointed_thing = get_clef_from_pointed_thing

--------------------------------
-- CREATING THE NOTENODE NODE

-- getting placement sounds for notenode, and instrumental device (if is_device is true)
-- needing different sound-getting functionality for each game
local function get_node_sound(is_device)
    -- nil dig sound to prevent disruption of instrument notes
    local sound = {dig={name=""}}
    -- now to see what we should do
    if (depends.voxelibre or depends.mineclonia) then -- MC-likes
        -- metallic sounds for instrumental device
        return is_device and mcl_sounds.node_sound_metal_defaults(sound) or
          mcl_sounds.node_sound_wood_defaults(sound)
    elseif depends.nodecore then
        sound = nc.sounds( (is_device and "nc_lode_tempered" or "nc_tree_woody"))
        sound.dig = nil
        return sound
    -- minetest and some others
    elseif depends.default then
        return is_device and default.node_sound_metal_defaults(sound) or
          default.node_sound_wood_defaults(sound)
    -- exile
    elseif depends.exile then
        -- get metal sound if it exists, otherwise stone sound for device
        -- wooden sound for notenodes
        return is_device and (tech.node_sound_metal_defaults and tech.node_sound_metal_defaults(sound) or
          nodes_nature.node_sound_stone_defaults(sound)) or
          nodes_nature.node_sound_wood_defaults(sound)
    -- age of mending
    elseif depends.aom_sounds then
        sound = is_device and aom_sounds.default_metal() or aom_sounds.default_wood()
        sound.dig = {dig={name=""}}
        return sound
    -- hades
    elseif depends.hades then
        return is_device and hades_sounds.node_sound_metal_defaults(sound) or
          hades_sounds.node_sound_wood_defaults(sound)
    -- repixture
    elseif depends.rpx then
        return is_device and rp_sounds.node_sound_metal_defaults(sound) or
          rp_sounds.node_sound_wood_defaults(sound)
    end
end

----------
-- notenode functions

-- ditto to get_instrument function, except it's the expected notenode's get_instrument functionality
--- basically the basic function for getting an instrument for a notenode, use `tph_notenode.get_instrument` to customize your own
--- permits getting meta from node core stacks - including non-nodes
--- @param pos vector3 position of notenode
--- @param node table `core.get_node` result of notenode (not actually used, kept in for convenience with builtin functions)
--- @param bpos? vector3 position below notenode, can be calculated from notenode's position
--- @param bnode? `core.get_node` result of bpos, can be grabbed from bpos
local function notenode_get_instrument(pos, node, bpos, bnode)
    -- below
    if not bpos then
        bpos = vector.new(pos)
        bpos.y = bpos.y - 1
    end
    bnode = bnode or core.get_node(bpos)
    -- nodecore unique
    -- get the node from the itemstack actually!
    if bnode.name == "nc_items:stack" then
        local meta = core.get_meta(bpos)
        local item = ItemStack(meta:get_string("ncitem"))
        local def = item:get_definition()
        if def then
            bnode.name = def.name
        end
    end
    -- return instrument corresponding to below node
    return get_instrument(bpos, bnode)
end
-- expects to be used in node definition - ideally in `on_punch`
tph_notenode.notenode_get_instrument = notenode_get_instrument



--- plays sound and produces a particle effect, should be used in node's on_punch
--- @param pos vector3 position of notenode
--- @param node? table core.get_node() result of pos, node table of notenode, can be grabbed from pos
--- @param instrument? expects instrument table if provided, otherwise determines instrument from below node
--- @param note? expects note table produced by convert_param2_to_note function, otherwise grabbed from node's param2
--- @param plusminus? see tph_notenode.produce_note_particle for usage, if specified produces symbol with note
--- @param player? used exclusively in Exile. The actual player responsible for playing the instrument
local function notenode_play_instrument(pos, node, instrument, note, plusminus, player)
    node = node or core.get_node(pos)
    local ndef = core.registered_nodes[node.name]
    -- get instrument + note
    instrument = instrument or tph_notenode.handle_notenode_get_instrument(ndef, pos, node)
    note = note or get_note(node.param2, instrument)
    if not note then return end
    -- play and particle
    --core.log(note.name.." : "..note.hertz.." : "..note.octave.." ;; "..note.val)
    core.sound_play(instrument.sound, {
        max_hear_distance = 48, pitch = note.val, pos = pos, gain = instrument.gain
    })
    noteparticle(pos, note, instrument, nil, nil, plusminus)
end
-- expects to be used in node definition
tph_notenode.notenode_play_instrument = notenode_play_instrument

----------
-- handler functions, for either running node definition's function or the default

--- handles running notenode_get_instrument functionality without having to do it yourself
--- @param ndef? used for running node definition's function, derived from pos or node parameter if nil
--- @param pos position of the notenode
--- @param node? core.get_node result of pos, derived from pos if nil
--- @param bpos? position below pos, derived from pos if nil
--- @param bnode? core.get_node result of bpos, derived from bpos if nil
tph_notenode.handle_notenode_get_instrument = function(ndef, pos, node, bpos, bnode)
    -- ensure basics
    node = node or core.get_node(pos)
    bpos = bpos or vector.new(pos.x, pos.y - 1, pos.z)
    bnode = bnode or core.get_node(bpos)
    -- ensure node definition
    ndef = ndef or node and core.registered_nodes[node.name]
    -- now for the good stuff
    local func = ndef and ndef.notenode_get_instrument or notenode_get_instrument
    return func(pos, node, bpos, bnode)
end

--- handles running notenode_play_instrument functionality without having to do it yourself
--- @param ndef? used for running node definition's function, derived from pos or node parameter if nil
--- @param pos position of the notenode
--- @param node? core.get_node result of pos, derived from pos if nil
--- @param instrument? see tph_notenode.notenode_play_instrument
--- @param note? see tph_notenode.notenode_play_instrument
--- @param plusminus? see tph_notenode.notenode_play_instrument
--- @param player? see tph_notenode.notenode_play_instrument
tph_notenode.handle_notenode_play_instrument = function(ndef, pos, node, instrument, note, plusminus, player)
    -- ensure node
    node = node or core.get_node(pos)
    ndef = ndef or core.registered_nodes[node.name]
    -- now for the good stuff
    local func = ndef and ndef.notenode_play_instrument or notenode_play_instrument
    return func(pos, node, instrument, note, plusminus, player)
end



----------
-- node definitions

local nbdef = { -- notenode definition
    description = S("Notenode"),
    groups = {dig_immediate=2, notenode=1, tph_notenode=1},
    drawtype = "normal",
    paramtype = "light",
    sounds = get_node_sound(),
    mapcolor = {r=129, g=52, b=16},
    is_ground_content = false,
    -- sets param2
    on_construct = function(pos)
        local node = core.get_node(pos)
        local ndef = core.registered_nodes[node.name]
        -- get instrument to adequately get appropriate param2
        local instrument = tph_notenode.handle_notenode_get_instrument(ndef, pos, node)
        node.param2 = convert_note(instrument.basenotes[1], instrument)
        core.swap_node(pos, node)
    end,
    -- pos, node, below pos, below node
    notenode_get_instrument = notenode_get_instrument,
    notenode_play_instrument = notenode_play_instrument,
    on_punch = function(pos, node, puncher, pointed_thing)
        tph_notenode.handle_notenode_play_instrument(nil, pos, node)
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        -- protection check
        if core.is_player(clicker) then
            -- protected, return
            if core.is_protected(pos, clicker:get_player_name()) then return end
        end
        -- treble or bass
        local clef = get_clef_from_pointed_thing(pointed_thing, true)
        if not clef then return end
        -- treble for higher, bass for lower
        local addparam2 = clef == "treble" and 1 or clef == "bass" and -1
        node.param2 = node.param2 + addparam2
        -- get node definition
        local ndef = core.registered_nodes[node.name]
        -- get instrument
        local instrument = tph_notenode.handle_notenode_get_instrument(ndef, pos, node)
        -- get note for playing
        local note = get_note(node.param2, instrument)
        -- update param2 and swap the node
        node.param2 = convert_note(note, instrument)--note_octave_to_param2(instrument, note)
        -- figure out if we should show a symbol or not - if so, which symbol
        -- uses addparam2 to figure it out, 1 is true, any other number will be false, and if not number, nil
        local doplusminus = addparam2 == 1 and true or type(addparam2) ~= "number" and nil
        -- play
        tph_notenode.handle_notenode_play_instrument(ndef, pos, node, instrument, note, doplusminus, clicker)
        -- modify node
        core.swap_node(pos, node)
    end,
    -- save param2 if it's different from middle C
    preserve_metadata = function(pos, oldnode, oldmeta, drops)
        -- no node data or param2
        if not (type(oldnode) == "table" and oldnode.param2) then return end
        -- itemstack?
        local stack = type(drops) == "table" and type(drops[1]) == "userdata" and drops[1]
        if not (stack and stack.get_meta) then return end -- no itemstack or get_meta function
        -- check if we should save this even (if param2 does NOT equal middle C)
        -- get instrument to adequately get appropriate param2
        local ndef = core.registered_nodes[oldnode.name]
        local instrument = tph_notenode.handle_notenode_get_instrument(ndef, pos, oldnode)
        -- calculate baseparam2 from middle C
        local baseparam2 = convert_note(instrument.basenotes[1], instrument)
        -- don't save this, equals middle C's param2 conversion
        if oldnode.param2 == baseparam2 then
            -- actually, exilev4 has a unique conundrum they've given us!
            if depends.exilev4 then
                local imeta = stack:get_meta()
                -- Exile v4 doesn't know when to let go, erase description meta
                if imeta then
                    return imeta:set_string("description", "")
                end
            end
            return
        end
        -- get item's meta now
        local imeta = stack:get_meta()
        if not imeta then return end -- failed to get meta
        -- add notename to description
        local cnote = get_note(oldnode.param2, instrument) -- current note
        if (cnote and cnote.name ~= "C") then
            imeta:set_string("description", S("Notenode @1", cnote.name))
        end
        -- save as int
        -- add by 1 to ensure it's not equal to a nil get_int() - 0
        imeta:set_int("param2", oldnode.param2+1)
    end,
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        -- get the metas
        local imeta = type(itemstack) == "userdata" and itemstack.get_meta and itemstack:get_meta()
        if not imeta then return end
        -- transfer param2 from item meta if not 0
        local param2 = imeta:get_int("param2")
        if param2 == 0 then return end
        local node = core.get_node(pos)
        -- subtracted as explained above
        node.param2 = param2-1
        core.swap_node(pos, node)
        -- have protection on place
        if depends.exile then
            local meta = core.get_meta(pos)
            meta:set_string("description", "") -- annoying, remove dis
            minimal.protection_after_place_node(pos, placer, itemstack, pointed_thing, meta, imeta)
        end
    end,
    --[[
    on_punch = function(pos, node, puncher, pointed_thing)
        local timer = core.get_node_timer(pos)
        if not timer:is_started() then
            --core.log("starting at "..core.pos_to_string(pos))
            core.registered_nodes[node.name].on_timer(pos, 0)
            timer:start(math.random(5,60)/100)
        else
            --core.log("stopping at "..core.pos_to_string(pos))
            timer:stop()
        end
    end,
    on_timer = function(pos, elapsed)
        local instrument = instruments["donk"]
        local notes = instrument.notes
        local note
        -- get a note in chord
        while note == nil do
            note = notes[math.random(1, #notes)]
            -- verify if this is a note in the chord
            local chord = "Dm"
            for ind,name in ipairs(chords[chord]) do
                -- found, end loop
                if note.name == name then
                    break
                -- at the end of the line, make nil, try again
                elseif ind == #chords[chord] then
                    note = nil
                end
            end
        end
        -- play and report
        core.sound_play(instrument.sound, {
            max_hear_distance = 48, pitch = note.val, pos = pos
        })
        noteparticle(pos, note, instrument)
        --core.log("playing "..note.name..note.octave.." at "..core.pos_to_string(pos))
        return true
    end
    --]]
}
-- create tiles
nbdef.tiles = {}
for i=1,6 do
    local tile = "tph_notenode.png^tph_notenode_crest.png"
    if i ~= 2 then -- not the bottom
        tile = csg("", tile, "^",
          (i == 1 and "tph_notenode_waveform.png" or -- top
          (i==4 or i==6) and "tph_notenode_treble.png" or -- higher pitch
          (i==3 or i==5) and "tph_notenode_bass.png") ) -- lower pitch
    end
    nbdef.tiles[i] = tile
end

-- exile, add a new function
if depends.exile then
    -- position hashes of actively playing, debounce of 0.5
    local active = {}
    -- what we'll call on `on_punch` instead
    nbdef.notenode_on_alight = function(pos, node, ndef)
        local poshash = core.hash_node_position(pos)
        if active[poshash] then return end -- currently playing!
        node = node or core.get_node(pos)
        ndef = ndef or core.registered_nodes[node.name]
        if core.get_item_group(node.name, "notenode") < 1 then return end -- NOT a notenode!
        tph_notenode.handle_notenode_play_instrument(ndef, pos, node)
        if not ndef.notenode_on_alight then return end -- no function for lighting other nodes
        -- add to active
        active[poshash] = true
        -- remove from active after 1sec
        core.after(1, function()
            active[poshash] = nil
        end)
        -- play a different node
        --if math.random()<0.15 then return end -- 15% chance of not playing nearby nodes
        -- found nodes
        local fnodes = core.find_nodes_in_area({x=pos.x-1, y=pos.y-1, z=pos.z-1},
          {x=pos.x+1, y=pos.y+1, z=pos.z+1}, {"tph_notenode:notenode"})
        local amt = #fnodes -- amount of found nodes
        if amt == 0 then return end -- don't do anything
        -- actually found some neighbours!
        local playchance = 1 -- chance of playing nearby
        for i=1, amt do
            if math.random()>playchance then return end -- over play chance, return!
            local choice = math.random(1, amt) -- can sometimes point at a nil, nice random chance!
            local npos = fnodes[choice] -- new pos
            -- do not play at ourself
            if npos and not (pos.x == npos.x and pos.y == npos.y and pos.z == npos.z) then
                -- play 0.4-0.6sec later
                core.after(math.random(40,60)/100, ndef.notenode_on_alight, npos)
                -- remove from list
                fnodes[choice] = nil
            end
            -- take 25% off each iteration to keep choosing
            playchance = playchance * 0.75
        end
    end
    -- new `on_punch` behaviour
    nbdef.on_punch = function(pos, node, puncher, pointed_thing)
        local ndef = core.registered_nodes[node.name]
        -- set nodes alight if holding shift and if function exists
        if core.is_player(puncher) and ndef.notenode_on_alight then
            if puncher:get_player_control().sneak then
                return ndef.notenode_on_alight(pos, node, ndef)
            end
        end
        -- otherwise do as normal
        tph_notenode.handle_notenode_play_instrument(ndef, pos, node)
    end
end

--------------------------------
-- CREATING THE INSTRUMENTAL DEVICE NODE

local devicedef = {
    description = S("Instrumental Device"),
    groups = {dig_immediate=2, metallic=1},
    sounds = get_node_sound(true),
    mapcolor = {r=172, g=170, b=168},
    drawtype = "mesh",
    tiles = {"tph_notenode_tuner.png"},
    mesh = "tph_notenode_tuner.obj",
    collision_box = {
      type="fixed",
      fixed = {
          {-1/16, -8/16, -7/16, 1/16, 2/16, 7/16},
          {-7/16, -8/16, -1/16, 7/16, -5/16, 1/16},
          {-4/16, 2/16, -4/16, 4/16, 5/16, 4/16},
          --{-8/16, -8/16, -8/16, 8/16, 6/16, 8/16}
      }
    },
    paramtype = "light",
    on_punch = function(pos, node, puncher, pointed_thing)
        node = node or core.get_node(pos)
        local ndef = core.registered_nodes[node.name]
        -- get instrument + note
        local instrument = tph_notenode.handle_notenode_get_instrument(ndef, pos, node)
        local instnotes = instrument.notes
        -- not properly built into a notenode, play notes at random
        local note = instnotes[math.random(1, #instnotes)]
        -- play and particle
        core.sound_play(instrument.sound, {
            max_hear_distance = 48, pitch = note.val, pos = pos, gain = instrument.gain
        })
        noteparticle(pos, note, instrument, 0.55)
    end
}
devicedef.selection_box = devicedef.collision_box

-- to tell compatibility layers that we already have crafting
local has_craft

-- mesecons, voxelibre, mineclonia
-- based off of noteblocks
local function noteblock_craft()
    if has_craft then return end -- crafting already exists
    local noteblock = depends.mineclonia and "mcl_noteblock:noteblock" or
      depends.mesecons and "mesecons_noteblock:noteblock"
    local irongot = (depends.mineclonia or depends.voxelibre) and "mcl_core:iron_ingot" or
      depends.mesecons and "mesecons_gamecompat:steel_ingot"
    -- check aliases
    noteblock = core.registered_aliases[noteblock] or noteblock
    irongot = core.registered_aliases[irongot] or irongot
    -- check definitions
    noteblock = core.registered_nodes[noteblock]
    irongot = core.registered_items[irongot]
    if not (noteblock and irongot) then return end -- can't craft
    has_craft = true
    -- crafting table
    core.register_craft({
        output = "tph_notenode:notenode 2",
        recipe = {
            {noteblock.name, irongot.name, noteblock.name}
        }
    })
    -- uncraft mechanics
    -- back to regular noteblocks
    nbdef.on_punch = function(pos, node, puncher, pointed_thing)
        local witem = puncher:get_wielded_item()
        witem = witem:get_definition()
        if witem then
            -- convert back to a regular node if hacked by a wooden axe
            if (witem.groups.wooden_axe or witem.groups.wood_axe)
              or witem.groups.axe and witem.name:match("axe") then
                -- prevent ruining noteblocks if protected
                if core.is_player(puncher) then
                    if core.is_protected(pos, puncher:get_player_name()) then return end
                end
                if (depends.mineclonia or depends.voxelibre) then
                    -- little sound effect to let you know
                    core.sound_play("mcl_mobs_mob_poof", {
                        pos = pos, pitch = math.random(85, 110)/100
                    })
                end
                return core.set_node(pos, {name = noteblock.name, param2 = (noteblock.place_param2 or 0)})
            end
        end
        -- otherwise play some music
        tph_notenode.handle_notenode_play_instrument(nil, pos, node)
    end
end

-- crafting instrument device and notenode from it
local function base_craft()
    -- ensure all materials are accounted for
    local irongot = (depends.mineclonia or depends.voxelibre) and "mcl_core:iron_ingot" or
      depends.mesecons and "mesecons_gamecompat:steel_ingot" or
      depends.default and "default:steel_ingot" or
      depends.hades and "hades_core:steel_ingot"
    local coppergot = (depends.mineclonia or depends.voxelibre) and "mcl_copper:copper_ingot" or
      depends.default and "default:copper_ingot" or
      depends.hades and "hades_core:copper_ingot"
    local poweragent = depends.mineclonia and "mcl_redstone:redstone" or
      depends.default and "default:mese_crystal" or
      depends.hades and "hades_core:mese_crystal" or
      (depends.mesecons or depends.voxelibre) and "group:mesecon_conductor_craftable"
    -- check registration
    irongot = core.registered_craftitems[irongot]
    coppergot = core.registered_craftitems[coppergot]
    poweragent = (poweragent and poweragent:sub(1,6) ~= "group:" and core.registered_craftitems[poweragent]) or poweragent
    poweragent = type(poweragent) == "table" and poweragent.name or poweragent
    -- don't exist
    if not (irongot and coppergot and poweragent) then return end
    -- craft device
    core.register_craft({
        output = "tph_notenode:device",
        recipe = {
            {irongot.name, irongot.name, irongot.name},
            {"", poweragent, irongot.name},
            {coppergot.name, coppergot.name, coppergot.name}
        }
    })
    -- craft instrument with device
    core.register_craft({
        output = "tph_notenode:notenode",
        recipe = {
            {"group:wood", "group:wood", "group:wood"},
            {"group:wood", "tph_notenode:device", "group:wood"},
            {"group:wood", "group:wood", "group:wood"}
        }
    })
    -- secret alternative craft for sneaky users
    core.register_craft({
        output = "tph_notenode:notenode",
        recipe = {
            {"", "group:wood", ""},
            {"group:wood", "tph_notenode:device", "group:wood"},
            {"", "group:wood", ""},
        }
    })
end


-- yeah, the MC-like games
if depends.voxelibre or depends.mineclonia then
    -- transmits power beyond our node
    nbdef.groups.opaque = 1
end

-- mineclonia support
if depends.mineclonia then
    nbdef._mcl_redstone = {
        connects_to = function(pos, dir)
            return true
        end,
        update = function(pos, node)
            if mcl_redstone.get_power(pos) == 0 then return end -- no power
            tph_notenode.handle_notenode_play_instrument(nil, pos, node)
        end
    }
end

-- nodecore support
if depends.nodecore then
    local facedirs = {
        vector.new(1,0,0),
        vector.new(-1,0,0),
        vector.new(0,0,1),
        vector.new(0,0,-1)
    }
    local activated = {} -- nodes that have been activated
    nbdef.optic_check = function(pos, node, recv)
        local lit -- whether or not we have an optic light shone upon us
        for _,fdir in ipairs(facedirs) do
            lit = recv(fdir)
            if lit then break end -- end loop
        end
        -- get an ID to store into or check activated
        local posid = core.hash_node_position(pos)
        local ctime = nodecore.gametime -- get time too
        -- not powered
        if not lit then
            -- remove our time from activation table
            if activated[posid] then
                activated[posid] = nil
            end
            return
        -- powered actually, check time
        elseif type(activated[posid]) == "number" then
            -- if the last time we played within 0.3 seconds from now then return
            if (ctime - activated[posid]) < 0.3 then return end
        end
        -- play and add our time to activated table
        activated[posid] = ctime
        tph_notenode.handle_notenode_play_instrument(nil, pos, node)
    end
    -- digging properly
    nbdef.groups.snappy = 1
    devicedef.groups.snappy = 1
    nbdef.groups.optic_check = 1 -- for optic checking
end

-- age of mending support
if depends.aom then
    -- remove dig immedate
    nbdef.groups.dig_immediate = nil
    devicedef.groups.dig_immediate = nil
    -- and replace with better dig groups
    nbdef.groups.choppy = 1
    devicedef.groups.cracky = 1
    local offnodes = {}
    -- we're machines!
    nbdef.groups.mechanisms = 1
    devicedef.groups.mechanisms = 1
    -- permit using as a relayer
    nbdef.groups.wire_output = 1
    -- play
    -- target (our pos), player, (pos of clicked item)
    nbdef._on_wire_input = function(target, player, pos)
        -- get hash as an id to prevent overflow
        local posid = core.hash_node_position(target)
        if offnodes[posid] then return end
        offnodes[posid] = true
        -- now to actually play
        tph_notenode.handle_notenode_play_instrument(nil, target)
        aom_wire.activate(target, player) -- activate any others
        core.after(0.2, function() offnodes[posid] = nil end)
    end
end

-- exile support
if depends.exile then
    -- have it so it's protected upon place
    devicedef.after_place_node = minimal.protection_after_place_node
end

-- mod functionality support
-- mesecons
if depends.mesecons then
    nbdef.mesecons = {
        effector = {
            rules = mesecon.rules.alldirs,
            action_on = function(pos, node)
                tph_notenode.handle_notenode_play_instrument(nil, pos, node)
            end
        }
    }
end

-- register stuff prior to crafting

-- register notenode
core.register_node("tph_notenode:notenode", nbdef)
-- register device node
core.register_node("tph_notenode:device", devicedef)

-- non-luanti crafting
if NLC then
    -- I can't figure out nodecore crafting so this remains unfinished
    if depends.nodecore then
        
    elseif depends.exile then
        -- instrumental device crafting
        crafting.register_recipe({
            type = "anvil",
            output = "tph_notenode:device",
            items = {"tech:iron_ingot 2", "tech:iron_fittings 2", "artifacts:singing_stone"},
            level = 1,
            always_known = true
        })
        -- notenode
        crafting.register_recipe({
            type = "carpentry_bench",
            output = "tph_notenode:notenode",
            items = {"group:log 2", "tph_notenode:device"},
            level = 1,
            always_known = true
        })
        -- decrafting
        crafting.register_recipe({
            type = "anvil",
            output = "artifacts:singing_stone",
            items = {"tph_notenode:device"},
            replace = {"tech:iron_ingot 2", "tech:iron_fittings 2"},
            level = 1,
            always_known = true,
        })
        -- notenode back to instrumental device
        crafting.register_recipe({
            type = core.registered_nodes["tech:axe_iron_placed"] and "axe" or "chopping_block",
            output = "tph_notenode:device",
            items = {"tph_notenode:notenode"},
            replace = {"tech:stick 48"},
            level = 1,
            always_known = true,
        })
    -- age of mending crafting
    -- only if machine crafting is allowed (?)
    elseif depends.aom and aom_machines.has_aom_tcraft then
        -- device
        aom_tcraft.register_craft({
            output = "tph_notenode:device",
            items = {
                ["aom_machines:gear_lever"] = 1,
                ["aom_items:iron_sheet"] = 1,
                ["aom_items:iron_bar"] = 2,
                ["aom_items:copper_bar"] = 2
            },
        })
        -- notenode
        aom_tcraft.register_group_craft({
            output = "tph_notenode:notenode",
            items = {["tph_notenode:device"] = 1},
            group = "planks",
            group_count = 4
        })
    -- repixture crafting
    elseif depends.rpx then
        -- device
        crafting.register_craft({
            output = "tph_notenode:device",
            items = {
                "rp_default:ingot_wrought_iron 4",
                "rp_default:ingot_steel", -- used as a "power" cause idk the rarity of jewels and lumien
                "rp_default:ingot_copper 3"
            }
        })
        -- notenode
        crafting.register_craft({
            output = "tph_notenode:notenode",
            items = {
                "tph_notenode:device",
                "group:planks 4"
            }
        })
    end
-- expected luanti-esque crafting
else
    -- run a function that allows crafting from a premade noteblock
    if depends.mineclonia or depends.voxelibre or depends.mesecons then
        noteblock_craft()
    end
    -- lazily run a function that handles overall crafting
    base_craft()
end

-- set custom instruments UGH - no usable or sensible groups!
core.register_on_mods_loaded(function()
    -- used to quickly add an instrument to a node's definition
    -- setting `tph_notenode_instrument` field allows first priority
    -- but we're setting it as a group here instead to permit mods to customize better
    local function do_override(ndef, instrument)
        local grps = ndef.groups or {}
        -- e.g. `tph_notenode_myinstrument` group
        -- use csg function as it's faster than using `..`
        grps[csg("", "tph_notenode_",instrument)] = 1
        core.override_item(ndef.name, {groups = grps})
        return true -- return true on success
    end
    -- certain games don't have good groups
    -- so we'll just have to add certain stuff, MANUALLY!
    local addstruments = { -- add instruments
        xylophone = {"mcl_core:goldblock", "default:goldblock", "nc_optics:glass_opaque", "artifacts:moon_glass",
          "rp_gold:block_gold", "rp_gold:ingot_gold"},
        bamboo = {"mcl_bamboo:bamboo_block", "mcl_bamboo:bamboo_block_stripped", "tech:stick",
          "aom_flora:warpberry_bush", "rp_default:papyrus", "default:pine_bush_stem",
          "default:bush_stem", "default:acacia_bush_stem", "aom_flora:warpberry_stem"},
        string = {"nc_woodwork:plank"},
        tin = {"default:tinblock", "hades_core:tinblock", "artifacts:antiquorium",
          "rp_default:block_tin", "rp_default:ingot_tin"},
        bottleflute = {"nc_concrete:mud", "rp_default:sand"}, -- no clay in repixture, use sand instead
        doap = {"nc_woodwork:shelf", "artifacts:antiquorium_ladder", "tech:wooden_ladder",
          "rp_default:clam", "rp_default:clam_nopearl",
          "rp_default:book", "rp_default:book_empty"},
        bowlhit = {"default:ice", "nc_optics:lens", "nc_optics:lens_on", "rp_lumien:crystal_on",
          "rp_lumien:crystal_off"},
        airwhistle = {"air"},
        metal = {"aom_stone:ironstone_brick"},
        metallictwang = {"default:bronzeblock", "tech:trapdoor_iron", "tech:pane_tray", "aom_stone:ironstone_cobble",
          "rp_default:block_bronze", "rp_default:ingot_bronze", "nc_lode:bar_tempered", "nc_lode:bar_annealed",
          "nc_lode:rod_tempered", "nc_lode:rod_annealed"},
        sonar = {"nodes_nature:snow", "nodes_nature:snow_block", "rp_default:cactus"},
        metallicpile = {"default:diamondblock", "artifacts:trapdoor_antiquorium", "rp_default:block_carbon_steel"},
        bell = {"xpanes:bar_flat", "xpanes:bar", "bones:bones", "artifacts:transporter_power_dep",
          "rp_default:reinforced_frame"},
        organ = {"default:coalblock", "ncrafting:dye_table", "minimal:burnt_storage_pile", "rp_default:block_coal",
          "nc_fire:lump_coal"},
        sawtooth = {"default:mese", "artifacts:sun_stone", "artifacts:star_stone", "artifacts:transporter_power",
          "rp_lumien:block"},
        -- exile-specific
        exilebell = depends.exile and {"artifacts:bell"} or nil,
        exilesingstone = depends.exilev4 and {"artifacts:singing_stone", "artifacts:singing_stone_b",
          "artifacts:singing_stone_c"}
    }
    -- add instrument string
    for instrument, nodes in pairs(addstruments) do -- node name, instrument name
        for _, nname in ipairs(nodes) do
            local ndef = core.registered_nodes[nname]
            if ndef then
                do_override(ndef, instrument)
            end
        end
    end
    -- iterate through all nodes anyways
    for nname, node in pairs(core.registered_nodes) do -- node name, node definition
        -- not a node that'll generate a unique instrument
        if not get_instrument_raw(nil, nil, node) then
            local csucc = false -- compatibility success
            local groups = node.groups or {} -- just so we can easily check
            -- exile unique stuff
            if depends.exile then
                if node.drawtype == "mesh" and node.paramtype2 == "facedir" and
                  nname:match("cobble") then
                    csucc = do_override(node, "stone")
                elseif nname:match("_mg_") then
                    csucc = do_override(node, "xylophone")
                elseif nname:match("wooden_") then
                    do_override(node, "string")
                elseif node.mod_origin == "tech" and nname:match("iron") then
                    do_override(node, "metal")
                elseif type(node.drop) == "string" and node.drop:match(":clay") then
                    csucc = do_override(node, "bottleflute")
                elseif type(node.drop) == "string" and node.drop:match(":gravel") then
                    csucc = do_override(node, "snarepaper")
                end
            -- repixture unique stuff
            elseif depends.rpx then
                if nname:match("rp_default:block_") and groups.cracky then
                    csucc = do_override(node, "metal")
                end
            end
            -- ncbells
            if node.mod_origin == "ncbells" then
                csucc = do_override(node, "ncbell")
            elseif node.mod_origin == "aom_pipes" then
                csucc = do_override(node, "tin")
            elseif node.mod_origin == "hades_bushes" then
                csucc = do_override(node, "bamboo")
            elseif node.mod_origin == "mcl_copper" and (groups.oxidizable or groups.waxed or
              node._mcl_waxed_variant) then
                csucc = do_override(node, "tin")
            elseif node.mod_origin == "nc_flora" then
                if node.name:match("flower_1") then
                    csucc = do_override(node, "bell")
                elseif node.name:match("flower_5") then
                    csucc = do_override(node, "doap")
                elseif node.name:match("flower_4") then
                    csucc = do_override(node, "metallicpile")
                else
                    csucc = do_override(node, "hornsoft")
                end
            -- sometimes games are weird
            elseif type(node.sounds) == "table" and not csucc then
                local sound
                -- find a soundspec
                for _,data in pairs(node.sounds) do
                    if type(data) == "table" and data.name then
                        sound = data
                        break
                    end
                end
                -- if found and no instrument set already
                if sound then
                    if sound.name:match("metal") then
                        csucc = do_override(node, "metal")
                    elseif sound.name:match("glass") then
                        csucc = do_override(node, "clack")
                    -- nodecore sounds
                    elseif depends.nodecore then
                        if sound.name:match("tree_sticky") then
                            csucc = do_override(node, "bamboo")
                        elseif sound.name:match("tree_woody") then
                            csucc = do_override(node, "stringbass")
                        end
                    end
                end
            end
            -- name checks
            if not csucc then
                if nname:match(":clay") then
                    csucc = do_override(node, "bottleflute")
                elseif nname:match(":gravel") then
                    csucc = do_override(node, "snarepaper")
                end
            end
        end
        -- no instrument provided if statement
    end
end)