class_name AdPacing
extends RefCounted
## Mémoire (en RAM, le temps d'une session) des annonces plein écran déjà vues : sert à espacer les publicités.
## Horloge monotone (millisecondes depuis le démarrage) passée par l'appelant : jamais l'heure civile du téléphone.

enum Kind { INTERSTITIAL, REWARDED, RETURN }

const NEVER := -1
const HOUR_MS := 3_600_000

var _all: Array[int] = []
var _interstitials: Array[int] = []
var _rewarded: Array[int] = []


func record(kind: int, now_ms: int) -> void:
	_all.append(now_ms)
	match kind:
		Kind.INTERSTITIAL:
			_interstitials.append(now_ms)
		Kind.REWARDED:
			_rewarded.append(now_ms)
	_trim(_all, now_ms)
	_trim(_interstitials, now_ms)
	_trim(_rewarded, now_ms)


## Millisecondes écoulées depuis la dernière annonce plein écran (toutes sortes), ou NEVER.
func since_last_full_screen(now_ms: int) -> int:
	return _since(_all, now_ms)


func since_last_rewarded(now_ms: int) -> int:
	return _since(_rewarded, now_ms)


func interstitials_in_last_hour(now_ms: int) -> int:
	return _count_recent(_interstitials, now_ms)


func rewarded_in_last_hour(now_ms: int) -> int:
	return _count_recent(_rewarded, now_ms)


static func _since(list: Array[int], now_ms: int) -> int:
	return NEVER if list.is_empty() else maxi(now_ms - list[list.size() - 1], 0)


static func _count_recent(list: Array[int], now_ms: int) -> int:
	var count := 0
	for at in list:
		if now_ms - at < HOUR_MS:
			count += 1
	return count


static func _trim(list: Array[int], now_ms: int) -> void:
	while not list.is_empty() and now_ms - list[0] >= HOUR_MS:
		list.remove_at(0)
