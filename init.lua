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
    for i=2,12 do
        local name = notenames[i]
        -- hertz calculation is middle C * 2^(semitone/12)
        -- https://en.wikipedia.org/wiki/Musical_note#Pitch_frequency_in_hertz
        local info = {hertz = noteC.hertz * 2^(i/12), octave=noteC.octave, name=name, num = i}
        info.val = info.hertz/noteC.hertz
        basenotes[#basenotes + 1] = info -- add to list
    end
    def.basenotes = basenotes -- list of notes to be used as a base (base octave)
    -- produce octave range and specific octaves
    local octrange = def.octrange or {}
    -- lower range must be less than noteC's octave - or equal to cancel the creation of lower octaves
    octrange[1] = type(octrange[1]) == "number" and octrange[1] <= noteC.octave or noteC.octave - 3 -- 3
    -- ditto to the above - higher range greater - or equal to cancel creation of higher octaves
    octrange[2] = type(octrange[2]) == "number" and octrange[2] >= noteC.octave or noteC.octave + 2 -- 2
    -- fill the notes
    local notes = {}
    -- lower fill
    if octrange[1] ~= noteC.octave then
        local numbocts = math.abs(octrange[1] - noteC.octave) -- number octaves - how many octaves to generate
        for i=numbocts,1,-1 do -- go down
            local oct = noteC.octave - i -- octave for this particular round
            for _,note in ipairs(basenotes) do
                -- hertz is base hertz divided by i times, same with val
                -- repeat note name, and add current octave to octave
                notes[#notes + 1] = {hertz=note.hertz/i, val = note.val/i, name=note.name, octave=oct, num = note.num}
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
                -- hertz is base hertz times i, same with val
                -- ditto
                notes[#notes + 1] = {hertz=note.hertz*i, val = note.val*i, name=note.name, octave=oct, num = note.num}
            end
        end
    end
    -- finalizing
    def.notes = notes
    def.name = name
    instruments[name] = def
end

-- name, tune, sound
-- name can be nil and grabbed from sound, tune can be nil as it defaults to the 1939 tuning standard
-- sound can be a definition table, if so, must have {sound=sound_name}
register_instrument(nil, 259.459, "tph_notenode_donk") -- base instrument

-- for debugging purposes, gets notenodes to ONLY play notes within a certain chord
local chords = {
    Cm = {"C", "D", "D#", "F", "G", "G#", "A"},
    ["C#m"] = {"C#", "D#", "E", "F#", "G", "A", "B"},
    Dm = {"D#","F,","F#","G#","A#","B","C#"},
    allhash = {"C#", "D#", "F#", "G#", "A#"},
    whole = {"C", "D", "E", "F", "G", "A", "B"},
    tetris = {"A", "B", "C", "D", "E", "F"},
}

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

--------------------------------
-- CREATING THE NOTENODE NODE


local nbdef = { -- notenode definition
    description = "Notenode",
    groups = {dig_immediate=2},
    drawtype = "normal",
    paramtype = "light",
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