# What plays what!

## Minetest Game
Block								Sound
----------------------------------------------------
Any non-special						Donk
Glass								Clack
Metal Blocks						Metal
Tin Block							Tin
Logs								Stringed Bass
Stone								Stone (bass drum-ish)
Sapling/Woody Plants/Bush Stems		Bamboo
Water								Water
Clay								Bottle Flute
Gold Block							Xylophone
Rail/Pumpkin						Doap (soft synthetic percussion sound)
Ice									Bowl Hit
Air									Air Whistle
Gravel								Paper Snare
Copper Block						Metallic Twang
Snow								Sonar
Diamond Block						Metallic Pile
Wooden Planks						String (Guitar-ish)
Grasses/Growing Plants				Soft Horn
Steel Bars							Bell
Coal Block							Organ
Mese Block							Sawtooth



# FOR DEVELOPERS

Every created instrument will have `tph_notenode_`(name) as a group, for example of the default `donk`: `groups.tph_notenode_donk = 1`

Notenodes check the groups of the node below - and play according to the highest prioritized instrument

Groups are the provided bullet points after sound information

# Base Instruments

These are instruments that come prepared with the mod - and will LIKELY be set up for every game - especially full setup for the games noted as compatible unless otherwise specified. Each of these instruments (excluding default) will have groups they will play notes accordingly to - so if you want these to work in your game, SET UP THE GROUPS!

## Donk

`tph_notenode_donk.ogg`

Default instrument - played for every non-special block

Meant to act similar to Minecraft's Harp - but instead seems to sound like a mix of both the harp and pling (electric piano)

Made from flicking a button on a mouse - which seems connected to some form of spring

- no groups beyond `tph_notenode_donk`!


## Clack

`tph_notenode_clack.ogg`

Meant to imitate Minecraft's "Clicks and Sticks"

Made from scratching a plastic battery pack

- glass


## Metal

`tph_notenode_metal.ogg`

Basic metallic sound

Made from finger-flicking a bed frame metal pole

- metal
- metallic
- lodey


## Tin

`tph_notenode_tin.ogg`

Weird artificial bassy sound. Idea behind it was because "tin" IRL has a different sound - such as when you twist it - "tin cry". But this sound overall isn't good quality

Made from hitting the top of a plastic nutella container's lid

- refined_tin
- (IF NODECORE) adobe


## String Bass

`tph_notenode_stringbass.ogg`

Meant to imitate a bass instrument - and is plucky

Made from plucking a spread-out shoelace

- tree
- log


## Stone

`tph_notenode_stone.ogg`

Soft slightly-bassy hit sound. Like a pillow being hit

Made from dragging my fingers across a zipper

- stone
- material_stone
- boulder
- cobble
- ore
- (IF EXILE) masonry


## Bamboo

`tph_notenode_bambo.ogg`

Sounds sort-of marimba-y

Made from hitting an actual bamboo plant!

- sapling
- bamboo_block
- woody_plant


## Water

`tph_notenode_water.ogg`

Name is quite self-explanatory - water splash!

Made from moving around in a bathtub of water

- water


## Bottle Flute

`tph_notenode_bottleflute.ogg`

Air-y, somewhat made to imitate Minecraft's flute

Made from blowing into a glass bottle, x2 pitch

- clay
- flutey


## Xylophone

`tph_notenode_xylophone.ogg`

Bell-ish sound, xylophone-esque

Made from flicking at a glass bottle (same one as the bottle Flute!)

- refined_gold
- (IF AGE OF MENDING) gilded


## Doap

`tph_notenode_doap.ogg`

Poppy soft mallet pluck sound - sort of like hitting the top of a airy bottle

Made from pulling finger tightly out of a glass bottle (same one as the Bottle Flute!)

- rail
- pumpkin
- (IF AGE OF MENDING) item_arlior_growth
- (IF AGE OF MENDING) item_arlior_growth_purple


## Bowl Hit

`tph_notenode_bowlhit.ogg`

Literally a ceramic bowl being hit! Clank sound with some soft cowbell notes (if a cowbell learned vibrato!)

- ice
- pottery
- (IF AGE OF MENDING) terracotta


## Air Whistle

`tph_notenode_airwhistle.ogg`

Whistley airy sound

Made from me blowing a whistley sound with my mouth lol

- air


## Paper Snare

`tph_notenode_snarepaper.ogg`

Sort-of crackly imperfect snare sound

Made from me hitting a paper recyclable bag

- gravel
- item_gravel


## Metallic Twang

`tph_notenode_metallictwang.ogg`

Clicky mostly twang-y metallic sound

Made from flicking a small metal cooking pot

- copper


## Sonar

`tph_notenode_sonar.ogg`

Synthetic ding/telephone-like "operator" sound

Made from banging bits of my thermos - and then REALLY HEAVY editing

- snowy
- snow


## Metallic Pile

`tph_notenode_metallicpile`

Similar to a bunch of metal pipes falling - except lighter. Perhaps like thin poor quality chime bells, "celeste at home"

Made from banging metal coat hangers together

- (IF AGE OF MENDING) granite


## String

`tph_notenode_string.ogg`

Muted soft guitar-y sound

Made from plucking the string of a falling-apart sock

- material_wood
- wood
- planks


## Soft Horn

`tph_notenode_hornsoft.ogg`

Soft brassy trumpet-ish sound, sounds slightly animalistic

Made from blowing air with my mouth similar to Air Whistle - however shaping my lips differently

- flora
- fibrous_plant
- (IF REPIXTURE) plant


## Bell

`tph_notenode_bell.ogg`

Doorbell-esque sound, simple percussion bell sound

Made from flicking a small iron horseshoe

- chime
- (IF AGE OF MENDING) scaffolding


## Organ

`tph_notenode_organ.ogg`

Electronic organ sorta sound

Made from me humming weirdly - but heavily edited

- coalblock
- coalstone
- organ
- (IF AGE OF MENDING) item_compost


## Sawtooth

`tph_notenode_sawtooth.ogg`

Imperfect sawtooth-y sound

Made from me humming with my teeth - but also heavily edited!

- meseblock
- (IF AGE OF MENDING) glow_rock




# Game-Specific Instruments

Instruments created using the sound files provided in certain games! They will be unique to these games - and only possible on them!

## `Exile`

Instruments that play in Exile, specifically!

## Exile Bell (`exilebell`)

`artifacts_bell.ogg`

Uses the sound that the bell plays every 12 in-game hours (midnight, midday)

- no groups, uses the artifacts bell


## Exile Singing Stone (`exilesingstone`)

`artifacts_singing_stone.ogg`

Exile v4 exclusive! Uses the sound that the singing stones produce!

- no groups, uses the singing stones




# Mod-Specific Instruments

Instruments created using the sounds files provided in certain mods! Unique specifically to said mods - and no where else!

## `Nodecore Bells`

The one and only - uses the bell audio provided by GreenXenith's mod for Nodecore!

## Nodecore Bell (`ncbell`)

`ncbells_ding.ogg`

The bell sound that plays when you hit a Nodecore Bell with a mallet

- no groups, uses ncbell bells