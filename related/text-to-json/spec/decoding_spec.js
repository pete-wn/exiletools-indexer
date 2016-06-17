var frisby = require('frisby');
var baseurl = "http://localhost:9000";

frisby.create("[IDENTIFY] Prophecy: The Servant's Heart")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Normal
The Servant's Heart
--------
The Servant's sacrifice summons a storm in the Prodigy's soul.
--------
You will defeat Fidelitas while wielding Storm Cloud.
--------
Can only be completed in Cruel Difficulty
--------
Right-click to add this prophecy to your character.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "The Servant's Heart" },
    attributes : { 
      baseItemType : "Prophecy",
      rarity: "Normal",
      league: "Prophecy"
    }
  })
.toss();

frisby.create("[IDENTIFY] Prophecy: The Prison Guard")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Normal
The Prison Guard
--------
Clad in black, the guard holds the key to unleashing the storm.
--------
You will track down a powerful Axiom Thunderguard who will drop a unique item when slain.
--------
Can only be completed in Cruel Difficulty
--------
Right-click to add this prophecy to your character.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "The Prison Guard" },
    attributes : {
      baseItemType : "Prophecy",
      rarity: "Normal",
      league: "Prophecy"
    }
  })
.toss();

frisby.create("[IDENTIFY] Divination Card: Jack in the Box")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Normal
Jack in the Box
--------
Stack Size: 1/4
--------
Item
--------
Turn the crank, 
close your eyes, 
and pray to the gods 
for a pleasant surprise.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Jack in the Box" },
    attributes : {
      baseItemType : "Card",
      rarity: "Normal",
      league: "Prophecy"
    }
  })
.toss();


frisby.create("[IDENTIFY] Divination Card: The Carrion Crow")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Normal
The Carrion Crow
--------
Stack Size: 2/4
--------
Life Armour
--------
From death, life. 
From life, death. 
The wheel turns, 
and the corbies wheel overhead.
--------

Shift click to unstack.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "The Carrion Crow" },
    attributes : {
      baseItemType : "Card",
      rarity: "Normal",
      league: "Prophecy"
    }
  })
.toss();

frisby.create("[IDENTIFY] Map (Normal)")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Normal
Grotto Map
--------
Map Tier: 1
--------
Item Level: 60
--------
Travel to this Map by using it in the Eternal Laboratory or a personal Map Device. Maps can only be used once.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Grotto Map" },
    attributes : {
      baseItemType : "Map",
      rarity: "Normal",
      league: "Prophecy",
      ilvl: 60
    },
    properties : {
      Map : {
        "Map Tier": 1
      }
    }
  })
.toss();

frisby.create("[IDENTIFY] Vaal Fragment")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Normal
Sacrifice at Noon
--------
Item Level: 50
--------
The light without pales in comparison to the light within.
--------
Can be used in the Eternal Laboratory or a personal Map Device.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Sacrifice at Noon" },
    attributes : {
      baseItemType : "Vaal Fragment",
      rarity: "Normal",
      league: "Prophecy"
    }
  })
.toss();

frisby.create("[IDENTIFY] Map Fragment")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Normal
Volkuur's Key
--------
Item Level: 71
--------
She of Many Bodies, whose very flesh unites all,
whose dark whispers draw forth our souls, unfettered.
--------
Can be used in the Eternal Laboratory or a personal Map Device.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Volkuur's Key" },
    attributes : { 
      baseItemType : "Map Fragment",
      rarity: "Normal",
      league: "Prophecy"
    }
  })
.toss();

frisby.create("[IDENTIFY] Currency: Chaos Orb")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Currency
Chaos Orb
--------
Stack Size: 173/10
--------
Reforges a rare item with new random properties
--------
Right click this item then left click a rare item to apply it.
Shift click to unstack.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Chaos Orb" },
    attributes : {
      baseItemType : "Currency",
      rarity: "Currency",
      league: "Prophecy"
    }
  })
.toss();

frisby.create("[IDENTIFY] Currency: Exalted Orb")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Currency
Exalted Orb
--------
Stack Size: 17/10
--------
Enchants a rare item with a new random property
--------
Right click this item then left click a rare item to apply it. Rare items can have up to six random properties.
Shift click to unstack.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Exalted Orb" },
    attributes : {
      baseItemType : "Currency",
      rarity: "Currency",
      league: "Prophecy"
    }
  })
.toss();

frisby.create("[IDENTIFY] Gem: Summon Flame Golem lvl1 q13")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Gem
Summon Flame Golem
--------
Golem, Fire, Minion, Spell
Level: 1
Mana Cost: 30
Cooldown Time: 6.00 sec
Cast Time: 1.00 sec
Quality: +13% (augmented)
Experience: 1/252,595
--------
Requirements:
Level: 34
Str: 50
Int: 35
--------
Can raise up to 1 Golem at a time
13% increased Minion Damage
43% increased Minion Maximum Life
Golems Grant 15% increased Damage
--------
Place into an item socket of the right colour to gain this skill. Right click to remove from a socket.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Summon Flame Golem" },
    attributes : {
      baseItemType : "Gem",
      rarity: "Gem",
      league: "Prophecy"
    },
    properties : {
      Gem : {
        Level: 1,
        Quality: 13
      }
    }
  })
.toss();

frisby.create("[IDENTIFY] Gem: Tempest Shield lvl4")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Gem
Tempest Shield
--------
Spell, Lightning, Chaining, Duration
Level: 4
Mana Cost: 18
Cast Time: 0.50 sec
Critical Strike Chance: 6.00%
Damage Effectiveness: 60%
Experience: 86,337/199,345
--------
Requirements:
Level: 28
Str: 29
Int: 42
--------
Deals 48-72 Lightning Damage
Chain +1 Times
Base duration is 12.00 seconds
Additional 3% Shield Block Chance
--------
Place into an item socket of the right colour to gain this skill. Right click to remove from a socket.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Tempest Shield" },
    attributes : {
      baseItemType : "Gem",
      rarity: "Gem",
      league: "Prophecy"
    },
    properties : {
      Gem : {
        Level: 4
      }
    }
  })
.toss();

frisby.create("[IDENTIFY] Gem: Enlighten lvl2 q17 corrupted")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Gem
Enlighten Support
--------
Support
Level: 2
Mana Multiplier: 96%
Quality: +17% (augmented)
Experience: 792,851,397/1,439,190,228
--------
Requirements:
Level: 10
Int: 21
--------
This Gem gains 85% increased Experience
--------
This is a Support Gem. It does not grant a bonus to your character, but to skills in sockets connected to it. Place into an item socket connected to a socket containing the Active Skill Gem you wish to augment. Right click to remove from a socket.
--------
Corrupted`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Enlighten Support" },
    attributes : {
      baseItemType : "Gem",
      rarity: "Gem",
      corrupted: "true",
      league: "Prophecy"
    },
    properties : {
      Gem : {
        Level: 2,
        Quality: 17
      }
    }
  })
.toss();

frisby.create("[IDENTIFY] Gem: Frenzy l20 q23 corrupted")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Gem
Frenzy
--------
Attack, Melee, Bow
Level: 20 (Max)
Mana Cost: 10
Quality: +23% (augmented)
--------
Requirements:
Level: 70
Dex: 155
--------
5% increased Physical Damage per Frenzy Charge
Deals 136.6% of Base Attack Damage
11% increased Attack Speed
5% increased Attack Speed per Frenzy Charge
--------
Place into an item socket of the right colour to gain this skill. Right click to remove from a socket.
--------
Corrupted`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Frenzy" },
    attributes : {
      baseItemType : "Gem",
      rarity: "Gem",
      corrupted: "true",
      league: "Prophecy"
    },
    properties : {
      Gem : {
        Level: 20,
        Quality: 23
      }
    }
  })
.toss();



frisby.create("[IDENTIFY] Gem: Vaal Haste lvl19")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Gem
Vaal Haste
--------
Aura, Vaal, Spell, AoE, Duration
Level: 19
Mana Cost: 0
Souls Per Use: 24
Can Store 1 Use
Cast Time: 0.60 sec
Experience: 142,197,838/211,877,683
--------
Requirements:
Level: 68
Dex: 151
--------
Base duration is 6.00 seconds
39% increased Area of Effect radius
You and nearby allies gain 20% increased Movement Speed
You and nearby allies gain 36% increased Attack Speed
You and nearby allies gain 35% increased Cast Speed
--------
Place into an item socket of the right colour to gain this skill. Right click to remove from a socket.
--------
Corrupted`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Vaal Haste" },
    attributes : {
      baseItemType : "Gem",
      rarity: "Gem",
      corrupted: "true",
      league: "Prophecy"
    },
    properties : {
      Gem : {
        Level: 19
      }
    }
  })
.toss();

frisby.create("[IDENTIFY] Ungil's Gauche Boot Knife")
  .post(baseurl, {
    'league':'Prophecy',
    'text':`Rarity: Unique
Ungil's Gauche
Boot Knife
--------
Dagger
Physical Damage: 14-54 (augmented)
Elemental Damage: 3-30 (augmented)
Critical Strike Chance: 6.60%
Attacks per Second: 1.54 (augmented)
--------
Requirements:
Level: 20
Dex: 31
Int: 45
--------
Sockets: B 
--------
Item Level: 25
--------
40% increased Global Critical Strike Chance
--------
12% additional Block Chance while Dual Wielding
80% increased Physical Damage
+11 to Dexterity
Adds 3-30 Lightning Damage
10% increased Attack Speed
50% increased Global Critical Strike Chance
--------
Unwieldy and garish became graceful
and deadly in Ungil's nimble hands.`
  })
  .expectStatus(200)
  .expectJSON({
    info : { fullName : "Ungil's Gauche Boot Knife" },
    attributes : {
      baseItemType : "Weapon",
      rarity: "Unique",
      league: "Prophecy",
      itemType: "Dagger",
      equipType: "One Handed Melee Weapon"
    },
    properties : {
      Weapon : {
        "Physical Damage": {
          min: 14,
          max: 54,
          avg: 34
        },
        "Elemental Damage": {
          min: 3,
          max: 30,
          avg: 17
        },
        "Critical Strike Chance": 6.6,
        "Attacks per Second": 1.54,
        "Total DPS": 78,
        "Physical DPS": 52,
        "Elemental DPS": 26
      }
    },
    sockets: {
      allSocketsGGG: "B",
      largestLinkGroup: 1,
      socketCount: 1
    },
    mods: {
      Dagger: {
        implicit: {
          "#% increased Global Critical Strike Chance": 40
        },
        explicit: {
          "#% additional Block Chance while Dual Wielding": 12,
          "#% increased Physical Damage": 80,
          "+# to Dexterity": 11,
          "Adds #-# Lightning Damage": {
            min: 3,
            max: 30,
            avg: 16
          },
          "#% increased Attack Speed": 10,
          "#% increased Global Critical Strike Chance": 50
        }
      }
    },
    modsTotal: {
      "#% increased Global Critical Strike Chance": 90,
      "#% additional Block Chance while Dual Wielding": 12,
      "#% increased Physical Damage": 80,
      "+# to Dexterity": 11,
      "#% increased Attack Speed": 10
    }
  })
.toss();


//frisby.create("[IDENTIFY] ")
//  .post(baseurl, {
//    'league':'Prophecy',
//    'text':`
//  })
//  .expectStatus(200)
//  .expectJSON({
//    info : { fullName : "" },
//    attributes : {
//      baseItemType : "",
//      rarity: "",
//      league: "Prophecy"
//    }
//  })
//.toss();
