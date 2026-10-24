# Audio

## Musique de fond (1.3.0)

Fichier : `assets/audio/music/music_background.ogg` (Vorbis, ≈ 1,1 Mo, 1 min 24 s, boucle sans couture), tiré de la musique fournie
(`mots_mêlés_background_music.mp3`, 1 min 30 s).

Traitement appliqué au fichier d'origine (qui était très fort : -11,7 LUFS, crêtes à -0,1 dBFS, descente finale en fondu) :
- **Boucle sans couture** : les 4 dernières secondes (descente finale) sont retirées et les 2 s précédentes se fondent (fondu
  enchaîné à puissance constante) dans les 2 premières secondes ; la fin du fichier se raccorde ainsi au début sans coupure ni creux.
- **Niveau** : -20 LUFS (crêtes à -8 dBFS), pour garder de la marge et laisser le réglage faire le reste.
- Encodage Vorbis qualité 4, import `loop=true` (`music_background.ogg.import`).

Réglage du volume (`GodotAudioManager`) :
- Gain maximal de la musique `MUSIC_MAX_GAIN = 0.55`. Au curseur par défaut (60 %) : gain ≈ 0,2 soit ≈ -14 dB, **≈ -34 LUFS** : environ
  **8 dB sous un effet sonore** (effets à 60 % par défaut : ≈ -26 LUFS). La musique reste une ambiance de fond.
- **Atténuation automatique** : pendant une voix de félicitation, un jingle de victoire ou un cadeau, le bus « Music » descend de
  7 dB en 0,12 s puis remonte en 0,9 s (`duck_music`). Un test vérifie l'écart musique / effets.
- Curseurs des réglages : effets sonores **60 % par défaut** (`AppSettings.DEFAULT_SFX_VOLUME`), musique 60 %. Un joueur qui a déjà
  enregistré ses réglages garde les siens.

## Remplacer la musique

1. Boucler : fondu enchaîné fin → début (voir ci-dessus), normaliser à -20 LUFS (`ffmpeg -af loudnorm` ou un gain fixe mesuré avec `ffmpeg -af ebur128`).
2. Encoder : `ffmpeg -i boucle.wav -c:a libvorbis -q:a 4 music_background.ogg`.
3. Déposer le fichier à la place de l'ancien, garder `loop=true` dans le `.import`, vérifier que `test_the_volume_curve_is_silent_at_zero_and_monotonic` passe.
