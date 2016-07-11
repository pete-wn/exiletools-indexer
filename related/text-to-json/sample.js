const normalBelt = `Rarity: Normal
Rustic Sash
--------
Item Level: 3
--------
19% increased Physical Damage`

const magicBelt = `Rarity: Magic
Recovering Leather Belt of Impact
--------
Requirements:
Level: 8
--------
Item Level: 13
--------
+27 to maximum Life
--------
14% increased Stun Duration on Enemies
18% increased Flask Life Recovery rate`;

const normalChest = `Rarity: Normal
Light Brigandine
--------
Armour: 35
Evasion Rating: 35
--------
Requirements:
Level: 8
Str: 16
Dex: 16
--------
Sockets: B-R-G 
--------
Item Level: 15`

const qualityNormalFlask = `Rarity: Normal
Superior Medium Life Flask
--------
Quality: +9% (augmented)
Recovers 164 (augmented) Life over 6.50 Seconds
Consumes 8 of 28 Charges on use
Currently has 0 Charges
--------
Requirements:
Level: 3
--------
Item Level: 5
--------
Right click to drink. Can only hold charges while in belt. Refills as you kill monsters.`

const rareArmour= `Rarity: Rare
Morbid Paw
Stealth Gloves
--------
Evasion Rating: 276 (augmented)
--------
Requirements:
Level: 62
Str: 88
Dex: 97
Int: 83
--------
Sockets: B-R-G-R 
--------
Item Level: 69
--------
Cast Decree of Flames on Hit
--------
+42 to Dexterity
10% increased Attack Speed
+300 to Accuracy Rating
38% increased Evasion Rating
+50 to maximum Life`

const rareWeapon = `Rarity: Rare
Ghoul Crack
Shadow Sceptre
--------
One Handed Mace
Physical Damage: 50-74 (augmented)
Elemental Damage: 5-76 (augmented)
Critical Strike Chance: 6.50%
Attacks per Second: 1.39 (augmented)
--------
Requirements:
Level: 32
Str: 52
Int: 62
--------
Sockets: R-R-R 
--------
Item Level: 35
--------
22% increased Elemental Damage
--------
101% increased Physical Damage
6% increased Cold Damage
Adds 5-76 Lightning Damage
11% increased Attack Speed
+23% to Cold Resistance`

module.exports = {
	normalBelt,
	magicBelt,
	normalArmour,
	rareArmour,
	rareWeapon,
	qualityNormalFlask,
};

/*

	Items are parsed into objects:

	item: {
		attributes: {
			league<string>
			rarity<string>
			itemType<string>
			baseItemType<string>
			equipType<string>
			corrupted<bool>
		},
		properties: {
			baseType[Armour/weapn/etc]: {
	
			}
		}
		info: {
			fullName<string>
		},
		sockets: {
	
		}
	}


	// If it has a note, remove that
	if (infoArray[infoArray.length-1].match(/^Note/)) {
	  infoArray.pop();
	}





*/