class_name StarRating
extends RefCounted
## < 1:00 = 3 étoiles ; 1:00 à < 3:00 = 2 étoiles ; >= 3:00 = 1 étoile (3:00 exactement = 1).

const THREE_STARS_BELOW_MS := 60_000
const TWO_STARS_BELOW_MS := 180_000


static func stars_for(elapsed_millis: int) -> int:
	if elapsed_millis < THREE_STARS_BELOW_MS:
		return 3
	if elapsed_millis < TWO_STARS_BELOW_MS:
		return 2
	return 1
