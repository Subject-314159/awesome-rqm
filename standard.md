# Coding standard

## Default variables

res = function internal result array which is to be returned
rcur = the current index of the result array
prop = a short lived array of properties
tech_name = LuaTechnology.name (or LuaTechnologyPrototype.name)

## References to in game classes

- Variables in lowercase refer to a live class
- Variables in UPPERCASE refer to a prototype
  p = LuaPlayer
  f = LuaForce
  t = LuaTechnology
  T = LuaTechnologyPrototype
  pre = LuaTechnology.prerequisite
  PRE = LuaTechnologyPrototype.prerequisite
  suc = LuaTechnology.successor
  SUC = LuaTechnologyPrototype.successor

## References to mod structures

-- Meta
meta = env.tech_meta{}
mcur = meta[tech_name]
msuc = meta[<t.successor>]
mpre = meta[<t.prerequisite>]

-- Tech state
tsx = tech.state_ext
xcur = tex[tech_name]
xsuc = tex[<t.successor>]
xpre = tex[<t.prerequisite>]

-- Queue
sfq = the actual force's queue{"tech-1", ...} array
q = a single queued "tech-1"

## Init & structure

- Control inits storage, storage.forces and storage.players
- Control init triggers <module>.init including force/player
- Control on_force/on_player triggers <module>.init_force/init_player
- <module>.init does *not* trigger <module>.init_force/init_player

## Data model

storage.<module>.<key> = {...}
storage.forces[force_index].<module>.<key> = {...}
storage.players[player_index].<module>.<key> = {...}

## Module order/dependencies

- Control

* lib

- const, util

* model
  -- env, state
  --- tech
  ---- queue
  ----- analyzer, cmd (lab?)
* view
  ---- gui
