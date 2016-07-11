const Helpers = module.exports;

Helpers.parseProperties = function(item, propertyList) {
	if (!['Weapon', 'Armour'].includes(item.attributes.baseItemType)) return;

	item.properties[item.attributes.baseItemType] = {};
	propertyList.forEach(function(prop) {
		const {propKey, propValue} = parseProperty(prop);
		item.properties[item.attributes.baseItemType][propKey] = propValue;
	});
}

Helpers.calculateDPS = function(item) {
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

Helpers.calculateSockets = function(item, infoArray) {
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
    linkArray.forEach(function(thisLink) {
      const thisLink = thisLink.replace(/\-/g, "");
      item.sockets.socketCount += thisLink.length;
      if (thisLink.length > item.sockets.largestLinkGroup) {
        item.sockets.largestLinkGroup = thisLink.length;
      }
    });
  });

  // Since we don't do much error checking, make sure 0 data is removed
  if (item.sockets.largestLinkGroup < 1) {
    delete item.sockets.largestLinkGroup;
  }
  if (item.sockets.socketCount < 1) {
    delete item.sockets.socketCount;
  }
};

Helper.createMods = function(item, modInfo) {
	const itemType = item.attributes.itemType;
	item.mods[itemType] = {};
	item.modsTotal = {};

	if (modInfo.length === 2) {
		item.mods[itemType].implicit = {};
		modInfo[0].forEach(function(mod) {
			const [modKey, modVal] = parseMod(mod);
			item.mods[itemType].implicit[modKey] = modVal;
			if (typeof modKey == 'number') {
				if (item.modsTotal[modKey]) {
					item.modsTotal[modKey] += modVal;
				} else {
					item.modsTotal[modKey] = modVal;
				}
			}
		})
	} else {
		item.mods[itemType].explicit = {};
		const explicits = modInfo.length === 2 ? modInfo[1] : modInfo[0];
		explicits.forEach(function(mod) {
			const [modKey, modVal] = parseMod(mod);
			item.mods[itemType].explicit[modKey] = modVal;
			if (typeof modKey == 'number') {
				if (item.modsTotal[modKey]) {
					item.modsTotal[modKey] += modVal;
				} else {
					item.modsTotal[modKey] = modVal;
				}
			}
		})
	} else {
    var error = { error : "Unable to identify the base item and type for " + nameArray[2] + "!"};
    throw(JSON.stringify(error));
  }
}

// This implementation does not need to know anything about the item.
// @param propDesc the string representing the property
// @return { propKey, propValue } parsing of @param propDesc
function parseProperty(propDesc) {
	if (!propDesc.match(/:/)) return;

	if (propDesc.match(/Physical Damage: /)) {
		return {
			propKey: "Physical Damage",
			propValue: parseMinMaxAvg(prop)
		};
	} else if (propDesc.match(/Elemental Damage: /) || propDesc.match(/Chaos Damages:/)) {
		const dmgSummary = { min: 0, max: 0, avg: 0 };

		const damageList = propDesc.split(': ')[1];
		const eleDamages = damageList.split(', ');
		eleDamages.forEach(function(dmg) {
			const { min, max, avg } = parseMinMaxAvg(dmg);
			dmgSummary.min += min;
			dmgSummary.max += max;
			dmgSummary.avg += avg;
		});
		return {
			propKey: "Elemental Damage",
			propValue: dmgSummary
		};
	} else {
		return decodeProp(prop);
	}
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

// @param damageDesc and string of the form: "XXX: 12 - 18 XXX"
// @return { min<number>, max<number>, avg<number> }
function parseMinMaxAvg(damageDesc) {
	const dmg = damageDesc.split('-');
	const minDmg = Number(dmg[0].replace(/[^0-9.]/g, ''))
	const maxDmg = Number(dmg[1].replace(/[^0-9.]/g, ''))
	return {
		min: minDmg,
		max: maxDmg,
		avg: Math.round((minDmg + maxDmg) / 2),
	}
}

function decodeProp(prop) {
	const [key, val] = prop.split(': ');
	return {
		propKey: key,
		propValue: Number(val.replace(/[^0-9.]/g, '')),
	};
}
