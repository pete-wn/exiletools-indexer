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
