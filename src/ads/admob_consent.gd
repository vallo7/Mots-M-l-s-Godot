class_name AdMobConsent
extends RefCounted
## Consentement (UMP) : demandé à chaque lancement ; le formulaire n'apparaît que si la région l'exige. Aucune
## annonce n'est demandée avant que le consentement ne le permette.
## Écrit d'après la documentation officielle du plugin Poing Studios 5.x (voir docs/ADS.md).

signal _done()

const TIMEOUT_SECONDS := 20.0

var _finished := false


## Asynchrone. Renvoie true si des annonces peuvent être demandées.
func request_consent(tree: SceneTree) -> bool:
	var info := UserMessagingPlatform.consent_information
	var request := ConsentRequestParameters.new()
	request.tag_for_under_age_of_consent = false
	info.update(
		request,
		func() -> void:
			var needs_form: bool = info.get_is_consent_form_available() and info.get_consent_status() == info.ConsentStatus.REQUIRED
			if needs_form:
				UserMessagingPlatform.load_consent_form(
					func(form: ConsentForm) -> void: form.show(func(_error: FormError) -> void: _finish()),
					func(_error: FormError) -> void: _finish()
				)
			else:
				_finish(),
		func(_error: FormError) -> void: _finish()
	)
	# Garde-fou : si le plugin ne répond jamais, on ne bloque pas le jeu.
	tree.create_timer(TIMEOUT_SECONDS).timeout.connect(_finish)
	if not _finished:
		await _done
	var status: int = info.get_consent_status()
	return status == info.ConsentStatus.OBTAINED or status == info.ConsentStatus.NOT_REQUIRED


func privacy_options_required() -> bool:
	var info := UserMessagingPlatform.consent_information
	return info.get_privacy_options_requirement_status() == info.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: pass)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_done.emit()
