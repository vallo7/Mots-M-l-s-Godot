class_name HintService
extends RefCounted
## Un indice révèle la première case d'un mot non trouvé et pas déjà indicé.
## Le solde n'est décrémenté que pour un résultat REVEALED : l'appelant persiste le nouveau solde
## puis applique l'état.


static func use_hint(state: GameState, balance: int) -> HintOutcome:
	if state.is_solved():
		return HintOutcome.new(HintOutcome.Kind.NOTHING_TO_REVEAL)
	if state.hints_used() >= state.level.hints_max_per_level:
		return HintOutcome.new(HintOutcome.Kind.LIMIT_REACHED)
	if balance <= 0:
		return HintOutcome.new(HintOutcome.Kind.NO_BALANCE)
	var hinted := {}
	for hint in state.revealed_hints:
		hinted[hint.word_index] = true
	var words := state.variant().words
	var index := -1
	for i in words.size():
		if not state.has_found(i) and not hinted.has(i):
			index = i
			break
	if index < 0:
		return HintOutcome.new(HintOutcome.Kind.NOTHING_TO_REVEAL)
	var revealed := RevealedHint.new(index, words[index].start)
	var next := state.copy()
	next.revealed_hints.append(revealed)
	return HintOutcome.new(HintOutcome.Kind.REVEALED, revealed, next, balance - 1)
