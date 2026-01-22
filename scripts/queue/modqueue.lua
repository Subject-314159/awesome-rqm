local modqueue = {}

----------------------------------------------------------------------------------------------------
--- Data model
----------------------------------------------------------------------------------------------------
--- storage.forces[force_index].queue[] = {
---     technology = technology
---     prerequisites[] = {
---         technology = technology
---         is_blocked = bool
---         is_blocked_by[] = localized_technology_name
---     }
---     is_blocked = bool
--- }

return modqueue
