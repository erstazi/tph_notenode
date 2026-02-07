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



# Instrument Groups Table (`playing_groups`)

Info info talk talk WIP



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

Creates a table that can be utilized for `tph_notenode.register_instrument`'s `playing_groups` parameter and optionally `choice_priority`. See `Instrument Group Table (playing_groups` for more information on what to expect

Permits tuple argument of strings for easily creating a risk-free `playing_groups` table. Ignores all non-strings unless first provided parameter is `number`. Can be used to skip over accidentally creating a table with `false` in arguments that require a depends to be existent, as per the last arugment in the below expected usage

Expected usage: `tph_notenode.create_instruments_group_table("node_group1", "node_group2", depends.somegame and "node_group_special")`

`choice_priority` alternative: if first passed argument is a `number` (expected `integer` above 0), this will be added to the returned table as index `lowprty` - which will be read and utilized by instrument registration

Expected usage: `tph_notenode.create_instruments_group_table(5, "agroup", "agroup2")`