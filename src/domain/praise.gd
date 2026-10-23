class_name Praise
extends RefCounted
## Échelle de praise, du plus modeste au plus rare. Les clés servent aussi de noms de fichiers.

enum { NICE, GREAT, AWESOME, AMAZING, INSANE, UNREAL, DIVINE, LEGENDARY }

const KEYS: Array[String] = ["nice", "great", "awesome", "amazing", "insane", "unreal", "divine", "legendary"]
const NONE := -1


static func key_of(praise: int) -> String:
	return KEYS[praise]


## -1 (NONE) si la clé est inconnue.
static func from_key(key: String) -> int:
	return KEYS.find(key)
