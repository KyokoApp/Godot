extends RefCounted
## Kumpulan kartu buff Survival; efek dan tampilannya diproses manager terpisah.

const CARDS: Array[Dictionary] = [
	{"id": "ember_core", "name": "JANTUNG BARA", "rarity": "LANGKA", "icon": "flame",
		"accent": "#ff7a45", "description": "Tanpa batas: +18% damage sihir per stack", "max_stacks": 0},
	{"id": "rapid_cast", "name": "MANTRA KILAT", "rarity": "LANGKA", "icon": "bolt",
		"accent": "#62d9ff", "description": "Cooldown tembak -10% per stack", "max_stacks": 5},
	{"id": "cinder_orbit", "name": "ORBIT BARA", "rarity": "EPIC", "icon": "orbit",
			"accent": "#ffa14e", "description": "Aura api orbit makin luas dan sakit", "max_stacks": 3},
	{"id": "arcane_aegis", "name": "AEGIS ARCANA", "rarity": "EPIC", "icon": "shield",
		"accent": "#bd83ff", "description": "+70 shield dan 7% damage reduction", "max_stacks": 4},
	{"id": "soul_siphon", "name": "SIPHON JIWA", "rarity": "LANGKA", "icon": "heart",
		"accent": "#ff668e", "description": "Pulihkan 8 HP setiap kill per stack", "max_stacks": 4},
	{"id": "overcharge", "name": "SIGIL KRITIKAL", "rarity": "EPIC", "icon": "star",
		"accent": "#ffe176", "description": "+8% peluang critical hit per stack", "max_stacks": 5},
	{"id": "echo_volley", "name": "ECHO VOLLEY", "rarity": "EPIC", "icon": "twin",
		"accent": "#ff8b62", "description": "+12% peluang tembakan sihir ganda", "max_stacks": 4},
	{"id": "long_reach", "name": "MATA PEMBURU", "rarity": "LANGKA", "icon": "eye",
		"accent": "#72e1ca", "description": "Tanpa batas: +7 m jangkauan auto-lock per stack",
		"max_stacks": 0},
	{"id": "volatile_nova", "name": "NOVA VOLATIL", "rarity": "EPIC", "icon": "nova",
		"accent": "#ffba55", "description": "Kill meledak, memberi damage area", "max_stacks": 4},
	{"id": "vitality", "name": "JANTUNG RAKSASA", "rarity": "LANGKA", "icon": "vitality",
		"accent": "#7be0a2", "description": "+25 max HP dan pulihkan HP per stack", "max_stacks": 4},
	{"id": "harvest", "name": "PANEN ARWAH", "rarity": "LANGKA", "icon": "harvest",
		"accent": "#b6ec79", "description": "+20% EXP dari kill per stack", "max_stacks": 5},
	{"id": "burning_brand", "name": "CAP BARA", "rarity": "LANGKA", "icon": "brand",
		"accent": "#ff665e", "description": "Tembakan membakar zombie selama 2,5 dtk", "max_stacks": 4},
	{"id": "seeking_flame", "name": "API PENCARI", "rarity": "LANGKA", "icon": "comet",
		"accent": "#99aaff", "description": "+18% kecepatan belok sihir per stack", "max_stacks": 4},
	{"id": "ascendant_sigil", "name": "SIGIL KEABADIAN", "rarity": "MITIK", "icon": "nova",
		"accent": "#f2d58b", "description": "Tanpa batas: +3% damage sihir per stack", "max_stacks": 0},
]


static func all_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card in CARDS:
		result.append(card.duplicate(true))
	return result


static func card_for(id: String) -> Dictionary:
	for card in CARDS:
		if str(card["id"]) == id:
			return card.duplicate(true)
	return {}
