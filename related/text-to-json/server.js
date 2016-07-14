var express = require('express');
var app = express();
var bodyParser = require('body-parser');
var _ = require('lodash');

// Read in the itemType.json file - we're doing this synchronously on purpose
var itemNames = require('./data/itemName-to-itemType.json');
var itemNamesSizeCheck = _.size(itemNames);
if (itemNamesSizeCheck > 800) {
  console.log("STARTUP: Loaded " + itemNamesSizeCheck + " item names from itemName-to-itemType.json");
} else {
  console.log("FATAL: Something went wrong loading itemName-to-itemType.json data!");
  console.log("Only " + itemNamesSizeCheck + " items were loaded, expected 800+!!");
  process.exit(1);
}

var itemTypes = require('./data/itemType-to-baseItemType.json');
var equipTypes = require('./data/itemName-to-equipType.json');


app.use(express.static('public'));

var urlencodedParser = bodyParser.urlencoded({ extended: false })

app.get('/', function (req, res) {
  res.sendFile( __dirname + "/" + "index.html" );
});

app.post('/', urlencodedParser, function (req, res) {
  console.log("Got a POST request for the homepage");

  if (req.body.text) {
    var item = parseItem(req.body.text, req.body.league);
    res.send(JSON.stringify(item));
  } else {
    var error = { error : "Text not found in request body!" };
    throw(JSON.stringify(error));
  }
})

app.listen(9000, function () {
  console.log('Example app listening on port 9000!');
});


function parseItem(text, league) {
  var item = new Object();
  item.info = new Object(); 
  item.attributes = new Object(); 
  item.attributes.league = league;

  // Note, we need to remove this after we've written mod parsing subroutines
  item.debug = new Object;

  // Remove unnecessary \r\n nonsense so we can filter by newlines properly
  text = text.replace(/\r\n/g, "\n")

  // Split the item text into an array based on the default separator
  // NOTE: Different items will have different numbers of slices and
  // the slice where specific information sits will change, however
  // the first slice always appears to contain rarity and name
  // (also note we remove any empty values just in case)
  var infoArray = _.compact(text.split(/\n--------\n/));

  // The infoArray must be a minimum of 4 elements - at time of
  // writing I'm not aware of any item which has less than 4 elements
  if (infoArray.length < 3) {
    var error = { error : "Valid item data should have at least three elements separated by dashes!" };
    throw(JSON.stringify(error));
  }


  // Split the first slice by newlines while removing empty values
  var nameArray = _.compact(infoArray[0].split(/\n/));

  // The name array must have two elements or it is incomplete
  if (nameArray.length < 2) {
    var error = { error : "First slice of clipboard data is too small - missing either name or rarity!" };
    throw(JSON.stringify(error));
  }

  // Check the first line of the first slice for the Item Rarity
  if (nameArray[0].match(/Rarity:/)) {
    var itemRarity = nameArray[0].match(/Rarity: (.*)/);
    item.attributes.rarity = itemRarity[1];
  } else {
    var error = { error : "Could not determine item rarity from line 1 of item text. Text must start with Rarity:" };
    throw(JSON.stringify(error)); 
  }

  // Populate the item name based on the second and optional third line of the first slice
  if (nameArray[2]) {
    item.info.fullName = nameArray[1] + " " + nameArray[2];
  } else {
    item.info.fullName = nameArray[1];
  }

  // Detect if the item is corrupted
  if (infoArray.indexOf("Corrupted") > -1) {
    item.attributes.corrupted = "true";
  }

  // Here's where things get tricky. Different item types have different data in the second slice.
  // * Maps: Map Tier, Quantity, Rarity
  // * Currency: Stack Size
  // * Gems: Gem information
  // * Divination Card: Stack Size
  // * Prophecy: flavour text
  // Other items: We'll do a base item lookup. Unfortunately this will ONLY work with uniques and
  //  rares, because normal items are a huge PITA. We might add support for that later.
  //
  // To do analysis, we need to look at some other data to optimize things.
  // rarity: Gem or Currency tell us what to look for in this slice
  // if the item has rarity:Normal and a Stack Size in this slice, it's a Div Card
  // blah blah
  //
  // Instead of just looking at the second slice, let's start by finding ANY
  // slice that starts with various things we know. 

  // OY OY OY ADD UNIDENTIFIED ITEM SUPPORT PEW PEW


  // PROPHECY:
  // If an item is normal and has the text "Right-click to add this prophecy to your character"
  // then it is a prophecy.
  if (item.attributes.rarity == "Normal" && infoArray.indexOf("Right-click to add this prophecy to your character.") > -1) {
    item.attributes.baseItemType = "Prophecy";
    return(item);

  // DIVINATION CARD:
  // If an item is normal and has a Stack Size, then it should be a Divination Card
  } else if (item.attributes.rarity == "Normal" && infoArray[1].match(/Stack Size:/)) {
    item.attributes.baseItemType = "Card";
    return(item);

  // MAPS:
  // if infoArray[1] contains "Map Tier:" then it's a map
  } else if (infoArray[1].match(/Map Tier:/)) {
    item.attributes.baseItemType = "Map";
    item.properties = new Object();
    item.properties.Map = new Object();
    // Extract the map properties from infoArray[1] by iterating on them
    // and converting them to numbers since they will always be properties.Map.[prop] = ###
    var thisInfo = _.compact(infoArray[1].split(/\n/));
    thisInfo.forEach(function (element) {
      var decodedProps = parseProperties(element);
      item.properties.Map[decodedProps[0]] = decodedProps[1];
    });

    // for maps, infoArray[2] should always be the Item Level
    if (infoArray[2].match(/Item Level:/)) {
      thisProperty = infoArray[2].split(": ");
      item.attributes.ilvl = Number(thisProperty[1]);
    }

    // next for maps, infoArray[3] will contain mods if the item isn't normal, and maps don't
    // have implicit mods - OR DO THEY?!?!?!
    if (item.attributes.rarity != "Normal") {
      item.mods = new Object;
      item.mods.Map = new Object;
      item.mods.Map.explicit = new Object;
      var thisInfo = _.compact(infoArray[3].split(/\n/));
      thisInfo.forEach(function (element) {
        var decodedMods = parseMod(element);
        item.mods.Map.explicit[decodedMods[0]] = decodedMods[1];
      });
    }

    return(item);

  // Map / Vaal Fragments
  // If the item is Normal rarity and says "Can be used in the Eternal Laboratory or a personal Map Device."
  // it is probably a map fragment or vaal fragment
  } else if (item.attributes.rarity == "Normal" && infoArray.indexOf("Can be used in the Eternal Laboratory or a personal Map Device.") > -1) {
    // If it has "Sacrifice at" or "Mortal" in the name then it's a vaal fragment, else a map fragment
    if (item.info.fullName.match(/^Sacrifice at/) || item.info.fullName.match(/^Mortal /)) {
      item.attributes.baseItemType = "Vaal Fragment";
    } else {
      item.attributes.baseItemType = "Map Fragment";
    }
    return(item);

  // CURRENCY detection
  // let's allow the macro to do some basic currency rates
  } else if (item.attributes.rarity == "Currency") {
    item.attributes.baseItemType = "Currency";
    return(item);

  // GEM detection
  // We need to detect the Gem name, level, and quality only for this
  // That means we need to ignore a bunch of other properties
  } else if (item.attributes.rarity == "Gem") {
    item.attributes.baseItemType = "Gem";
    item.properties = new Object();
    item.properties.Gem = new Object();
    var thisInfo = _.compact(infoArray[1].split(/\n/));
    thisInfo.forEach(function (element) {
      // this ignores the spell properties line as well, i.e. "Golem, Fire, Minion"
      if (element.match(/:/)) {
        var decodedProps = parseProperties(element);
        if (decodedProps[0] == "Quality" || decodedProps[0] == "Level") {
          item.properties.Gem[decodedProps[0]] = decodedProps[1];
        }
      } else {
        console.log("Note: " + element + " isn't a matched pair property");
      }
    });

    return(item);

  // Analyze Rare and Unique items that don't match any of the above
  } else if (item.attributes.rarity == "Rare" || item.attributes.rarity == "Unique") {
    console.log("this item is rare or unique, trying to identify it " + nameArray[2]);

    // If it has a note, remove that
    if (infoArray[infoArray.length-1].match(/^Note/)) {
      infoArray.pop();
    }

    // If it's Unique, remove the flavor text
    if (item.attributes.rarity == "Unique") {
      infoArray.pop();
    }

    if (itemNames[nameArray[2]]) {
      item.attributes.itemType = itemNames[nameArray[2]];
      item.attributes.baseItemType = itemTypes[item.attributes.itemType];
      item.attributes.equipType = equipTypes[nameArray[2]];

      // Iterate through the properties - note that for some items, this will
      // be the Requirements and we'll just ignore them if so
      // ONLY ARMOUR AND WEAPONS HAVE PROPERTIES for RARE/UNIQUES!
      if ((item.attributes.baseItemType == "Weapon") || (item.attributes.baseItemType == "Armour")) {
        item.properties = new Object;
        var propertyList = _.compact(infoArray[1].split(/\n/));
        if (propertyList[0] != /^Requirements:/) {
          // This means we have properties, so create pwx style properties from them
          writeProperties(item, propertyList);
        }
      }

      // Calculate DPS for Weapons
      if (item.attributes.baseItemType == "Weapon") {
        writeDPS(item);
      }

      // Calculate Sockets if it's a Weapon or Armour
      if ((item.attributes.baseItemType == "Weapon") || (item.attributes.baseItemType == "Armour")) {
        writeSockets(item, infoArray);
      }

      // Now we must attempt to parse mods. This isn't so easy, because the mods can
      // show up in various sections. Thus we need to first eliminate non mod data.
      // No mod contains a ':' or '"' so those will be the primary filters
      var modInfo = new Array;
      infoArray.forEach(function (element) {
        if ((!element.match(/:/)) && (!element.match(/^\"/))) {
          var theseMods = element.split("\n");
          modInfo.push(theseMods);
        }
      });

      // For Normal items this logic will have to work differently
      writeMods(item, modInfo);

//      var thisInfo = _.compact(infoArray[3].split(/\n/));
//      thisInfo.forEach(function (element) {
//        var decodedMods = parseMod(element);
//        item.mods.Map.explicit[decodedMods[0]] = decodedMods[1];
//      });

    } else {
      var error = { error : "Unable to identify the base item and type for " + nameArray[2] + "!"};
      throw(JSON.stringify(error));
    }

    return(item);
  }

  item.warning = "This item wasn't fully identified and is returning only default info!";
  return item;
}

function parseMod(mod) {
  // This subroutine performs basic mod parsing. Right now it is not
  // nearly as complex as the ExileTools Indexer mod parsing.
  // At some point it will need to have modsTotal / etc. calculated


  // Look for mods that start with +/- to a number or just a number with %
  // examples this will match:
  // +10 to life --> +# to life:10
  // 200% increased damage --> % increased damage:200
  var matches = mod.match(/^(\+|\-)?(\d+(\.\d+)?)(\%?)\s+(.*)$/);
  if (matches != null) {
    if (matches[1]) {
      var modName = matches[1] + "#" + matches[4] + " "  + matches[5];
    } else {
      var modName = "#" + matches[4] + " "  + matches[5];
    }
    var modValue = Number(matches[2]);
//    console.log(modName + ":" + modValue);
  } else {
    // Look for +#-# stuff
    var matches = mod.match(/^(.*?) (\+?\d+(\.\d+)?(-\d+(\.\d+)?)?%?)\s?(.*)$/);
    if (matches != null) {
      // If the matching number is a range, treat it differently
      if (matches[2].match(/-/)) {
        var modName = matches[1] + " #-# " + matches[6];
        var theseValues = matches[2].split("-");
        var modValue = new Object;
        modValue.min = Number(theseValues[0]);
        modValue.max = Number(theseValues[1]);
        modValue.avg = Math.floor((modValue.min + modValue.max) / 2);
      } else if (matches[2].match(/%/)) {
        matches[2] = matches[2].replace("%", "");
        var modName = matches[1] + " #% " + matches[6];
        var modValue = Number(matches[2]);
      } else {
        var modName = matches[1] + " # " + matches[6];
        var modValue = Number(matches[2]);
      }
//      console.log(modName + ":" + modValue);
    } else {
      // Assume anything left is a boolean value
      var modName = mod;
      var modValue = true;
//      console.log(modName + ":" + modValue);
    }
  }

  // debug code
  if (modName == null) {
    var modName = mod;
    var modValue = "unparsed";
  }

  return[modName, modValue];
}

function parseProperties(prop) {
  thisProperty = prop.split(": ");
  propName = thisProperty[0];
  propValue = Number(thisProperty[1].replace(/[^0-9.]/g, ''));
  return[propName, propValue];
}


/********
  Additional code, mostly just abstracting your work but I rewrote it to
  understand what was going on.
********/

/*
  Extract properties and values from @param propertyList and record them in @param item.
  @return extend @param item.properties with: {
    [baseItemType]: {
      [propertyType]: [value],
      ...
    }
  }
*/
function writeProperties(item, propertyList) {
  if (!['Weapon', 'Armour'].includes(item.attributes.baseItemType)) return; 

  item.properties[item.attributes.baseItemType] = {};
  propertyList.forEach(function(prop) {
    const [propKey, propVal] = parseProperty(prop);
    if (!propKey) return;

    item.properties[item.attributes.baseItemType][propKey] = propVal;
  });
}

// Accumulate weapon statistics into a useful format.
// @return extend @param item.properties.Weapon with field { 'Total DPS' }
function writeDPS(item) {
  if (!item.attributes.baseItemType === 'Weapon') return;

  weaponProps = item.properties.Weapon;
  weaponProps["Total DPS"] = 0;
  if (weaponProps["Physical Damage"] && weaponProps["Physical Damage"].avg) {
    weaponProps["Physical DPS"] = Math.round(weaponProps["Physical Damage"].avg * weaponProps["Attacks per Second"]);
    weaponProps["Total DPS"] += weaponProps["Physical DPS"];
  }
  if ((weaponProps["Elemental Damage"]) && (weaponProps["Elemental Damage"].avg)) {
    weaponProps["Elemental DPS"] = Math.round(weaponProps["Elemental Damage"].avg * weaponProps["Attacks per Second"]);
    weaponProps["Total DPS"] += weaponProps["Elemental DPS"];
  }
}

// Extract socket information from @param infoArray and write a useful summary to @param item. 
function writeSockets(item, infoArray) {
  if (!['Weapon', 'Armour'].includes(item.attributes.baseItemType)) return;

  // We have to iterate through infoArray to find the one with sockets
  infoArray.forEach(function(thisInfo) {
    if (!thisInfo.match(/^Sockets/)) return;

    const allSocketsGGG = thisInfo.split(': ')[1].trim();
    item.sockets = {
      allSocketsGGG,
      largestLinkGroup: 0,
      socketCount: 0
    };
    const linkArray = allSocketsGGG.split(" ");
    linkArray.forEach(function(_thisLink) {
      thisLink = _thisLink.replace(/\-/g, "");
      item.sockets.socketCount += thisLink.length;
      if (thisLink.length > item.sockets.largestLinkGroup) {
        item.sockets.largestLinkGroup = thisLink.length;
      }
    });
  });
}

/*
  Extract modifier information from @param modInfo and write it to @param item.
  @return extend @param item with fields:
  {
    'mods': {
      [itemType]: {
        [unique list of mods]
      }
    },
    'modsTotal': {
      [modType]: [mod sum],
      ...
    }
  }
*/
function writeMods(item, modInfo) {
  const itemType = item.attributes.itemType;
  item.mods = {};
  item.mods[itemType] = {};
  item.modsTotal = {};

  // If modInfo has two elements, then the first element is an implicit mod
  if (modInfo.length === 2) {
    item.mods[itemType].implicit = {};
    modInfo[0].forEach(function(mod) {
      const [modKey, modVal] = parseMod(mod);
      item.mods[itemType].implicit[modKey] = modVal;
      if (typeof modVal === 'number') {
        if (item.modsTotal[modKey]) {
          item.modsTotal[modKey] += modVal;
        } else {
          item.modsTotal[modKey] = modVal;
        }
      }
    });
  }

  // explicits
  if (item.attributes.rarity !== 'normal') {
    item.mods[itemType].explicit = {};
    const explicits = modInfo.length === 2 ? modInfo[1] : modInfo[0];
    explicits.forEach(function(mod) {
      const [modKey, modVal] = parseMod(mod);
      item.mods[itemType].explicit[modKey] = modVal;
      if (typeof modVal === 'number') {
        if (item.modsTotal[modKey]) {
          item.modsTotal[modKey] += modVal;
        } else {
          item.modsTotal[modKey] = modVal;
        }
      }
    });
  }
}

// @param propDesc the string describing the property
// @return [propKey, propVal] parsing of @param propDesc
function parseProperty(propDesc) {
  // The parseProperties subroutine is only designed for : separated single number 
  // properties. Only weapons violate this, so we will just parse out those 
  // weapon properties here.
  if (!propDesc.match(/:/)) return [];

  if (propDesc.match(/Physical Damage: /)) {
    return ["Physical Damage", parseMinMaxAvg(propDesc)];
  } else if (propDesc.match(/Elemental Damage: /) || propDesc.match(/Chaos Damages:/)) {
    const dmgSummary = { min: 0, max: 0, avg: 0 };

    const damageList = propDesc.split(': ')[1];
    const eleDamages = damageList.split(', ');
    eleDamages.forEach(function(dmg) {
      const {min, max, avg} = parseMinMaxAvg(dmg);
      dmgSummary.min += min;
      dmgSummary.max += max;
      dmgSummary.avg += avg;
    });
    
    return ["Elemental Damage", dmgSummary];
  } else {
    return decodeProp(propDesc);
  }
}

// @param dmgDesc is string of the form: "XXX: 12 - 18 XXX"
// @return { min, max, avg }
function parseMinMaxAvg(dmgDesc) {
  const dmg = dmgDesc.split('-');
  const minDmg = Number(dmg[0].replace(/[^0-9.]/g, ''))
  const maxDmg = Number(dmg[1].replace(/[^0-9.]/g, ''))
  return {
    min: minDmg,
    max: maxDmg,
    avg: Math.round((minDmg + maxDmg) / 2),
  };
}

// @return [propertyKey, propertyValue]
function decodeProp(prop) {
  const [key, val] = prop.split(': ');
  return [key, Number(val.replace(/[^0-9.]/g, ''))];
}
