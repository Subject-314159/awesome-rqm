# Coding standard

## Default variables

res = function internal result array which is to be returned
rcur = the current index of the result array
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
tech_meta = env.tech_meta[tech_name]

## Init & structure

- Control inits storage, storage.forces and storage.players
- Control init triggers <module>.init including force/player
- Control on_force/on_player triggers <module>.init_force/init_player
- <module>.init does *not* trigger <module>.init_force/init_player

## Module order/dependencies

- Control
+ lib
- const, util
+ model
-- env, state
--- tech
---- queue
----- analyzer, cmd (lab?)
+ view
---- gui