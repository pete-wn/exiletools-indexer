const _ = require('lodash');

const Helpers = module.exports;

Helpers.parseProperties = function(item, propertyList) {
	if (['Weapon', 'Armour'].includes(item.attributes.baseItemType)) {
		item.properties[item.attributes.baseItemType] = {};

		propertyList.forEach(function(property) {
			const {propKey, propValue} = parseProperty(property);
			item.properties[item.attributes.baseItemType][propKey] = propValue;
		});
	}
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
    if (thisInfo.match(/^Sockets/)) {
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
      return;
    }
  });
  // Since we don't do much error checking, make sure 0 data is removed
  if (item.sockets.largestLinkGroup < 1) {
    delete item.sockets.largestLinkGroup;
  }
  if (item.sockets.socketCount < 1) {
    delete item.sockets.socketCount;
  }

};

// The below implementation removes a need to know anything about the item.
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
