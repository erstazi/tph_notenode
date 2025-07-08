--[[
(C) TPH/tph9677/TubberPupperHusker/TubberPupper/Damotrix
MIT License
https://opensource.org/license/mit

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]


-- use calculating function progressively via multiplication `2^(1/12)`
local notenames = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
-- for use by noteparticle function
local notecolours = {"#ff0000","#ff8000","#ffff00","#80ff00","#00ff00","#00ff80","#00ffff", -- C - F
  "#0080ff","#0000ff","#7f00ff","#ff00ff","#ff0080"} -- F# to B

local instruments = {}

-- register an instrument
-- name can be nil as it can be derived from sound file's name minus the mod's name
-- tune is the hertz of middle C (aka your sound file which SHOULD BE TUNED to C!)
-- def can be the sound file string, otherwise must be a table with `sound` as an index
local function register_instrument(name, tune, def)
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
    for i=1,11 do
        local name = notenames[i]
        -- hertz calculation is middle C * 2^(semitone/12)
        -- https://en.wikipedia.org/wiki/Musical_note#Pitch_frequency_in_hertz
        local info = {hertz = noteC.hertz * 2^(i/12), octave=noteC.octave, name=name, num = i+1}
        info.val = info.hertz/noteC.hertz
        basenotes[#basenotes + 1] = info -- add to list
    end
    def.basenotes = basenotes -- list of notes to be used as a base (base octave)
    -- produce octave range and specific octaves
    local octrange = def.octrange or {}
    -- lower range must be less than noteC's octave - or equal to cancel the creation of lower octaves
    octrange[1] = type(octrange[1]) == "number" and octrange[1] <= noteC.octave or noteC.octave - 2 -- 3
    -- clamp above `middle octave - 10`
    octrange[1] = octrange[1] ~= noteC.octave and (octrange[1] < noteC.octave - 10 and noteC.octave-10) or octrange[1]
    -- ditto to the above - higher range greater - or equal to cancel creation of higher octaves
    octrange[2] = type(octrange[2]) == "number" and octrange[2] >= noteC.octave or noteC.octave + 1 -- 2
    -- clamp below `middle octave + 10`
    octrange[2] = octrange[2] ~= noteC.octave and (octrange[2] > noteC.octave + 10 and noteC.octave+10) or octrange[2]
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
register_instrument(nil, 259.459, "tph_notenode_donk") -- base instrument
register_instrument(nil, nil, "tph_notenode_klalk")
register_instrument(nil, nil, "tph_notenode_couke")

-- for debugging purposes, gets notenodes to ONLY play notes within a certain chord
local chords = {
    Cm = {"C", "D", "D#", "F", "G", "G#", "A"},
    ["C#m"] = {"C#", "D#", "E", "F#", "G", "A", "B"},
    Dm = {"D#","F,","F#","G#","A#","B","C#"},
    allhash = {"C#", "D#", "F#", "G#", "A#"},
    whole = {"C", "D", "E", "F", "G", "A", "B"},
    tetris = {"A", "B", "C", "D", "E", "F"},
}

local function default_instrument()
    return instruments.donk
end

-- pos, node, and ndef must be what is BELOW the note node
local function get_instrument_from_below(pos, node, ndef)
    node = node or core.get_node(pos)
    ndef = ndef or core.registered_nodes[node.name]
    if ndef.sounds then
        local sound = next(ndef.sounds)
        sound = ndef.sounds[sound]
        if not (sound and sound.name) then return default_instrument() end
        -- metallic
        if sound.name:match("metal") then
            return instruments.couke
        -- glassy
        elseif sound.name:match("glass") then
            return instruments.klalk
        end
    end
    -- universal instrument
    return default_instrument()
end

--
-- spawns a little eighth note above the notenode

local function noteparticle(pos, note, instrument)
    pos = table.copy(pos)
    pos.y = pos.y + 0.75
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

local function instrument_calculate_octave(instrument, octave, convert_to_raw)
    local instnotes = instrument.notes
    local octamt = #instnotes/12 -- octave amount -- how many octaves in instrument total
    -- converting instrumental octave into param2 octave
    if convert_to_raw then
        local octmin, octmax = instrument.octave_range[1], instrument.octave_range[2] -- min to max of range
        if octave < octmin then return 0 end -- give lowest raw octave
        if octave > octmax then return octamt end -- give highest raw octave
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


local nbdef = { -- notenode definition
    description = "Notenode",
    groups = {dig_immediate=2},
    drawtype = "normal",
    paramtype = "light",
    sounds = {dig = {name=""}},
    -- sets param2
    on_construct = function(pos)
        local node = core.get_node(pos)
        local ndef = core.registered_nodes[node.name]
        -- get instrument to adequately get appropriate param2
        local instrument = ndef.notenode_get_instrument(pos, node)
        node.param2 = note_octave_to_param2(instrument, {num=1, octave=1})
        core.swap_node(pos, node)
    end,
    -- pos, node, below node
    notenode_get_instrument = function(pos, node, bnode)
        -- ourselves
        --node = node or core.get_node(pos)
        --local ndef = core.registered_nodes[node.name]
        -- below
        local bpos = table.copy(pos)
        bpos.y = bpos.y - 1
        bnode = bnode or core.get_node(bpos)
        -- return instrument corresponding to below node
        return get_instrument_from_below(bpos, bnode)
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
            max_hear_distance = 48, pitch = note.val, pos = pos
        })
        noteparticle(pos, note, instrument)
    end,
    on_punch = function(pos, node, puncher, pointed_thing)
        local ndef = core.registered_nodes[node.name]
        ndef.notenode_play_instrument(pos, node)
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local ndef = core.registered_nodes[node.name]
        -- where the node was clicked
        local face = (pointed_thing.above + pointed_thing.under)/2
        -- check if we should lower notes or not
        local xequal,zequal = math.ceil(face.x) == face.x, math.ceil(face.z) == face.z
        -- xequal == treble, zequal == bass
        local addparam2 = not (xequal and zequal) and (xequal and 1 or zequal and -1) or 0
        if addparam2 ~= 0 then
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
    local tile = "tph_notenode.png"
    tile = i ~= 2 and tile.."^"..(i == 1 and "tph_notenode_waveform.png" or
      i > 4 and "tph_notenode_treble.png" or
      i > 2 and "tph_notenode_bass.png") or tile
    nbdef.tiles[i] = tile
end

-- register notenode
core.register_node("tph_notenode:notenode", nbdef)