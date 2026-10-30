-- GENERATED 2026-10-30 - do not hand-edit
if (C_Seasons and C_Seasons.GetActiveSeason and C_Seasons.GetActiveSeason() == ((Enum and Enum.SeasonID and Enum.SeasonID.SeasonOfDiscovery) or 2)) then return end
RecommendedStatsData_Talents = {
    ["DRUID_BALANCE_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    35,
                    0,
                    16,
                },
                ["pct"] = 45,
            },
            {
                ["split"] = {
                    37,
                    0,
                    14,
                },
                ["pct"] = 35,
            },
            {
                ["split"] = {
                    38,
                    0,
                    13,
                },
                ["pct"] = 15,
            },
        },
        ["median"] = {
            37,
            0,
            14,
        },
    },
    ["DRUID_FERAL_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    14,
                    32,
                    5,
                },
                ["pct"] = 100,
            },
        },
        ["median"] = {
            14,
            32,
            5,
        },
    },
    ["DRUID_GUARDIAN_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    11,
                    33,
                    7,
                },
                ["pct"] = 65,
            },
            {
                ["split"] = {
                    14,
                    32,
                    5,
                },
                ["pct"] = 25,
            },
            {
                ["split"] = {
                    13,
                    33,
                    5,
                },
                ["pct"] = 5,
            },
        },
        ["median"] = {
            11,
            33,
            7,
        },
    },
    ["DRUID_RESTORATION_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    24,
                    0,
                    27,
                },
                ["pct"] = 30,
            },
            {
                ["split"] = {
                    12,
                    0,
                    39,
                },
                ["pct"] = 30,
            },
            {
                ["split"] = {
                    7,
                    0,
                    44,
                },
                ["pct"] = 10,
            },
        },
        ["median"] = {
            12,
            0,
            39,
        },
    },
    ["HUNTER_MARKSMANSHIP_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    20,
                    31,
                    0,
                },
                ["pct"] = 85,
            },
            {
                ["split"] = {
                    7,
                    31,
                    13,
                },
                ["pct"] = 10,
            },
            {
                ["split"] = {
                    5,
                    31,
                    15,
                },
                ["pct"] = 5,
            },
        },
        ["median"] = {
            20,
            31,
            0,
        },
    },
    ["MAGE_FIRE_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    13,
                    35,
                    3,
                },
                ["pct"] = 65,
            },
            {
                ["split"] = {
                    12,
                    36,
                    3,
                },
                ["pct"] = 20,
            },
            {
                ["split"] = {
                    11,
                    37,
                    3,
                },
                ["pct"] = 10,
            },
        },
        ["median"] = {
            13,
            35,
            3,
        },
    },
    ["MAGE_ARCANE_RAID"] = {
        ["n"] = 16,
        ["builds"] = {
            {
                ["split"] = {
                    31,
                    0,
                    20,
                },
                ["pct"] = 94,
            },
            {
                ["split"] = {
                    33,
                    0,
                    18,
                },
                ["pct"] = 6,
            },
        },
        ["median"] = {
            31,
            0,
            20,
        },
    },
    ["MAGE_FROST_RAID"] = {
        ["n"] = 4,
        ["builds"] = {
            {
                ["split"] = {
                    15,
                    0,
                    36,
                },
                ["pct"] = 25,
            },
            {
                ["split"] = {
                    22,
                    0,
                    29,
                },
                ["pct"] = 25,
            },
            {
                ["split"] = {
                    13,
                    0,
                    38,
                },
                ["pct"] = 25,
            },
        },
        ["median"] = {
            19,
            0,
            36,
        },
    },
    ["PALADIN_HOLY_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    35,
                    11,
                    5,
                },
                ["pct"] = 65,
            },
            {
                ["split"] = {
                    31,
                    20,
                    0,
                },
                ["pct"] = 10,
            },
            {
                ["split"] = {
                    32,
                    14,
                    5,
                },
                ["pct"] = 10,
            },
        },
        ["median"] = {
            35,
            11,
            5,
        },
    },
    ["PALADIN_PROTECTION_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    11,
                    31,
                    9,
                },
                ["pct"] = 70,
            },
            {
                ["split"] = {
                    11,
                    32,
                    8,
                },
                ["pct"] = 10,
            },
            {
                ["split"] = {
                    11,
                    33,
                    7,
                },
                ["pct"] = 5,
            },
        },
        ["median"] = {
            11,
            31,
            9,
        },
    },
    ["PALADIN_RETRIBUTION_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    11,
                    8,
                    32,
                },
                ["pct"] = 60,
            },
            {
                ["split"] = {
                    11,
                    9,
                    31,
                },
                ["pct"] = 10,
            },
            {
                ["split"] = {
                    18,
                    0,
                    33,
                },
                ["pct"] = 5,
            },
        },
        ["median"] = {
            11,
            8,
            32,
        },
    },
    ["PRIEST_HOLY_RAID"] = {
        ["n"] = 16,
        ["builds"] = {
            {
                ["split"] = {
                    21,
                    30,
                    0,
                },
                ["pct"] = 63,
            },
            {
                ["split"] = {
                    19,
                    32,
                    0,
                },
                ["pct"] = 38,
            },
        },
        ["median"] = {
            21,
            30,
            0,
        },
    },
    ["PRIEST_DISCIPLINE_RAID"] = {
        ["n"] = 6,
        ["builds"] = {
            {
                ["split"] = {
                    31,
                    20,
                    0,
                },
                ["pct"] = 67,
            },
            {
                ["split"] = {
                    32,
                    19,
                    0,
                },
                ["pct"] = 33,
            },
        },
        ["median"] = {
            31,
            20,
            0,
        },
    },
    ["PRIEST_SHADOW_RAID"] = {
        ["n"] = 18,
        ["builds"] = {
            {
                ["split"] = {
                    14,
                    0,
                    37,
                },
                ["pct"] = 28,
            },
            {
                ["split"] = {
                    16,
                    0,
                    35,
                },
                ["pct"] = 22,
            },
            {
                ["split"] = {
                    20,
                    0,
                    31,
                },
                ["pct"] = 17,
            },
        },
        ["median"] = {
            16,
            0,
            35,
        },
    },
    ["ROGUE_COMBAT_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    20,
                    31,
                    0,
                },
                ["pct"] = 55,
            },
            {
                ["split"] = {
                    15,
                    31,
                    5,
                },
                ["pct"] = 35,
            },
            {
                ["split"] = {
                    19,
                    32,
                    0,
                },
                ["pct"] = 10,
            },
        },
        ["median"] = {
            20,
            31,
            0,
        },
    },
    ["SHAMAN_ELEMENTAL_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    31,
                    0,
                    20,
                },
                ["pct"] = 90,
            },
            {
                ["split"] = {
                    30,
                    0,
                    21,
                },
                ["pct"] = 10,
            },
        },
        ["median"] = {
            31,
            0,
            20,
        },
    },
    ["SHAMAN_ENHANCEMENT_RAID"] = {
        ["n"] = 21,
        ["builds"] = {
            {
                ["split"] = {
                    5,
                    32,
                    14,
                },
                ["pct"] = 24,
            },
            {
                ["split"] = {
                    0,
                    32,
                    19,
                },
                ["pct"] = 19,
            },
            {
                ["split"] = {
                    20,
                    31,
                    0,
                },
                ["pct"] = 14,
            },
        },
        ["median"] = {
            5,
            32,
            14,
        },
    },
    ["SHAMAN_RESTORATION_RAID"] = {
        ["n"] = 19,
        ["builds"] = {
            {
                ["split"] = {
                    0,
                    5,
                    46,
                },
                ["pct"] = 63,
            },
            {
                ["split"] = {
                    8,
                    5,
                    38,
                },
                ["pct"] = 16,
            },
            {
                ["split"] = {
                    8,
                    7,
                    36,
                },
                ["pct"] = 5,
            },
        },
        ["median"] = {
            0,
            5,
            46,
        },
    },
    ["WARLOCK_DESTRUCTION_RAID"] = {
        ["n"] = 8,
        ["builds"] = {
            {
                ["split"] = {
                    7,
                    21,
                    23,
                },
                ["pct"] = 75,
            },
            {
                ["split"] = {
                    0,
                    21,
                    30,
                },
                ["pct"] = 13,
            },
            {
                ["split"] = {
                    8,
                    21,
                    22,
                },
                ["pct"] = 13,
            },
        },
        ["median"] = {
            7,
            21,
            23,
        },
    },
    ["WARLOCK_DEMONOLOGY_RAID"] = {
        ["n"] = 11,
        ["builds"] = {
            {
                ["split"] = {
                    9,
                    21,
                    21,
                },
                ["pct"] = 91,
            },
            {
                ["split"] = {
                    0,
                    30,
                    21,
                },
                ["pct"] = 9,
            },
        },
        ["median"] = {
            9,
            21,
            21,
        },
    },
    ["WARLOCK_AFFLICTION_RAID"] = {
        ["n"] = 1,
        ["builds"] = {
            {
                ["split"] = {
                    30,
                    0,
                    21,
                },
                ["pct"] = 100,
            },
        },
        ["median"] = {
            30,
            0,
            21,
        },
    },
    ["WARRIOR_FURY_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    17,
                    34,
                    0,
                },
                ["pct"] = 100,
            },
        },
        ["median"] = {
            17,
            34,
            0,
        },
    },
    ["WARRIOR_PROTECTION_RAID"] = {
        ["n"] = 20,
        ["builds"] = {
            {
                ["split"] = {
                    17,
                    34,
                    0,
                },
                ["pct"] = 40,
            },
            {
                ["split"] = {
                    2,
                    33,
                    16,
                },
                ["pct"] = 20,
            },
            {
                ["split"] = {
                    3,
                    32,
                    16,
                },
                ["pct"] = 20,
            },
        },
        ["median"] = {
            3,
            33,
            16,
        },
    },
}
