extends HoldableObject
class_name Defibrillator

## Cosmetic equipment damage only: throwing the device cracks its display once.

var screen_cracked: bool = false


func on_tossed() -> void:
	if screen_cracked:
		return
	screen_cracked = true
	$CrackedScreen.visible = true
