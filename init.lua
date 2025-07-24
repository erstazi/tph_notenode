--[[
(C) TPH/tph9677/TubberPupperHusker/TubberPupper/Damotrix
MIT License
https://opensource.org/license/mit

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

-- mod support
local depends = {
    -- games
    default = core.get_modpath("default"), -- minetest, mesecraft
    mineclonia = core.get_modpath("mcl_redstone"),
    voxelibre = core.get_modpath("mcl_sounds"),
    nodecore = core.get_modpath("nc_optics"),
    -- mods
    mesecons = core.get_modpath("mesecons"),
    ncbells = core.get_modpath("ncbells") -- nodecore bells
}


-- notes 1 to 12
local notenames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
-- for use by noteparticle function
local notecolours = {"#ff0000","#ff8000","#ffff00","#80ff00","#00ff00","#00ff80","#00ffff", -- C - F
  "#0080ff","#0000ff","#7f00ff","#ff00ff","#ff0080"} -- F# to B

local instruments = {}

-- register an instrument
-- name can be nil as it can be derived from sound file's name minus the mod's name
-- def can be the sound file string, otherwise must be a table with `sound` as an index
-- tune is the hertz of middle C (aka your sound file which SHOULD BE TUNED to C!)
-- gain is the volume of the instrument
local function register_instrument(name, def, tune, gain)
    name = type(name) == "string" and name or "unknown"
    -- basic definition (requires sound)
    def = type(def) == "string" and {sound=def} or type(def) == "table" and def
    if not (def and type(def.sound) == "string") then
        error("tph_notenode: instrument '"..name.."' lacks a sound! Please provide a sound file as 2nd parameter or "..
          "as the 'sound' index in definition")
    end
    def.mod_origin = core.get_current_modname()
    -- be weird and derive name from sound
    name = name == "unknown" and def.sound:gsub(def.mod_origin.."_","") or name
    -- if found in instruments, do error
    if instruments[name] then
        error("tph_notenode: '"..name.."' is an already registered instrument! Please name your instrument something else.")
    end
    -- volume
    gain = type(gain) == "number" and gain > 0 and gain or 1
    def.gain = gain
    -- tune! be sure you properly tune it to be C!
    tune = type(tune) == "number" and (tune > 0 and tune) or 261.6256
    -- create noteC (middle C note)
    local noteC = def.noteC or {}
    def.noteC = nil -- erase from def
    noteC.octave = noteC.octave or 1
    noteC.hertz = tune
    noteC.val, noteC.num = 1, 1
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
    local octrange = def.octrange or {}
    -- lower octave (default: -2)
    octrange[1] = type(octrange[1]) == "number" and math.min(math.abs(math.ceil(octrange[1])), 10) or 2
    octrange[1] = noteC.octave - octrange[1]
    -- higher octave (default: +1)
    octrange[2] = type(octrange[2]) == "number" and math.min(math.abs(math.ceil(octrange[2])), 10) or 1
    octrange[2] = noteC.octave + octrange[2]
    -- fill the notes
    -- there can only be a total of 252 notes, below param2's max of 256
    local notes = {}
    -- lower fill
    if octrange[1] ~= noteC.octave then
        local numbocts = math.abs(octrange[1] - noteC.octave) -- number octaves - how many octaves to generate
        for i=numbocts,1,-1 do -- go down
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
    if octrange[2] ~= noteC.octave then
        local numbocts = math.abs(octrange[2] - noteC.octave) -- ditto
        for i=1,numbocts do -- go up
            local oct = noteC.octave + i -- ditto
            for _,note in ipairs(basenotes) do
                -- hertz is base hertz times 2 ^ i
                -- ditto
                local new = {hertz=note.hertz*(2^i), name=note.name, octave=oct, num=note.num} -- new note
                new.val = new.hertz/noteC.hertz -- calculate val (for pitch modification)
                notes[#notes + 1] = new
            end
        end
    end
    -- finalizing
    def.notes = notes
    def.name = name
    def.octave_range = octrange
    instruments[name] = def
end

-- name, tune, sound
-- name can be nil and grabbed from sound, tune can be nil as it defaults to the 1939 tuning standard
-- sound can be a definition table, if so, must have {sound=sound_name}
-- simple bling-like synthy sound, springy (made from a spring inside of a mouse)
register_instrument(nil, "tph_notenode_donk", 259.459) -- base instrument
-- clacky kinda sound (made from scratching a plastic battery pack)
register_instrument(nil, "tph_notenode_klalk")
-- metallic-ish sound (made from hitting a metal pole)
register_instrument(nil, "tph_notenode_couke")
-- weird artificial bassy sound (made from hitting the top of a nutella plastic lid)
register_instrument(nil, "tph_notenode_dwoite")
-- wobbly bassy song (made from playing a spread-out shoelace)
register_instrument(nil, "tph_notenode_bvogne")
-- simple hit sound (made from dragging a finger across a zipper)
register_instrument(nil, "tph_notenode_blipck")
-- bamboo-y (hit actual bamboo)
register_instrument(nil, "tph_notenode_ghlick")
-- watery (made from moving around in a bathtub of water)
register_instrument(nil, "tph_notenode_llorlk")
-- air-y (made from blowing into a glass bottle, 2x pitch)
register_instrument(nil, "tph_notenode_oouve")
-- bell-ish (made from flicking at a glass bottle)
register_instrument(nil, {sound="tph_notenode_gliurk", octrange={3,1}})
-- soft mallet/pluck sound (made from pulling finger tightly out of a glass bottle)
register_instrument(nil, "tph_notenode_doap")
-- mod-specific instruments
if depends.ncbells then
    register_instrument("ncbell", 
      {sound="ncbells_ding",
      -- low, high
      octrange={4,3}
      })
end

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
local function get_instrument_raw(pos, node, ndef)
    if not ndef then
        node = node or core.get_node(pos)
    end
    ndef = ndef or core.registered_nodes[node.name]
    -- will play any instrument specified and if said instrument exists
    do
        -- prioritized
        local foundstrument = instruments[ndef.tph_notenode_instrument] -- found instrument
        if foundstrument then
            return foundstrument
        end
    end
    -- could not find a specified instrument, aight!
    local groups = ndef.groups or {}
    if groups.tree or groups.log or groups.material_wood or groups.wood then
        return instruments.bvogne
    elseif groups.sapling or groups.bamboo_block then
        return instruments.ghlick
    elseif groups.water then
        return instruments.llorlk
    elseif groups.clay then
        return instruments.oouve
    elseif groups.rail then
        return instruments.doap
    -- metals
    elseif groups.refined_tin or (depends.nodecore and groups.adobe) then
        return instruments.dwoite
    elseif groups.refined_gold then
        return instruments.gliurk
    elseif groups.metal or groups.metallic or groups.lodey then
        return instruments.couke
    --
    elseif groups.glass then
        return instruments.klalk
    elseif groups.stone then
        return instruments.blipck
    end
end

-- ditto to the above function, except this returns a default instrument on failure
local function get_instrument(pos, node, ndef)
    local inst = get_instrument_raw(pos, node, ndef)
    if not inst then
        -- get default instrument
        inst = instruments[default_instrument]
        -- add a new default instrument in case of failure
        if not inst then
            default_instrument = next(instruments)
            inst = instruments[default_instrument]
        end
    end
    return inst
end

--
-- spawns a little eighth note above the notenode

local function noteparticle(pos, note, instrument, y)
    pos = vector.new(pos)
    pos.y = pos.y + (y or 0.75)
    -- randomize position to prevent zindex fighting
    local range = 100
    pos.x, pos.z = pos.x + (math.random(-range,range)/1000), pos.z + (math.random(-range,range)/1000)
    local texture = "tph_notenode_note_eighth.png"
    -- figure out colour
    if note and instrument then
        instrument = type(instrument) == "string" and instruments[instrument] or instrument
        texture = texture.."^[multiply:"..notecolours[note.num]
        -- get octaves
        local octave, midoctave = note.octave, instrument.basenotes[1].octave
        -- add darkness or lightness
        if octave ~= midoctave then
            local divideby = midoctave+10
            -- higher, add lightness
            if octave > midoctave then
                octave = octave-midoctave -- difference between octave and base octave
                octave = math.ceil(200*(octave/divideby)) -- round up
                texture = texture.."^[colorize:#ffffff:"..octave
            -- lower, add darkness
            elseif octave < midoctave then
                octave = midoctave - octave
                octave = math.ceil(200*(octave/divideby))
                texture = texture.."^[colorize:#000000:"..octave
            end
        end
    end
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

-- instrument (e.g. from registered_instruments)
-- octave (param2 `rawoctave` or if `convert_to_raw` is true, convert refined note octave to param2)
local function instrument_calculate_octave(instrument, octave, convert_to_raw)
    local instnotes = instrument.notes
    local octamt = #instnotes/12 -- octave amount -- how many octaves in instrument total
    -- converting instrumental octave into param2 octave
    if convert_to_raw then
        local octmin, octmax = instrument.octave_range[1], instrument.octave_range[2] -- min to max of range
        if octave < octmin then return 0 end -- give lowest raw octave
        if octave > octmax then return math.floor(#instnotes/12) end -- give highest raw octave
        -- index will be the raw octave we want
        for ind,note in ipairs(instnotes) do
            if note.octave == octave then -- found our octave of choice
                return math.floor(ind/12) -- that is, `index/12` is the raw octave we want
            end
        end
    -- converting param2 octave into instrumental octave
    else
        octave = math.min(octave, octamt) -- clamp below instrument octave amount
        if octave == 0 then return instnotes[1].octave end -- octave of lowest note
        octave = octave*12
        local note = instnotes[octave] -- otherwise octave of interest will be at note `octave*12`
        if note and note.num%12 == 0 then
            note = instnotes[octave+1]
        end
        if not note then return instnotes[#instnotes].octave end -- too high!
        return note.octave
    end
end

-- node functions

-- param2 is expected to be 0 to 251
-- converts param2 into a corresponding note and octave
local function param2_to_note_octave(param2, instrument)
    local octaveraw = param2/12
    local octave = math.floor(octaveraw)
    local note = (octaveraw-octave)*12 -- percentage of 12
    -- note would be 0 to 11, but is added 1 to be 1 to 12
    note = math.floor(note + 0.5) + 1 -- round it too
    -- if instrument is not provided:
    -- octave will be param2 converted into a positive integer
    -- you will have to calculate what this means with your instrument
    return note, instrument and instrument_calculate_octave(instrument, octave) or octave
end

-- instrument data, note data
local function note_octave_to_param2(instrument, note)
    local param2 = instrument_calculate_octave(instrument, note.octave, true)
    return (param2*12) + (note.num-1)
end

-- get a note within the bounds of an instrument's notes using rawnote and octave
local function get_refined_note(rawnote, octave, instrument)
    local instnotes = instrument.notes
    -- clamping
    -- too low! lower than lowest note in instrument
    if octave < instnotes[1].octave then
        -- find ourselves on the first row
        return instnotes[rawnote]
    end
    -- too high! higher than highest note in instrument
    local hightave = instnotes[#instnotes].octave
    if octave > hightave then
        -- find equivalent note by subtracting length of instrument notes by `length of instnotes subtracted by (scale-rawnote)`
        -- scale being 12
        return instnotes[#instnotes-(12-rawnote)]
    end
    -- iterate through notes
    for _,note in ipairs(instrument.notes) do
        if note.octave == octave and note.num == rawnote then
            return note
        end
    end
end

-- for extra laziness
local function get_refined_note_from_param2(param2, instrument)
    local rawnote, octave = param2_to_note_octave(param2, instrument)
    return get_refined_note(rawnote, octave, instrument)
end

--------------------------------
-- CREATING THE NOTENODE NODE

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
    end
end


local nbdef = { -- notenode definition
    description = "Notenode",
    groups = {dig_immediate=2},
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
        local instrument = ndef.notenode_get_instrument(pos, node)
        local basenote = instrument.basenotes[1]
        node.param2 = note_octave_to_param2(instrument, basenote)
        core.swap_node(pos, node)
    end,
    -- pos, node, below node
    notenode_get_instrument = function(pos, node, bnode)
        -- ourselves
        --node = node or core.get_node(pos)
        --local ndef = core.registered_nodes[node.name]
        -- below
        local bpos = vector.new(pos)
        bpos.y = bpos.y - 1
        bnode = bnode or core.get_node(bpos)
        -- return instrument corresponding to below node
        return get_instrument(bpos, bnode)
    end,
    notenode_play_instrument = function(pos, node, instrument, note, player)
        node = node or core.get_node(pos)
        local ndef = core.registered_nodes[node.name]
        -- get instrument + note
        instrument = instrument or ndef.notenode_get_instrument(pos, node)
        note = note or get_refined_note_from_param2(node.param2, instrument)
        if not note then return end
        -- play and particle
        --core.log(note.name.." : "..note.hertz.." : "..note.octave.." ;; "..note.val)
        core.sound_play(instrument.sound, {
            max_hear_distance = 48, pitch = note.val, pos = pos, gain = instrument.gain
        })
        noteparticle(pos, note, instrument)
    end,
    on_punch = function(pos, node, puncher, pointed_thing)
        local ndef = core.registered_nodes[node.name]
        ndef.notenode_play_instrument(pos, node)
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        -- protection check
        if core.is_player(clicker) then
            -- protected, return
            if core.is_protected(pos, clicker:get_player_name()) then return end
        end
        -- some games do really weird stuff and don't properly send over a pointed_thing, return
        if not (pointed_thing and pointed_thing.type == "node") then return end
        local ndef = core.registered_nodes[node.name]
        -- where the node was clicked
        local face = (pointed_thing.above + pointed_thing.under)/2
        -- check if we should decrease or increase the pitch of notes, or not
        local staff = ( face.x == (pos.x - 0.5) or face.z == (pos.z - 0.5) ) and "treble" or
          ( face.x == (pos.x + 0.5) or face.z == (pos.z + 0.5) ) and "bass"
        -- ditto
        local addparam2 = (staff == "bass" or staff == "treble") and
          (staff == "treble" and 1 or staff == "bass" and -1)
        if addparam2 then
            node.param2 = node.param2 + addparam2
            -- clamp between 0 and 251
            --node.param2 = math.min(math.max(node.param2,0), 251)
            -- get instrument + rawnote + octave
            local instrument = ndef.notenode_get_instrument(pos, node)
            -- clamp param2 between instrument parameters
            if node.param2 < 0 then
                node.param2 = #instrument.notes+11
            elseif node.param2 >= #instrument.notes then
                node.param2 = 0
            end
            local rawnote, octave = param2_to_note_octave(node.param2, instrument)
            -- get note for playing
            local note = get_refined_note(rawnote, octave, instrument)
            -- update param2 and swap the node
            node.param2 = note_octave_to_param2(instrument, note)
            -- play
            ndef.notenode_play_instrument(pos, node, instrument, note, clicker)
            core.swap_node(pos, node)
        end
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
        local instrument = ndef.notenode_get_instrument(pos, oldnode)
        -- calculate baseparam2 from basenote
        local basenote = instrument.basenotes[1]
        local baseparam2 = note_octave_to_param2(instrument, basenote)
        -- don't save this, equals middle C's param2 conversion
        if oldnode.param2 == baseparam2 then return end
        -- get item's meta now
        local imeta = stack:get_meta()
        if not imeta then return end -- failed to get meta
        -- add notename to description
        local cnote = instrument.notes[oldnode.param2+1] -- current note
        if (cnote and cnote.name ~= "C") then
            imeta:set_string("description", stack:get_description().." "..cnote.name)
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
        tile = tile.."^"..(i == 1 and "tph_notenode_waveform.png" or -- top
          (i==4 or i==6) and "tph_notenode_treble.png" or -- higher pitch
          (i==3 or i==5) and "tph_notenode_bass.png") -- lower pitch
    end
    nbdef.tiles[i] = tile
end

--------------------------------
-- CREATING THE INSTRUMENTAL DEVICE NODE

local devicedef = {
    description = "Instrumental Device",
    groups = {dig_immediate=2},
    sounds = get_node_sound(true),
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
        local bpos = vector.new(pos)
        bpos.y = bpos.y - 1
        local instrument = get_instrument(bpos)
        local instnotes = instrument.notes
        -- not properly built into a notenode, play notes at random
        local note = instnotes[math.random(1, #instnotes)]
        -- play and particle
        --core.log(note.name.." : "..note.hertz.." : "..note.octave.." ;; "..note.val)
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
        -- otherwise play hopeful music
        local ndef = core.registered_nodes[node.name]
        ndef.notenode_play_instrument(pos, node)
    end
end

-- crafting instrument device and notenode from it
local function base_craft()
    -- ensure all materials are accounted for
    local irongot = (depends.mineclonia or depends.voxelibre) and "mcl_core:iron_ingot" or
      depends.mesecons and "mesecons_gamecompat:steel_ingot" or
      depends.default and "default:steel_ingot"
    local coppergot = (depends.mineclonia or depends.voxelibre) and "mcl_copper:copper_ingot" or
      depends.default and "default:copper_ingot"
    local poweragent = depends.mineclonia and "mcl_redstone:redstone" or
      depends.default and "default:mese_crystal" or
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
    -- crafting
    noteblock_craft()
end

-- mineclonia support
if depends.mineclonia then
    nbdef._mcl_redstone = {
        connects_to = function(pos, dir)
            return true
        end,
        update = function(pos, node)
            if mcl_redstone.get_power(pos) == 0 then return end -- no power
            local ndef = node and core.registered_nodes[node.name]
            if ndef and ndef.notenode_play_instrument then
                ndef.notenode_play_instrument(pos, node)
            end
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
        nbdef.notenode_play_instrument(pos, node)
    end
    -- digging properly
    nbdef.groups.snappy = 1
    devicedef.groups.snappy = 1
    nbdef.groups.optic_check = 1 -- for optic checking
end

-- mod functionality support
-- mesecons
if depends.mesecons then
    nbdef.mesecons = {
        effector = {
            rules = mesecon.rules.alldirs,
            action_on = function(pos, node)
                local ndef = node and core.registered_nodes[node.name]
                if ndef and ndef.notenode_play_instrument then
                    ndef.notenode_play_instrument(pos, node)
                end
            end
        }
    }
    -- crafting
    noteblock_craft()
end

-- lazily run a function that handles overall crafting
base_craft()

-- register notenode
core.register_node("tph_notenode:notenode", nbdef)
-- register device node
core.register_node("tph_notenode:device", devicedef)

-- set custom instruments UGH - no usable or sensible groups!
core.register_on_mods_loaded(function()
    -- used to add an instrument to a node's definition
    local function do_override(name, instrument)
        core.override_item(name, {tph_notenode_instrument = instrument})
    end
    local addstruments = { -- add instruments
        gliurk = {"mcl_core:goldblock", "default:goldblock", "nc_optics:glass_opaque"},
        ghlick = {"mcl_bamboo:bamboo_block", "mcl_bamboo:bamboo_block_stripped"},
        dwoite = {"default:tinblock"},
        oouve = {"nc_concrete:mud"},
        doap = {"nc_woodwork:shelf"}
    }
    -- add instrument string
    for instrument, nodes in pairs(addstruments) do -- node name, instrument name
        for _, nname in ipairs(nodes) do
            if core.registered_nodes[nname] then
                do_override(nname, instrument)
            end
        end
    end
    -- iterate through all nodes anyways
    for nname, node in pairs(core.registered_nodes) do -- node name, node definition
        -- not a node that'll generate a unique instrument
        if not get_instrument_raw(nil, nil, node) then
            -- ncbells
            if node.mod_origin == "ncbells" then
                do_override(nname, "ncbell")
            -- sometimes games are weird
            elseif type(node.sounds) == "table" and not node.tph_notenode_instrument then
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
                        do_override(nname, "couke")
                    elseif sound.name:match("glass") then
                        do_override(nname, "klalk")
                    elseif depends.nodecore then
                        if sound.name:match("tree_sticky") then
                            do_override(nname, "ghlick")
                        elseif sound.name:match("tree_woody") then
                            do_override(nname, "bvogne")
                        end
                    end
                end
            end
            -- name checks
            if not node.tph_notenode_instrument then
                if node.name:match(":clay") then
                    do_override(nname, "oouve")
                end
            end
            -- sound exists if statement
        end
    end
end)