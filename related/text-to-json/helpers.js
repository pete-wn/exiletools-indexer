const _ = require('lodash');

const Helpers = module.exports;

Helpers.parseProperties = function(_item, propertyList) {
	const item = _item;
	if (['Weapon', 'Armour'].includes(item.attributes.baseItemType)) {
		item.properties[item.attributes.baseItemType] = {};
		propertyList.forEach(parseProperty.bind(null, item));
	}

	return item;
}

function parseProperty(item, prop) {
	if (!prop.match(/:/)) return;

	if (prop.match(/Physical Damage: /)) {
		item.properties.Weapon["Physical Damage"] = parseMinMaxAvg(prop)
	} else if (prop.match(/Elemental Damage: /) || prop.match(/Chaos Damages:/)) {
		item.properties.Weapon["Elemental Damage"] = { min: 0, max: 0, avg: 0 };
		const damageList = prop.split(': ')[1];
		const eleDamages = damageList.split(', ');
		eleDamages.forEach(function(dmg) {
			const { min, max, avg } = parseMinMaxAvg(dmg);
			item.properties.Weapon["Elemental Damage"].min += min;
			item.properties.Weapon["Elemental Damage"].max += max;
			item.properties.Weapon["Elemental Damage"].avg += avg;
		});
	} else {
		const {propName, propValue} = decodeProp(prop);
		item.properties[item.attributes.baseItemType][propName] = propValue;
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
		propName: key,
		propValue: Number(val.replace(/[^0-9.]/g, '')),
	};
}
