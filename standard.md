# Coding standard

## Default variables

res = function internal result array which is to be returned
pcur = the current prerequisite
qcur = the current queued tech
rcur = the current index of the result array
scur = the current successor
tcur = the current technology state
prop = a short lived array of properties

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

tech_name = LuaTechnology.name
meta = env.tech_meta
tstate = tech.state

## Init & structure

- Control inits storage, storage.forces and storage.players
- Control init triggers <module>.init including force/player
- Control on_force/on_player triggers <module>.init_force/init_player
- <module>.init does _not_ trigger <module>.init_force/init_player

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
