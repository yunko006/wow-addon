-- PIGlow Spell Database
-- CD (in seconds) of the main DPS cooldown per spec
-- specID: https://warcraft.wiki.gg/wiki/SpecializationID

PIGlow_SpellDB = {
    -- Death Knight
    [250] = { spec = "Blood DK",        spell = "Dancing Rune Weapon", cd = 120 },
    [251] = { spec = "Frost DK",        spell = "Pillar of Frost",    cd = 60 },
    [252] = { spec = "Unholy DK",       spell = "Apocalypse",         cd = 45 },
    -- Demon Hunter
    [577] = { spec = "Havoc DH",        spell = "Metamorphosis",      cd = 120 },
    [581] = { spec = "Vengeance DH",    spell = "Fel Devastation",    cd = 60 },
    -- Druid
    [102] = { spec = "Balance Druid",   spell = "Celestial Alignment",cd = 120 },
    [103] = { spec = "Feral Druid",     spell = "Berserk",            cd = 120 },
    [104] = { spec = "Guardian Druid",  spell = "Incarnation",        cd = 180 },
    [105] = { spec = "Resto Druid",     spell = "Tranquility",        cd = 180 },
    -- Evoker
    [1467] = { spec = "Devastation Evoker", spell = "Dragonrage",     cd = 120 },
    [1468] = { spec = "Preservation Evoker", spell = "Dream Flight",  cd = 120 },
    [1473] = { spec = "Augmentation Evoker", spell = "Ebon Might",    cd = 30 },
    -- Hunter
    [253] = { spec = "BM Hunter",       spell = "Bestial Wrath",      cd = 90 },
    [254] = { spec = "MM Hunter",       spell = "Trueshot",           cd = 120 },
    [255] = { spec = "Survival Hunter", spell = "Coordinated Assault",cd = 120 },
    -- Mage
    [62]  = { spec = "Arcane Mage",     spell = "Arcane Surge",       cd = 90 },
    [63]  = { spec = "Fire Mage",       spell = "Combustion",         cd = 120 },
    [64]  = { spec = "Frost Mage",      spell = "Frozen Orb",         cd = 60 },
    -- Monk
    [268] = { spec = "Brewmaster Monk", spell = "Weapons of Order",   cd = 120 },
    [269] = { spec = "Windwalker Monk", spell = "Storm, Earth, Fire", cd = 120 },
    [270] = { spec = "Mistweaver Monk", spell = "Revival",            cd = 180 },
    -- Paladin
    [65]  = { spec = "Holy Paladin",    spell = "Avenging Wrath",     cd = 120 },
    [66]  = { spec = "Prot Paladin",    spell = "Avenging Wrath",     cd = 120 },
    [70]  = { spec = "Ret Paladin",     spell = "Avenging Wrath",     cd = 120 },
    -- Priest
    [256] = { spec = "Disc Priest",     spell = "Evangelism",         cd = 90 },
    [257] = { spec = "Holy Priest",     spell = "Divine Hymn",        cd = 180 },
    [258] = { spec = "Shadow Priest",   spell = "Void Eruption",      cd = 120 },
    -- Rogue
    [259] = { spec = "Assassination Rogue", spell = "Deathmark",      cd = 120 },
    [260] = { spec = "Outlaw Rogue",    spell = "Adrenaline Rush",    cd = 180 },
    [261] = { spec = "Sub Rogue",       spell = "Shadow Dance",       cd = 60 },
    -- Shaman
    [262] = { spec = "Elemental Shaman",spell = "Ascendance",         cd = 120 },
    [263] = { spec = "Enhancement Shaman", spell = "Feral Spirit",    cd = 90 },
    [264] = { spec = "Resto Shaman",    spell = "Healing Tide Totem", cd = 180 },
    -- Warlock
    [265] = { spec = "Affliction Lock",  spell = "Summon Darkglare",  cd = 120 },
    [266] = { spec = "Demonology Lock",  spell = "Demonic Tyrant",    cd = 60 },
    [267] = { spec = "Destruction Lock",  spell = "Summon Infernal",  cd = 120 },
    -- Warrior
    [71]  = { spec = "Arms Warrior",    spell = "Colossus Smash",     cd = 45 },
    [72]  = { spec = "Fury Warrior",    spell = "Recklessness",       cd = 90 },
    [73]  = { spec = "Prot Warrior",    spell = "Avatar",             cd = 90 },
}
