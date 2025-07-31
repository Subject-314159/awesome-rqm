local const = {
    categories = {
        inserters = {
            research_effects = {"inserter-stack-size-bonus", "bulk-inserter-capacity-bonus", "belt-stack-size-bonus"},
            prototypes = {"inserter"}
        },
        belts = {
            prototypes = {"linked-belt", "transport-belt", "underground-belt", "lane-splitter", "splitter",
                          "belt-stack-size-bonus"}
        },
        crafting_machines = {
            prototypes = {"assembling-machine", "furnace", "rocket-silo"}
        },
        research = {
            research_effects = {"laboratory-speed", "laboratory-productivity"},
            prototypes = {"lab"}
        },
        logistics = {
            research_effects = {"character-logistic-trash-slots", "worker-robot-speed", "worker-robot-storage",
                                "max-failed-attempts-per-tick-per-construction-queue",
                                "max-successful-attempts-per-tick-per-construction-queue", "worker-robot-battery",
                                "character-logistic-requests", "vehicle-logistics"},
            prototypes = {"logistic-robot", "construction-robot", "roboport", "roboport-equipment"}
        },
        combat = {
            research_effects = {"turret-attack", "ammo-damage", "gun-speed", "artillery-range"},
            prototypes = {"active-defense-equipment", "ammo-turret", "artillery-turret", "electric-turret",
                          "fluid-turret"}
        },
        combat_robots = {
            research_effects = {"maximum-following-robots-count", "follower-robot-lifetime"},
            prototypes = {"combat-robot"}
        },
        character_bonus = {
            research_effects = {"character-logistic-trash-slots", "give-item", "character-crafting-speed",
                                "character-mining-speed", "character-running-speed", "character-build-distance",
                                "character-item-drop-distance", "character-reach-distance",
                                "character-resource-reach-distance", "character-item-pickup-distance",
                                "character-loot-pickup-distance", "character-inventory-slots-bonus",
                                "character-health-bonus", "character-logistic-requests"},
            prototypes = {"roboport-equipment", "active-defense-equipment", "battery-equipment",
                          "belt-immunity-equipment", "energy-shield-equipment", "equipment-ghost",
                          "generator-equipment", "inventory-bonus-equipment", "movement-bonus-equipment",
                          "night-vision-equipment", "solar-panel-equipment"}
        },
        recipes = {
            research_effects = {"unlock-recipe", "unlock-space-platforms", "unlock-circuit-network",
                                "cliff-deconstruction-enabled", "uranium-mining", "rail-support-on-deep-oil-ocean",
                                "rail-planner-allow-elevated-rails"},
            prototypes = {"recipe"}
        },
        misc = {
            research_effects = {"deconstruction-time-to-live", "nothing", "cargo-landing-pad-count",
                                "beacon-distribution"},
            prototypes = {}
        },
        effect_modifiers = {
            research_effects = {"mining-drill-productivity-bonus", "laboratory-productivity",
                                "change-recipe-productivity", "unlock-quality", "laboratory-speed",
                                "laboratory-productivity"},
            prototypes = {"beacon", "module"}
        },
        vehicles = {
            research_effects = {"train-braking-force-bonus", "rail-support-on-deep-oil-ocean",
                                "rail-planner-allow-elevated-rails"},
            prototypes = {"locomotive", "artillery-wagon", "cargo-wagon", "infinity-cargo-wagon", "fluid-wagon", "car",
                          "spider-vehicle"}
        },
        space = {
            research_effects = {"unlock-space-location", "unlock-space-platforms"},
            prototypes = {"space-location", "cargo-bay", "rocket-silo", "space-platform-hub",
                          "space-platform-starter-pack", "thruster", "asteroid-collector", "cargo-landing-pad"}
        }
    },
    default_settings = {
        player = {
            hide_tech = {
                disabled_tech = true,
                manual_trigger_tech = true,
                -- blacklisted_tech = true,
                -- completed_tech = true,
                inherited_tech = true,
                unavailable_successors = true
            },
            show_tech = {
                selected = "all"
            }
        },
        force = {}
    },
    no_propagate_settings = {
        player = {
            hide_tech = {"completed_tech", "inherited_tech"}
        }
    }
}
return const
