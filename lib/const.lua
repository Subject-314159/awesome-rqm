-- All static constants are stored in this module
local const = {}

const.categories = {
    all = {},
    essential = {},
    infinite = {},
    inserters = {
        research_effects = {"inserter-stack-size-bonus", "bulk-inserter-capacity-bonus", "belt-stack-size-bonus"},
        research_prototypes = {"inserter"}
    },
    belts = {
        research_prototypes = {"linked-belt", "transport-belt", "underground-belt", "lane-splitter", "splitter",
                               "belt-stack-size-bonus"}
    },
    crafting_machines = {
        research_prototypes = {"assembling-machine", "furnace", "rocket-silo"}
    },
    research = {
        research_effects = {"laboratory-speed", "laboratory-productivity"},
        research_prototypes = {"lab", "tool"} -- TODO: Do not look at prototype tool but get all science items dynamically
    },
    logistics = {
        research_effects = {"character-logistic-trash-slots", "worker-robot-speed", "worker-robot-storage",
                            "max-failed-attempts-per-tick-per-construction-queue",
                            "max-successful-attempts-per-tick-per-construction-queue", "worker-robot-battery",
                            "character-logistic-requests", "vehicle-logistics"},
        research_prototypes = {"logistic-robot", "construction-robot", "roboport", "roboport-equipment"}
    },
    combat = {
        research_effects = {"turret-attack", "ammo-damage", "gun-speed", "artillery-range"},
        research_prototypes = {"active-defense-equipment", "ammo-turret", "artillery-turret", "electric-turret",
                               "fluid-turret", "ammo", "capsule", "gun"}
    },
    combat_robots = {
        research_effects = {"maximum-following-robots-count", "follower-robot-lifetime"},
        research_prototypes = {"combat-robot"}
    },
    character_bonus = {
        research_effects = {"character-logistic-trash-slots", "give-item", "character-crafting-speed",
                            "character-mining-speed", "character-running-speed", "character-build-distance",
                            "character-item-drop-distance", "character-reach-distance",
                            "character-resource-reach-distance", "character-item-pickup-distance",
                            "character-loot-pickup-distance", "character-inventory-slots-bonus",
                            "character-health-bonus", "character-logistic-requests"},
        research_prototypes = {"roboport-equipment", "active-defense-equipment", "battery-equipment",
                               "belt-immunity-equipment", "energy-shield-equipment", "equipment-ghost",
                               "generator-equipment", "inventory-bonus-equipment", "movement-bonus-equipment",
                               "night-vision-equipment", "solar-panel-equipment"}
    },
    recipes = {
        research_effects = {"unlock-recipe"},
        research_prototypes = {"recipe"}
    },
    effect_modifiers = {
        research_effects = {"mining-drill-productivity-bonus", "laboratory-productivity", "change-recipe-productivity",
                            "unlock-quality", "laboratory-speed", "laboratory-productivity"},
        research_prototypes = {"beacon", "module"}
    },
    vehicles = {
        research_effects = {"train-braking-force-bonus", "rail-support-on-deep-oil-ocean",
                            "rail-planner-allow-elevated-rails"},
        research_prototypes = {"locomotive", "artillery-wagon", "cargo-wagon", "infinity-cargo-wagon", "fluid-wagon",
                               "car", "spider-vehicle", "spidertron-remote"}
    },
    space = {
        research_effects = {"unlock-space-location", "unlock-space-platforms"},
        research_prototypes = {"space-location", "cargo-bay", "rocket-silo", "space-platform-hub",
                               "space-platform-starter-pack", "thruster", "asteroid-collector", "cargo-landing-pad",
                               "cargo-landing-pad-count"}
    },
    misc = {
        research_effects = {"deconstruction-time-to-live", "nothing", "beacon-distribution", "unlock-circuit-network",
                            "uranium-mining", "cliff-deconstruction-enabled"},
        research_prototypes = {"blueprint-book", "selection-tool", "blueprint", "copy-paste-tool",
                               "deconstruction-item", "upgrade-item"}
    }
}

const.announcements = {"start_finish_all", "finish_all", "finish_queued", "updates_only"}

const.default_settings = {
    startup = {"rqm-startup_tech-shortcut-opens-rqm-instead"},
    player = {
        hide_tech = {
            disabled_tech = true,
            manual_trigger_tech = false,
            infinite_tech = false,
            inherited_tech = true,
            unavailable_successors = false
        },
        show_tech = {
            selected = "all"
        },
        settings_tab = {
            use_manual_lowercase_map = false
        }
    },
    force = {
        master_enable = "right",
        research_queue_cleanup_timeout = 30 * 60, -- seconds * ticks
        research_progress_average_ticks = 30,
        announcement_level = "updates_only",
        settings = {
            -- announce_research_finished = false,
            requeue_infinite_tech = true
        },
        queue_blocking_tech = {
            disabled_tech = true,
            manual_trigger_tech = true,
            unavailable_successors = true
        }
    }
}

const.no_propagate_settings = {
    player = {
        hide_tech = {"tech_is_completed", "tech_is_inherited"}
    }
}

const.lower_map = {
    -- Latin basic + extended for be,bg,ca,cs,da,de,en,eo,es,et,fi,fr,ga,hr,hu,id,it,lt,lv,nl,no,pl,pt,ro,sk,sl,sr,sv,vi
    ["A"] = "a",
    ["B"] = "b",
    ["C"] = "c",
    ["D"] = "d",
    ["E"] = "e",
    ["F"] = "f",
    ["G"] = "g",
    ["H"] = "h",
    ["I"] = "i",
    ["J"] = "j",
    ["K"] = "k",
    ["L"] = "l",
    ["M"] = "m",
    ["N"] = "n",
    ["O"] = "o",
    ["P"] = "p",
    ["Q"] = "q",
    ["R"] = "r",
    ["S"] = "s",
    ["T"] = "t",
    ["U"] = "u",
    ["V"] = "v",
    ["W"] = "w",
    ["X"] = "x",
    ["Y"] = "y",
    ["Z"] = "z",
    -- Latin-1 Supplement
    ["À"] = "à",
    ["Á"] = "á",
    ["Â"] = "â",
    ["Ã"] = "ã",
    ["Ä"] = "ä",
    ["Å"] = "å",
    ["Æ"] = "æ",
    ["Ç"] = "ç",
    ["È"] = "è",
    ["É"] = "é",
    ["Ê"] = "ê",
    ["Ë"] = "ë",
    ["Ì"] = "ì",
    ["Í"] = "í",
    ["Î"] = "î",
    ["Ï"] = "ï",
    ["Ð"] = "ð",
    ["Ñ"] = "ñ",
    ["Ò"] = "ò",
    ["Ó"] = "ó",
    ["Ô"] = "ô",
    ["Õ"] = "õ",
    ["Ö"] = "ö",
    ["Ø"] = "ø",
    ["Ù"] = "ù",
    ["Ú"] = "ú",
    ["Û"] = "û",
    ["Ü"] = "ü",
    ["Ý"] = "ý",
    ["Þ"] = "þ",
    -- Latin Extended-A
    ["Ā"] = "ā",
    ["Ă"] = "ă",
    ["Ą"] = "ą",
    ["Ć"] = "ć",
    ["Ĉ"] = "ĉ",
    ["Ċ"] = "ċ",
    ["Č"] = "č",
    ["Ď"] = "ď",
    ["Đ"] = "đ",
    ["Ē"] = "ē",
    ["Ĕ"] = "ĕ",
    ["Ė"] = "ė",
    ["Ę"] = "ę",
    ["Ě"] = "ě",
    ["Ĝ"] = "ĝ",
    ["Ğ"] = "ğ",
    ["Ġ"] = "ġ",
    ["Ģ"] = "ģ",
    ["Ĥ"] = "ĥ",
    ["Ħ"] = "ħ",
    ["Ĩ"] = "ĩ",
    ["Ī"] = "ī",
    ["Ĭ"] = "ĭ",
    ["Į"] = "į",
    ["İ"] = "i",
    ["Ĳ"] = "ĳ",
    ["Ĵ"] = "ĵ",
    ["Ķ"] = "ķ",
    ["Ĺ"] = "ĺ",
    ["Ļ"] = "ļ",
    ["Ľ"] = "ľ",
    ["Ŀ"] = "ŀ",
    ["Ł"] = "ł",
    ["Ń"] = "ń",
    ["Ņ"] = "ņ",
    ["Ň"] = "ň",
    ["Ŋ"] = "ŋ",
    ["Ō"] = "ō",
    ["Ŏ"] = "ŏ",
    ["Ő"] = "ő",
    ["Œ"] = "œ",
    ["Ŕ"] = "ŕ",
    ["Ŗ"] = "ŗ",
    ["Ř"] = "ř",
    ["Ś"] = "ś",
    ["Ŝ"] = "ŝ",
    ["Ş"] = "ş",
    ["Š"] = "š",
    ["Ţ"] = "ţ",
    ["Ť"] = "ť",
    ["Ŧ"] = "ŧ",
    ["Ũ"] = "ũ",
    ["Ū"] = "ū",
    ["Ŭ"] = "ŭ",
    ["Ů"] = "ů",
    ["Ű"] = "ű",
    ["Ų"] = "ų",
    ["Ŵ"] = "ŵ",
    ["Ŷ"] = "ŷ",
    ["Ÿ"] = "ÿ",
    ["Ź"] = "ź",
    ["Ż"] = "ż",
    ["Ž"] = "ž",
    -- Greek (el)
    ["Α"] = "α",
    ["Β"] = "β",
    ["Γ"] = "γ",
    ["Δ"] = "δ",
    ["Ε"] = "ε",
    ["Ζ"] = "ζ",
    ["Η"] = "η",
    ["Θ"] = "θ",
    ["Ι"] = "ι",
    ["Κ"] = "κ",
    ["Λ"] = "λ",
    ["Μ"] = "μ",
    ["Ν"] = "ν",
    ["Ξ"] = "ξ",
    ["Ο"] = "ο",
    ["Π"] = "π",
    ["Ρ"] = "ρ",
    ["Σ"] = "σ",
    ["Τ"] = "τ",
    ["Υ"] = "υ",
    ["Φ"] = "φ",
    ["Χ"] = "χ",
    ["Ψ"] = "ψ",
    ["Ω"] = "ω",
    ["Ά"] = "ά",
    ["Έ"] = "έ",
    ["Ή"] = "ή",
    ["Ί"] = "ί",
    ["Ό"] = "ό",
    ["Ύ"] = "ύ",
    ["Ώ"] = "ώ",
    ["Ϊ"] = "ϊ",
    ["Ϋ"] = "ϋ",
    -- Cyrillic (be,bg,kk,ru,sr,uk)
    ["А"] = "а",
    ["Б"] = "б",
    ["В"] = "в",
    ["Г"] = "г",
    ["Д"] = "д",
    ["Е"] = "е",
    ["Ё"] = "ё",
    ["Ж"] = "ж",
    ["З"] = "з",
    ["И"] = "и",
    ["Й"] = "й",
    ["К"] = "к",
    ["Л"] = "л",
    ["М"] = "м",
    ["Н"] = "н",
    ["О"] = "о",
    ["П"] = "п",
    ["Р"] = "р",
    ["С"] = "с",
    ["Т"] = "т",
    ["У"] = "у",
    ["Ф"] = "ф",
    ["Х"] = "х",
    ["Ц"] = "ц",
    ["Ч"] = "ч",
    ["Ш"] = "ш",
    ["Щ"] = "щ",
    ["Ъ"] = "ъ",
    ["Ы"] = "ы",
    ["Ь"] = "ь",
    ["Э"] = "э",
    ["Ю"] = "ю",
    ["Я"] = "я",
    ["І"] = "і",
    ["Ї"] = "ї",
    ["Є"] = "є",
    ["Ґ"] = "ґ",
    ["Қ"] = "қ",
    ["Ә"] = "ә",
    ["Ө"] = "ө",
    ["Ү"] = "ү",
    ["Ұ"] = "ұ",
    ["Һ"] = "һ",
    ["Ң"] = "ң"
}

return const
