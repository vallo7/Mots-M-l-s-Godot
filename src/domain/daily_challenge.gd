class_name DailyChallenge
extends RefCounted
## Règles du défi quotidien : un jour = un entier (jours depuis le 1er janvier 1970, à l'heure LOCALE du téléphone).
## Une grille par jour et par langue (voir DailyLevelFactory), une seule victoire par jour compte. Récompenses :
## 1 indice par défi réussi, +1 avec 3 étoiles, et un bonus quand la série de jours consécutifs atteint un palier.

const BASE_REWARD := 1
const THREE_STARS_BONUS := 1
## Série (jours consécutifs) -> indices offerts, une seule fois par série.
const STREAK_MILESTONES := {3: 1, 7: 2, 14: 3, 30: 5}
## On ne garde que l'historique de cette durée (jours) dans la sauvegarde.
const HISTORY_DAYS := 400
const SECONDS_PER_DAY := 86400


## Jour local courant pour un instant UTC (secondes) et un décalage de fuseau (minutes).
static func day_index_at(unix_utc: float, utc_offset_minutes: int) -> int:
	return int(floor((unix_utc + utc_offset_minutes * 60.0) / SECONDS_PER_DAY))


static func today_index() -> int:
	return day_index_at(Time.get_unix_time_from_system(), int(Time.get_time_zone_from_system()["bias"]))


## Secondes avant minuit local.
static func seconds_until_next_day(unix_utc: float, utc_offset_minutes: int) -> int:
	var local := unix_utc + utc_offset_minutes * 60.0
	return int(SECONDS_PER_DAY - fposmod(local, SECONDS_PER_DAY))


static func seconds_until_tomorrow() -> int:
	return seconds_until_next_day(Time.get_unix_time_from_system(), int(Time.get_time_zone_from_system()["bias"]))


## {year, month, day, weekday} d'un jour (weekday : 0 = dimanche).
static func date_of(day_index: int) -> Dictionary:
	return Time.get_date_dict_from_unix_time(day_index * SECONDS_PER_DAY)


static func day_index_of(year: int, month: int, day: int) -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": 0, "minute": 0, "second": 0}) / SECONDS_PER_DAY)


static func days_in_month(year: int, month: int) -> int:
	var next_year := year + (1 if month == 12 else 0)
	var next_month := 1 if month == 12 else month + 1
	return day_index_of(next_year, next_month, 1) - day_index_of(year, month, 1)


## Série affichée : celle enregistrée si le dernier défi réussi date d'aujourd'hui ou d'hier, sinon la série est rompue (0).
static func effective_streak(state: ProgressState, today: int) -> int:
	if state.daily_last_day >= 0 and (state.daily_last_day == today or state.daily_last_day == today - 1):
		return state.daily_streak
	return 0


## Prochain palier de série : Vector2i(jours, indices), ou (0, 0) s'il n'y en a plus.
static func next_milestone(streak: int) -> Vector2i:
	var days: Array = STREAK_MILESTONES.keys()
	days.sort()
	for d in days:
		if int(d) > streak:
			return Vector2i(int(d), int(STREAK_MILESTONES[d]))
	return Vector2i.ZERO


## Indices gagnés pour une victoire : [base, bonus 3 étoiles, bonus de palier].
static func rewards_for(stars: int, streak_after: int, milestone_already_claimed: bool) -> Array[int]:
	var milestone := 0
	if STREAK_MILESTONES.has(streak_after) and not milestone_already_claimed:
		milestone = int(STREAK_MILESTONES[streak_after])
	return [BASE_REWARD, THREE_STARS_BONUS if stars >= 3 else 0, milestone]
