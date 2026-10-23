class_name PraiseVoice
extends RefCounted

var asset_path: String
var volume: float


func _init(p_asset_path: String, p_volume: float) -> void:
	asset_path = p_asset_path
	volume = p_volume
