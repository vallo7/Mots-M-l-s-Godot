class_name DailyModel
extends RefCounted
## Tout ce que l'écran du défi du jour et la bannière d'accueil affichent, calculé à partir de la progression (pure).

enum Status { LOADING, AVAILABLE, IN_PROGRESS, DONE }

var today := 0
var status: int = Status.LOADING
var stars := 0
var elapsed_millis := 0
var theme: Dictionary = {}
var grid_size := 0
var band: int = DifficultyBand.EASY
var is_final := false
var weekday := 0
var streak := 0  ## série en cours (0 si elle est rompue)
var best_streak := 0
var completed_total := 0
var seconds_left := 0
## Prochain palier de série : Vector2i(jours, indices), (0, 0) s'il n'y en a plus.
var next_milestone := Vector2i.ZERO
## Les 7 derniers jours (le plus ancien d'abord, aujourd'hui en dernier) : {day, weekday, state, stars}.
## state : "done", "today", "missed", "future" (jamais « future » ici).
var week: Array[Dictionary] = []
## Mois courant : {year, month, first_weekday, days: [{number, day, state, stars}]}.
var month: Dictionary = {}
## Paliers : {days, hints, reached, claimed}.
var milestones: Array[Dictionary] = []


## `level` : le défi du jour s'il est prêt (null pendant sa préparation). `resumable` : une partie est en cours.
static func build(state: ProgressState, p_today: int, level: Level, resumable: bool, p_seconds_left: int) -> DailyModel:
	var m := DailyModel.new()
	m.today = p_today
	m.seconds_left = p_seconds_left
	m.weekday = DailyChallenge.date_of(p_today)["weekday"]
	m.streak = DailyChallenge.effective_streak(state, p_today)
	m.best_streak = state.daily_best_streak
	m.completed_total = state.daily_results.size()
	m.next_milestone = DailyChallenge.next_milestone(m.streak)
	if state.daily_results.has(p_today):
		var r: LevelResult = state.daily_results[p_today]
		m.status = Status.DONE
		m.stars = r.stars
		m.elapsed_millis = r.elapsed_millis
	elif level == null:
		m.status = Status.LOADING
	else:
		m.status = Status.IN_PROGRESS if resumable else Status.AVAILABLE
	if level != null:
		m.theme = level.theme
		m.grid_size = level.grid_size
		m.band = DifficultyBand.of(level.number)
		m.is_final = level.is_final_challenge()
	else:
		var plan := DailyLevelFactory.plan_for(p_today)
		m.grid_size = int(plan["size"])
		m.band = DifficultyBand.of(int(plan["number"]))
		m.is_final = int(plan["number"]) == Level.FINAL_NUMBER
	for offset in range(6, -1, -1):
		var day := p_today - offset
		var entry := {"day": day, "weekday": DailyChallenge.date_of(day)["weekday"], "state": "missed", "stars": 0}
		if state.daily_results.has(day):
			entry["state"] = "done"
			entry["stars"] = (state.daily_results[day] as LevelResult).stars
		elif day == p_today:
			entry["state"] = "today"
		m.week.append(entry)
	var date := DailyChallenge.date_of(p_today)
	var first_day := DailyChallenge.day_index_of(date["year"], date["month"], 1)
	var days: Array[Dictionary] = []
	for number in range(1, DailyChallenge.days_in_month(date["year"], date["month"]) + 1):
		var day := first_day + number - 1
		var cell := {"number": number, "day": day, "state": "future", "stars": 0}
		if state.daily_results.has(day):
			cell["state"] = "done"
			cell["stars"] = (state.daily_results[day] as LevelResult).stars
		elif day == p_today:
			cell["state"] = "today"
		elif day < p_today:
			cell["state"] = "missed"
		days.append(cell)
	m.month = {"year": date["year"], "month": date["month"], "first_weekday": DailyChallenge.date_of(first_day)["weekday"], "days": days}
	var thresholds: Array = DailyChallenge.STREAK_MILESTONES.keys()
	thresholds.sort()
	for d in thresholds:
		m.milestones.append({
			"days": int(d), "hints": int(DailyChallenge.STREAK_MILESTONES[d]),
			"reached": m.streak >= int(d), "claimed": state.daily_claimed_milestones.has(int(d)) and m.streak >= int(d),
		})
	return m
