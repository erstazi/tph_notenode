# Purpose of this API

The API included with the TPH's Notenodes mod allows one to make their OWN playing instruments! Permitting unique sounds to be played with specific nodes if a notenode is placed above.


# Cool things to note

If you're having issues with instruments conflicting - e.g. you set up different instruments for dirt and a specialized type of dirt (let's say podzol), and both have the "dirt" group and podzol has the "podzol" group - you'll notice how it'll still keep playing the dirt instrument! In order to fix this, you can set a `choice_priority` in the dirt instrument's definition, OR set a `lowprty=3` (3 or any number from 1 to well, any higher) in the `groups` table when registering the instrument. When set, it will deprioritize the dirt instrument in favour of the podzol instrument. The higher the number, the less priority it will have. So that if you had an instrument for a "node" group that both dirt and podzol share, you could have that group be higher than the dirt instrument's `choice_priority` so that the dirt instrument plays accordingly.



# Instrument Registration (`tph_notenode.register_instrument`)

`tph_notenode.register_instrument(name, definition, playing_groups, noteC)`

## name

`string` or can be `nil` IF a "sound" is specified for instrument definition (deriving name from the string)

## definition

WIP

`table` of data (with `sound`), or `string` of sound file name (which can be used to derive name if name is `nil`)

## playing_groups (OPTIONAL)

`table` array of strings associated to a node group

`lowprty` index can be specified in the `playing_groups` table array (as it will be grabbed independently out) to shorthand needing to write `choice_priority` in `definition`

Recommended to use API function `tph_notenode.create_instruments_group_table`, especially for custom depends handling which can have nil values (if for example, you use a boolean condition to determine whether or not to have a group specified for a certain instrument for a certain game/mod)

## noteC (OPTIONAL)

Used for determining what the middle note on the base octave should be

`table` dictionary containing two interpretable values;

- `hertz`, a `number`, is used for calculating pitches for notes after middle C in the scale, and other octave scales in the instrument. Primarily for reading purposes, and does not affect how pitches are generated. Defaults to `261.6256`

- `octave`, an `integer`, is used purely for reading purposes and does not pose any unique functionality. Defaults to `1`



# `tph_notenode_` functionality

There are two ways to force a certain block to play an instrument - a softer one that respects `lowprty` - and one that does NOT respect it - and will play the select instrument regardless of node groups.

## Soft

In groups, if `tph_notenode_(instrument name)` is specified, such as `groups = {tph_notenode_donk = 1}`, then it will attempt to play that instrument unless an instrument with a higher priority is detected according to the node's other groups

## Hard

If the field `tph_notenode_instrument` is specified, such as `tph_notenode_instrument = "donk"`, then it will play this instrument REGARDLESS of groups - and will not check node groups



# Compatibilities (`tph_nodecore.depends`)

A table of `depends` exists within the `tph_notenode` global. These are indexed by name, and will be a path string or nil depending on if it was detected. These can NOT be written to and will error if written to.

## Game "Depends"
- default (Minecraft, Mesecraft)
- mineclonia
- voxelibre
- nodecore
- exile
- exilev4 (if `exile` and its detected that the experimental v4 is present)
- aom (Age of Mending)
- hades (Hades Revisited)
- rpx (Wuzzy's Repixture)

## Mod "Depends"
- mesecons (https://content.luanti.org/packages/Jeija/mesecons/)
- ncbells (GreenXenith's Nodecore Bells)
- aom_sounds (Age of Mending sounds, depended upon in the possibility of it not being included)

## NLC (Non-Luanti Crafting)

For games that introduce unique crafting systems that require specific attention to set up crafting recipes. This will be `true` if there is such a game (and can be used by you to figure out how to approach the system), and `false` if it's anticipated to be the usual Minetest Game crafting.

Current games within `depends` that will cause `depends.NLC` to be true:
- exile (including `exilev4`)
- nodecore
- aom (Age of Mending)
- rpx (Wuzzy's Repixture)



# API variables

Any values under `tph_notenode` meant NOT to be written to - and will cause error if written to. In order to properly iterate over said tables, you will require the mod `metatable_metamethods` (https://content.luanti.org/packages/TPH/metatable_metamethods/)

See `Compatibilities` for `tph_notenode.depends`

## notesdata (`tph_notenode.notesdata`)

Table of two different tables utilized for determining the colour and "name" of a note. Each table indexed under the format of a 12-tone scale (numbered 1 to 12)

- names (`notesdata.names`)

These will be strings equal to: C, C#, D, D#, E, F, F#, G, G#, A, A#, B

- colours (`notesdata.colours`)

These will be a `ColorString` in hexadecimal format without an alpha channel

## Playing Groups (`tph_notenode.playing_groups`)

A table of instrument names indexed by a node group. Used for quickly determining which instrument to play depending on a node's groups. For example, indexing `tph_notenode.playing_groups["glass"]` would get the instrument `tph_notenode_clack` (unless an instrument has been registered to replace the `glass` `playing_group`.

## Registered Instruments (`tph_notenode.registered_instruments`)

A table of registered instruments indexed by name.



# API settings

Values within `tph_notenode` that can be modified by external mods.

## colours (`tph_notenode.colours`)

This contains hexadecimal `ColorString`s indexed by name, utilized in specific situations that require colour. Supports usage of the alpha channel (although I wasn't able to get it to work lol). The actual table can NOT be replaced, however the variables inside can be modified.

- minus (`colours.minus`)

A hexadecimal used for colouring the symbol that appears when a note is modified to be lower in pitch

- plus (`colours.plus`)

A hexadecimal used for colouring the symbol that appears when a note is modified to be higher in pitch



# API functions

Callable functions for handling general effects and mechanics

See `Instrument Registration` for `tph_notenode.register_instrument`

## Create Instruments Group Table (`tph_notenode.create_instruments_group_table`)

Creates a table that can be utilized for `tph_notenode.register_instrument`'s `playing_groups` parameter and optionally `choice_priority`. See Instrument Registration's `playing_groups` for more information on what to expect

Permits tuple argument of strings for easily creating a risk-free `playing_groups` table. Ignores all non-strings unless first provided parameter is `number`. Can be used to skip over accidentally creating a table with `false` in arguments that require a depends to be existent, as per the last arugment in the below expected usage

Expected usage: `tph_notenode.create_instruments_group_table("node_group1", "node_group2", depends.somegame and "node_group_special")`

`choice_priority` alternative: if first passed argument is a `number` (expected `integer` above 0), this will be added to the returned table as index `lowprty` - which will be read and utilized by instrument registration

Expected usage: `tph_notenode.create_instruments_group_table(5, "agroup", "agroup2")`

## Get Instrument (Raw) (`tph_notenode.raw_get_instrument`)

`tph_notenode.raw_get_instrument(pos, node, nodedefinition)`

EXPECTED TO BE THE NODE BELOW THE NOTENODE

As long as one of the parameters exist, it will return the detected instrument. If no `node` or `nodedefinition`, can derive from `pos`. If no `nodedefinition` or `pos`, can derive from `node`, if no `pos` or `node`, will utilize provided `nodedefinition`

Returns instrument definition or nil if couldn't find instrument

## Get Instrument (`tph_notenode.get_instrument`)

`tph_notenode.get_instrument(pos, node, nodedefinition)`

EXPECTED TO BE THE NODE BELOW THE NOTENODE

Same functionality as `tph_notenode.raw_get_instrument` except that it will return the definition of the `default_instrument` if could not find an instrument

## Produce Note Particle (`tph_notenode.produce_note_particle`)

`tph_notenode.produce_note_particle(pos, note, instrument, y, colour, plusminus)`

Spawns a floating note particle at pos

If `note` not specified, note will spawn as uncoloured (white) UNLESS `colour` IS SPECIFIED. `note` MUST be a table that is derived from `tph_notenode.convert_param2_to_note` or an instrument's notes table. `note` table must have a `num` that is from 1 to 12

If `instrument` not specified, octave darkening or lightening won't be applied to the note particle - ALSO requires `note` to be specified. `instrument` is an instrument definition table with an adequately formed `basenotes` table. If both are specified, applies darkening to particle if note octave is lower than instrument's base octave, applies lightening to particle if note octave is higher, otherwise applies no effect

If `y` not specified, spawns Y+0.75 (3 quarters up) from pos. `y` is otherwise expected to be a number

If `colour` is specified, overrides colouring from `note` or default white colouring. EXPECTED TO BE A `HEXADECIMAL COLORSTRING`

If `plusminus` is specified, must be boolean true or false. Shows a coloured `+` (if `true`) or `-` (if `false`) symbol next to the note particle

## Param2 --> Note (`tph_notenode.convert_param2_to_note`)

`tph_notenode.convert_param2_to_note(param2, instrument)`

The inverse of `tph_notenode.convert_note_to_param2`! Handles converting a node's param2 to a valid note table

`param2` should be what's returned from `core.get_node(pos)`, a number between 0 and 255. Gets clamped if under or above said limit

`instrument` should be an instrument definition table or the name of a valid instrument

Returns `note` table correlating to the provided `param2`. Returns "high" or "low" as 2nd parameter if param2 had to be clamped

## Note --> Param2 (`tph_notenode.convert_note_to_param2`)

`tph_notenode.convert_note_to_param2(note, instrument)`

The inverse of `tph_notenode.convert_param2_to_note`! Handles converting a valid note table into a node param2

`note` should be a valid note table that would be in `instrument`

`instrument` should be an instrument definition table or the name of a valid instrument

Returns a number from 0 to 255 correlated to the note table and instrument definition's information

## Coordinate of Node Face Correlated to Pointed Thing (`tph_notenode.get_pointed_thing_node_face`)

`tph_notenode.get_pointed_thing_node_face(pointed_thing)`

You SHOULDN'T need to use this function, but the option is provided. Utilized by `tph_notenode.get_staff_from_pointed_thing`

Derives which facing side was clicked upon by the subject with a valid provided `pointed_thing` table. Representing the select face with a 3D coord (XYZ) with minus or plus symbols (-+) preceeding.

`pointed_thing` should be a valid `pointed_thing` returned by node click callbacks or the results from a raycast

Returns a string correlating to the coordinate and which integer thingie. What can be returned: "-X", "+X", "-Y", "+Y", "-Z", "+Z"

## (Music) Staff from Pointed Thing (`tph_notenode.get_staff_from_pointed_thing`)

`tph_notenode.get_pointed_thing_node_face(pointed_thing, staffonly)`

Utilizes `tph_notenode.get_pointed_thing_node_face` to determine the staff clef. Used for setting notenode's pitch correlated to the suspected

`pointed_thing` should be a valid `pointed_thing` returned by node click callbacks or the results from a raycast

`staffonly` is optional - however if specified, should be boolean. If true, returns only if a valid detected staff - otherwise nil

Returns a string correlating to the clicked face of a node. Returns "bass" or "treble", and if `staffonly` is not specified, then will return "top" or "bottom" as well

## Functions Intended for Node Callbacks;; ==============================================

Premade functions for easily setting up node callbacks

## Node Get Instrument (`tph_notenode.notenode_get_instrument`)

`tph_notenode.notenode_get_instrument(pos, node, bottompos, bottomnode)`

Utilizes a localized version of `tph_notenode.get_instrument` to get the instrument underneath a notenode

`pos` is the `Vector` position of the notenode in question

`node` is the node table `core.get_node(pos)` of the notenode in question (not currently used, kept for parameters sakes, unlikely to be used in the future)

`bottompos` is optional. Should be the position underneath the notenode, will calculate from `pos` if not specified

`bottomnode` is optional. Should be the node table `core.get_node(bottompos)` of the node underneath the notenode. Will be grabbed from `bottompos` if not specified

Returns the same return as `tph_notenode.get_instrument` - the definition table of an instrument

## Node Play Instrument (`tph_notenode.notenode_play_instrument`)

`tph_notenode.notenode_play_instrument(pos, node, instrument, note, player, plusminus)`

Plays sound of instrument and produces a note particle at provided notenode. Requires notenode's definition to have the `notenode_get_instrument` callback

`pos` is the `Vector` position of the notenode in question

`node` is optional. If provided, must be a note table `core.get_node(pos)` result grabbed from position of notenode

`instrument` is optional. If provided, must be a valid `instrument` definition from `tph_notenode.registered_instruments`. Otherwise is grabbed from node underneath notenode's position

`note` is optional. If provided, must be a valid `note` table from an `instrument` definition. Otherwise is grabbed from the notenode's param2 and gathered instrument definition

`player` is optional and intended purely for Exile. Good to provide it anyways if you can. If specified, should be the player object of the player interacting

`plusminus` is optional. If provided, must be boolean - `true` for `+`, `false` for `-`. Utilized in the function's usage of a localized variant of `tph_notenode.produce_note_particle`

## Handler Functions;; ==============================================

Functions for handling running a node definition's callbacks or running default functions

## Handle Node Get Instrument (`tph_notenode.handle_notenode_get_instrument`)

`tph_notenode.handle_notenode_get_instrument(ndef, pos, node, bottompos, bottomnode)`

Handler variant for `tph_notenode.notenode_get_instrument`, runs node's callback variant or `tph_notenode.notenode_get_instrument`

`ndef` is optional. If provided, must be the `core.registered_nodes` definition of node

See `tph_notenode.notenode_get_instrument` for other parameters

## Handle Node Play Instrument (`tph_notenode.handle_notenode_play_instrument`)

`tph_notenode.handle_notenode_play_instrument(pos, node, instrument, note, player, plusminus)`

Handler variant for `tph_notenode.notenode_play_instrument`, runs node's callback variant or `tph_notenode.notenode_play_instrument`

`ndef` is optional. If provided, must be the `core.registered_nodes` definition of node

See `tph_notenode.notenode_play_instrument` for other parameters



# API node callbacks

Callback options that can be utilized to customize how the `notenode` or your own registered node using `notenode` functions, handle certain functionality

## Callback Get Instrument (`ndef.notenode_get_instrument`)

`ndef.notenode_get_instrument(pos, node, bpos, bnode)`

See `tph_notenode.notenode_get_instrument` for an explanation of parameters

SHOULD expect `node`, `bpos`, and `bnode` to be nil, and should make cases for grabbing them from `pos`

Recommended to include or otherwise utilize `tph_notenode.notenode_get_instrument`

## Callback Play Instrument (`ndef.notenode_play_instrument`)

`ndef.notenode_play_instrument(pos, node, instrument, note, player, plusminus)`

See `tph_notenode.notenode_play_instrument` for an explanation of parameters

SHOULD expect all parameters except for `pos` to be nil, and should make cases for grabbing them from `pos`

Recommended to include or otherwise utilize `tph_notenode.notenode_get_instrument`

## (EXILE ONLY) Callback On Alight

`ndef.notenode_on_alight(pos, node, ndef)`

`pos` is the `Vector3` position of the notenode in question

`node` may not always be provided. You should derive from `pos` using `core.get_node(pos)`

`ndef` may not always be provided. You should derive from `node` using `core.registered_nodes[node.name]`

SHOULD expect all parameters except for `pos` to be nil, and should make cases for grabbing them from `pos`

No builtin mod functions currently exist for handling `ndef.notenode_on_alight`. It is only ran by the customized `on_punch` for Exile