#!/usr/bin/env python3
"""Outil de production éditoriale des niveaux (exécuté par les auteurs, jamais par l'application).

Les listes de mots et les paramètres de difficulté ci-dessous sont le contenu éditorial. Le script
place les mots avec une graine fixe (résultat reproductible), remplit la grille et écrit
data/levels/*.json. L'application ne génère rien à l'exécution : elle lit ces fichiers.

    python3 scripts/generate_levels.py            # (ré)écrit data/levels
    python3 scripts/generate_levels.py --check    # échoue si les fichiers committés diffèrent
"""
import json
import os
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from level_tools import (  # noqa: E402
    DIRS, OPPOSITE, SCHEMA_VERSION, level_score, occurrences, style_for, tier_directions,
    to_letters, validate_chapters,
)

MAX_PLACE_TRIES = int(os.environ.get("MAX_PLACE_TRIES", "6000"))
OUT_DIR = Path(__file__).resolve().parent.parent / "data" / "levels"

FR_ALPHA = "EEEEEEEEEEEEAAAAAAAIIIIIIINNNNNNOOOOOORRRRRRSSSSSSTTTTTTUUUUUULLLLLDDDCCMMPPVFBGHQXYZJKW"
EN_ALPHA = "EEEEEEEEEEEEAAAAAAAAIIIIIIIOOOOOOONNNNNNRRRRRRTTTTTTSSSSSLLLLCCCDDDUUMMPPHHGGBFYWKVXZJQ"
ALPHA = {"fr": FR_ALPHA, "en": EN_ALPHA}


def L(number, size, tier, amb, hints, theme, fr, en, cross=0, cover=0.88, decoys=0):
    return dict(number=number, size=size, tier=tier, amb=amb, hints=hints, theme=theme,
                fr=fr, en=en, cross=cross, cover=cover, decoys=decoys)


# Dix chapitres, de plus en plus difficiles (le validateur impose un score moyen croissant d'un chapitre à l'autre).
#  - Conception : plus de mots, des mots plus longs, davantage de croisements, des grilles plus denses et plus grandes ;
#    les paliers (directions autorisées) montent plus vite ; chaque niveau peut aussi planter des LEURRES (`decoys`) :
#    des débuts de mots ou des mots « presque justes » (dernières lettres changées) cachés dans la grille.
#  - Résolution : la grille se remplit de plus en plus avec les lettres des mots eux-mêmes (`amb`), si bien que presque
#    toutes les cases ressemblent à un début de mot ; les mots à l'envers et en diagonale arrivent plus tôt.
# Tailles : 4×4 puis 5×5 réservées au chapitre 1 ; ensuite 6 à 11 ; 12×12 pour le défi final (niveau 10) de chaque chapitre.
# Longueurs : chaque niveau mêle des mots COURTS et des mots LONGS (voir LENGTH_PROFILE et min_longest_word dans
# level_tools.py : le script refuse tout niveau qui ne respecte pas ce profil).
CHAPTERS = [
    dict(id="chapter-01", index=1, palette="meadow", theme=("Nature", "Nature"), levels=[
        L(1, 4, 1, 0.1, 2, ("Plage", "Beach"), ["MER", "SOL", "ÎLE", "VENT"], ["SEA", "SUN", "SAND", "WAVE"], cross=2, cover=1.0),
        L(2, 5, 1, 0.2, 2, ("Jardin", "Garden"), ["FLEUR", "ROSE", "PRÉ", "EAU", "NID"], ["TULIP", "ROSE", "BEE", "SUN", "ELM"], cross=1, cover=0.95),
        L(3, 6, 2, 0.3, 3, ("Forêt", "Forest"), ["MOUSSE", "HIBOU", "LOUP", "CERF", "ORME", "NID"], ["FOREST", "OWL", "WOLF", "DEER", "FERN", "NEST"], cross=3, cover=0.95),
        L(4, 6, 2, 0.4, 3, ("Montagne", "Mountain"), ["SOMMET", "NEIGE", "ROCHER", "CIME", "SKI", "LAC", "COL"], ["SUMMIT", "SNOW", "CLIFF", "PEAK", "SKI", "ICE", "ELK"], cross=4, cover=0.97, decoys=1),
        L(5, 7, 3, 0.5, 3, ("Océan", "Ocean"), ["BALEINE", "CORAIL", "DAUPHIN", "VAGUE", "ALGUE", "THON", "MER", "ÎLE"], ["DOLPHIN", "CORAL", "WHALE", "WAVE", "SHARK", "TUNA", "EEL", "SEA"], cross=5, cover=0.95, decoys=1),
        L(6, 7, 3, 0.6, 3, ("Animaux", "Animals"), ["GIRAFE", "RENARD", "PANDA", "TIGRE", "LION", "OURS", "RAT", "ZÈBRE"], ["GIRAFFE", "MONKEY", "PANDA", "TIGER", "LION", "SEAL", "APE", "ZEBRA"], cross=5, cover=0.97, decoys=2),
        L(7, 8, 3, 0.65, 4, ("Fruits", "Fruits"), ["ABRICOT", "CITRON", "BANANE", "PÊCHE", "POIRE", "KIWI", "LIME", "FIGUE", "PASTÈQUE"], ["APRICOT", "LEMON", "BANANA", "PEACH", "PEAR", "KIWI", "LIME", "FIG", "MULBERRY"], cross=6, cover=0.95, decoys=2),
        L(8, 9, 4, 0.75, 4, ("Météo", "Weather"), ["TONNERRE", "TEMPÊTE", "ÉCLAIR", "BRUINE", "NEIGE", "PLUIE", "VENT", "GEL", "SOLEIL", "BRUME"], ["BLIZZARD", "THUNDER", "TORNADO", "SHOWER", "BREEZE", "STORM", "HAIL", "ICE", "SUNSHINE", "FOG"], cross=7, cover=0.95, decoys=3),
        L(9, 10, 4, 0.8, 4, ("Fleurs", "Flowers"), ["MARGUERITE", "COQUELICOT", "ORCHIDÉE", "HIBISCUS", "LAVANDE", "JASMIN", "TULIPE", "ROSE", "IRIS", "PIVOINE", "LILAS"], ["SUNFLOWER", "DAFFODIL", "LAVENDER", "MAGNOLIA", "JASMINE", "ORCHID", "TULIP", "ROSE", "IRIS", "POPPY", "LILAC"], cross=8, cover=0.95, decoys=4),
        L(10, 12, 4, 1.0, 5, ("Le grand air", "The great outdoors"), ["BIODIVERSITÉ", "ÉCOSYSTÈME", "VÉGÉTATION", "RANDONNÉE", "CAMPEMENT", "ESCALADE", "AVENTURE", "GLACIER", "SENTIER", "SOMMET", "NATURE", "FORÊT", "RIVE", "BOIS", "CASCADE", "RUISSEAU", "PRAIRIE"], ["BIODIVERSITY", "WILDERNESS", "RAINFOREST", "WATERFALL", "ADVENTURE", "ECOSYSTEM", "CAMPFIRE", "MOUNTAIN", "GLACIER", "MEADOW", "RIVER", "TRAIL", "PINE", "SKY", "CANYON", "STREAM", "VALLEY"], cross=12, cover=0.95, decoys=6),
    ]),
    dict(id="chapter-02", index=2, palette="voyage", theme=("Voyage", "Travel"), levels=[
        L(1, 7, 3, 0.57, 3, ("Transports", "Transport"), ["BATEAU", "CAMION", "AVION", "TRAIN", "TAXI", "BUS", "MÉTRO", "FUSÉE"], ["ROCKET", "TRUCK", "TRAIN", "PLANE", "TAXI", "BUS", "METRO", "FERRY"], cross=6, cover=0.97, decoys=2),
        L(2, 7, 3, 0.61, 3, ("Hôtel", "Hotel"), ["CHAMBRE", "PISCINE", "BALCON", "CLIENT", "SUITE", "BAR", "LIT", "SPA", "LOBBY"], ["BALCONY", "PILLOW", "SHOWER", "LOBBY", "SUITE", "BED", "KEY", "SPA", "TOWEL"], cross=6, cover=0.97, decoys=2),
        L(3, 8, 3, 0.6, 3, ("Pays", "Countries"), ["PORTUGAL", "ESPAGNE", "MEXIQUE", "CANADA", "BRÉSIL", "JAPON", "CUBA", "INDE", "ITALIE"], ["PORTUGAL", "GERMANY", "MEXICO", "CANADA", "BRAZIL", "JAPAN", "CUBA", "PERU", "ITALY"], cross=7, cover=0.96, decoys=3),
        L(4, 8, 4, 0.59, 4, ("Monuments", "Landmarks"), ["PYRAMIDE", "COLISÉE", "CHÂTEAU", "PAGODE", "TEMPLE", "MUSÉE", "PONT", "TOUR", "STATUE", "PALAIS"], ["MONUMENT", "FORTRESS", "PYRAMID", "CASTLE", "TEMPLE", "MUSEUM", "TOWER", "ARCH", "STATUE", "PALACE"], cross=7, cover=0.96, decoys=1),
        L(5, 9, 4, 0.69, 4, ("Cuisine du monde", "World food"), ["COUSCOUS", "BURRITO", "RAVIOLI", "FALAFEL", "PAELLA", "TAGINE", "SUSHI", "TACO", "KEBAB", "CURRY"], ["DUMPLING", "TORTILLA", "LASAGNA", "GOULASH", "PAELLA", "CURRY", "SUSHI", "TACO", "KEBAB", "PIZZA"], cross=7, cover=0.95, decoys=1),
        L(6, 9, 4, 0.72, 4, ("Aéroport", "Airport"), ["TERMINAL", "PASSAGER", "AÉRONEF", "BAGAGES", "DOUANE", "PILOTE", "PISTE", "VOL", "HANGAR", "TOUR", "RADAR"], ["TERMINAL", "BOARDING", "AIRLINE", "LUGGAGE", "CUSTOMS", "HANGAR", "PILOT", "GATE", "RADAR", "TOWER", "FLIGHT"], cross=8, cover=0.96, decoys=2),
        L(7, 10, 4, 0.68, 4, ("Mers et îles", "Seas and islands"), ["CATAMARAN", "PÉNINSULE", "ARCHIPEL", "NAUFRAGE", "PLONGÉE", "LAGUNE", "RÉCIF", "ÎLE", "BALEINE", "PHARE", "ATOLL", "MARÉE"], ["CATAMARAN", "PENINSULA", "SHIPWRECK", "SEASHORE", "SNORKEL", "LAGOON", "REEF", "BAY", "WHALE", "LIGHTHOUSE", "ATOLL", "TIDE"], cross=8, cover=0.95, decoys=2),
        L(8, 10, 4, 0.84, 4, ("Déserts", "Deserts"), ["DROMADAIRE", "CARAVANE", "SCORPION", "BÉDOUIN", "SAHARA", "MIRAGE", "CACTUS", "DUNES", "SOIF", "OASIS", "SABLE", "CHAMEAU"], ["SANDSTORM", "SCORPION", "CARAVAN", "BEDOUIN", "MIRAGE", "CACTUS", "SAHARA", "CANYON", "DUNE", "OASIS", "CAMEL", "THIRST"], cross=9, cover=0.95, decoys=4),
        L(9, 11, 4, 0.9, 5, ("Capitales", "Capitals"), ["WASHINGTON", "BRUXELLES", "STOCKHOLM", "BUDAPEST", "LISBONNE", "NAIROBI", "BANGKOK", "ROME", "OSLO", "MADRID", "LONDRES", "BERLIN", "VIENNE"], ["WASHINGTON", "STOCKHOLM", "AMSTERDAM", "BRUSSELS", "NAIROBI", "BANGKOK", "LISBON", "ROME", "OSLO", "MADRID", "LONDON", "BERLIN", "VIENNA"], cross=9, cover=0.95, decoys=4),
        L(10, 12, 4, 1.0, 5, ("Tour du monde", "Around the world"), ["CARTOGRAPHIE", "EXPLORATEUR", "DESTINATION", "ITINÉRAIRE", "EXPÉDITION", "PASSEPORT", "CONTINENT", "FRONTIÈRE", "VOYAGEUR", "BOUSSOLE", "VALISE", "CARTE", "TRAIN", "CAP", "VOL", "AVION"], ["CARTOGRAPHY", "EXPLORATION", "DESTINATION", "ADVENTURER", "EXPEDITION", "ITINERARY", "CONTINENT", "PASSPORT", "TRAVELER", "COMPASS", "TICKET", "TRAIN", "ROAD", "MAP", "BAG", "PLANE"], cross=12, cover=0.97, decoys=8),
    ]),
    dict(id="chapter-03", index=3, palette="cosmos", theme=("Espace", "Space"), levels=[
        L(1, 8, 3, 0.56, 3, ("Système solaire", "Solar system"), ["SOLEIL", "TERRE", "MARS", "VÉNUS", "JUPITER", "SATURNE", "URANUS", "NEPTUNE", "LUNE", "PLANÈTES"], ["STAR", "EARTH", "MARS", "VENUS", "JUPITER", "SATURN", "URANUS", "NEPTUNE", "MOON", "ASTEROID"], cross=7, cover=0.95, decoys=3),
        L(2, 8, 4, 0.6, 3, ("Fusée", "Rocket"), ["FUSÉE", "MOTEUR", "NAVETTE", "ORBITE", "CAPSULE", "PILOTE", "RADAR", "DÉCOLLER", "SAS", "COMPTE"], ["ROCKET", "THRUSTER", "SHUTTLE", "ORBIT", "CAPSULE", "PILOT", "RADAR", "LIFTOFF", "SUIT", "LAUNCH"], cross=7, cover=0.96, decoys=1),
        L(3, 9, 4, 0.56, 4, ("Étoiles et galaxies", "Stars and galaxies"), ["NÉBULEUSE", "SUPERNOVA", "GALAXIE", "ÉTOILE", "COMÈTE", "QUASAR", "PULSAR", "COSMOS", "ASTRE", "ORION", "SIRIUS"], ["SUPERNOVA", "ASTEROID", "STARDUST", "GALAXY", "COMET", "QUASAR", "PULSAR", "COSMOS", "ORION", "SIRIUS", "NEBULA"], cross=8, cover=0.96, decoys=1),
        L(4, 9, 4, 0.74, 4, ("Astronautes", "Astronauts"), ["ÉQUIPAGE", "MISSION", "GRAVITÉ", "STATION", "HUBLOT", "CASQUE", "GANTS", "SANGLE", "LUNAIRE", "SONDE", "EAU"], ["ASTRONAUT", "MISSION", "GRAVITY", "STATION", "HATCH", "HELMET", "GLOVES", "LUNAR", "PROBE", "ROVER", "CREW"], cross=8, cover=0.96, decoys=1),
        L(5, 10, 4, 0.62, 4, ("Télescope", "Telescope"), ["TÉLESCOPE", "PARALLAXE", "OCULAIRE", "LENTILLE", "LUMIÈRE", "SPECTRE", "ÉCLIPSE", "ZÉNITH", "FOCALE", "MIROIR", "LUNETTE", "ZOOM"], ["TELESCOPE", "PARALLAX", "EYEPIECE", "SPECTRUM", "ECLIPSE", "ZENITH", "MIRROR", "LENS", "LIGHT", "FOCUS", "ZOOM", "OPTICS"], cross=9, cover=0.95, decoys=2),
        L(6, 10, 4, 0.81, 4, ("Satellites", "Satellites"), ["SATELLITE", "TÉLÉCOMS", "ANTENNE", "SIGNAL", "PANNEAU", "SOLAIRE", "ORBITE", "TERRE", "LUNE", "CODE", "RADIO", "SONDE"], ["SATELLITE", "ANTENNA", "SIGNAL", "PANEL", "SOLAR", "ORBIT", "TELECOM", "EARTH", "MOON", "CODE", "RADIO", "PROBE"], cross=9, cover=0.95, decoys=3),
        L(7, 10, 4, 0.88, 4, ("Mission Mars", "Mars mission"), ["EXPÉDITION", "POUSSIÈRE", "COLONIE", "CRATÈRE", "VOLCAN", "TEMPÊTE", "DÉSERT", "ATTERRIR", "HABITAT", "CANYON", "ROVER", "GLACE", "FER"], ["EXPEDITION", "COLONY", "CRATER", "VOLCANO", "CANYON", "DESERT", "HABITAT", "LANDING", "STORM", "DUST", "ROVER", "ICE", "IRON"], cross=9, cover=0.96, decoys=3),
        L(8, 11, 4, 0.9, 4, ("Univers", "Universe"), ["SINGULARITÉ", "GRAVITATION", "RELATIVITÉ", "EXPANSION", "HORIZON", "MATIÈRE", "ÉNERGIE", "ESPACE", "INFINI", "TEMPS", "VIDE", "TROU", "ONDE"], ["SINGULARITY", "GRAVITATION", "RELATIVITY", "EXPANSION", "HORIZON", "MATTER", "ENERGY", "SPACE", "INFINITY", "TIME", "VOID", "HOLE", "WAVE"], cross=9, cover=0.95, decoys=4),
        L(9, 11, 4, 0.9, 5, ("Exploration", "Exploration"), ["TRAJECTOIRE", "ÉCHANTILLON", "TÉLÉMÉTRIE", "VOYAGEUR", "DONNÉES", "SURVOL", "CAMÉRA", "CARTE", "RELAIS", "LASER", "PHOTO", "FLUX", "ÉCHO", "SONDE"], ["TRAJECTORY", "SPACECRAFT", "TELEMETRY", "VOYAGER", "DATA", "FLYBY", "CAMERA", "CHART", "RELAY", "LASER", "PHOTO", "FLUX", "ECHO", "PROBE"], cross=10, cover=0.96, decoys=6),
        L(10, 12, 4, 1.0, 5, ("La Voie lactée", "The Milky Way"), ["OBSERVATOIRE", "ASTRONAUTE", "EXOPLANÈTE", "GRAVITATION", "SATELLITE", "TÉLESCOPE", "NÉBULEUSE", "SUPERNOVA", "ANNEAUX", "TERRE", "GALAXIE", "COMÈTE", "ÉTOILE", "ORBITE", "SOLEIL", "LUNE", "MARS"], ["OBSERVATORY", "ASTRONAUT", "EXOPLANET", "GRAVITATION", "SATELLITE", "TELESCOPE", "SUPERNOVA", "ASTEROID", "MILKYWAY", "GALAXY", "COMET", "ORBIT", "EARTH", "MOON", "MARS", "RINGS", "NEBULA"], cross=12, cover=0.97, decoys=9),
    ]),
    dict(id="chapter-04", index=4, palette="legend", theme=("Légendes", "Legends"), levels=[
        L(1, 9, 4, 0.56, 4, ("Chevaliers", "Knights"), ["CHEVALIER", "ÉPÉE", "ARMURE", "BOUCLIER", "LANCE", "CASQUE", "ÉCUYER", "DONJON", "TOURNOI", "FIER", "ROI"], ["CHIVALRY", "DUNGEON", "KNIGHT", "SWORD", "ARMOR", "SHIELD", "LANCE", "HELMET", "SQUIRE", "BANNER", "KING"], cross=8, cover=0.96, decoys=1),
        L(2, 9, 4, 0.67, 4, ("Dragons", "Dragons"), ["ÉCAILLES", "TANIÈRE", "CAVERNE", "DRAGON", "FLAMME", "TRÉSOR", "GRIFFE", "SOUFFLE", "AILES", "FUMÉE", "FEU"], ["SCALES", "LAIR", "CAVERN", "DRAGON", "FLAME", "TREASURE", "CLAWS", "WINGS", "BREATH", "SMOKE", "FIRE"], cross=8, cover=0.96, decoys=1),
        L(3, 10, 4, 0.57, 4, ("Magie", "Magic"), ["SORCIER", "POTION", "GRIMOIRE", "BAGUETTE", "ENCHANTEUR", "SORTILÈGE", "MAGICIEN", "CHAUDRON", "ALCHIMIE", "CRISTAL", "RUNES", "ELFE"], ["SPELLBOOK", "ENCHANTER", "SORCERER", "MAGICIAN", "CAULDRON", "ALCHEMY", "CRYSTAL", "WIZARD", "POTION", "WAND", "RUNES", "ELF"], cross=9, cover=0.95, decoys=1),
        L(4, 10, 4, 0.68, 4, ("Créatures", "Creatures"), ["MINOTAURE", "CENTAURE", "LICORNE", "GRIFFON", "GOBELIN", "VAMPIRE", "FANTÔME", "SIRÈNE", "PHÉNIX", "GÉANT", "TROLL", "ORC"], ["LEPRECHAUN", "WEREWOLF", "MINOTAUR", "UNICORN", "GRIFFIN", "GOBLIN", "VAMPIRE", "PHOENIX", "MERMAID", "GIANT", "TROLL", "ORC"], cross=9, cover=0.95, decoys=2),
        L(5, 10, 4, 0.71, 5, ("Mythes grecs", "Greek myths"), ["LABYRINTHE", "HERCULE", "ACHILLE", "POSÉIDON", "OLYMPE", "ODYSSÉE", "ATHÉNA", "MÉDUSE", "PÉGASE", "ICARE", "TITAN", "HYDRE", "ZEUS"], ["LABYRINTH", "HERCULES", "ACHILLES", "POSEIDON", "OLYMPUS", "ODYSSEY", "ATHENA", "MEDUSA", "PEGASUS", "ICARUS", "TITAN", "HYDRA", "ZEUS"], cross=9, cover=0.96, decoys=3),
        L(6, 11, 4, 0.82, 5, ("Légendes du Nord", "Northern legends"), ["SCANDINAVIE", "BERSERKER", "RAGNAROK", "VALHALLA", "DRAKKAR", "MJOLNIR", "GUERRIER", "ODIN", "THOR", "LOKI", "RUNE", "HACHE", "FJORD"], ["SCANDINAVIA", "BERSERKER", "RAGNAROK", "VALHALLA", "LONGSHIP", "MJOLNIR", "WARRIOR", "ODIN", "THOR", "LOKI", "RUNE", "AXE", "FJORD"], cross=9, cover=0.95, decoys=3),
        L(7, 11, 4, 0.8, 5, ("Hors-la-loi", "Outlaws"), ["NOTTINGHAM", "AVENTURIER", "SHERWOOD", "MARIANNE", "TAVERNE", "BANDIT", "FLÈCHE", "SHÉRIF", "ARCHER", "CIBLE", "CAPE", "FORÊT", "LAC", "ROI"], ["NOTTINGHAM", "ADVENTURER", "SHERWOOD", "MARIAN", "TAVERN", "BANDIT", "ARROW", "SHERIFF", "ARCHER", "TARGET", "CAPE", "FOREST", "LAKE", "KING"], cross=10, cover=0.96, decoys=4),
        L(8, 11, 4, 0.89, 5, ("Contes sombres", "Dark tales"), ["CRÉPUSCULE", "CIMETIÈRE", "ARAIGNÉE", "SQUELETTE", "SORCIÈRE", "CERCUEIL", "FANTÔME", "SPECTRE", "MOMIE", "ZOMBI", "BRUME", "LUNE", "HIBOU", "TOMBE"], ["CANDLELIGHT", "GRAVEYARD", "SKELETON", "SORCERESS", "COFFIN", "GHOST", "SPECTER", "MUMMY", "ZOMBIE", "FOG", "MOON", "OWL", "TOMB", "SPIDER"], cross=10, cover=0.96, decoys=6),
        L(9, 11, 4, 0.94, 5, ("Pirates", "Pirates"), ["MOUSSAILLON", "FLIBUSTIER", "BOUCANIER", "PERROQUET", "ABORDAGE", "CORSAIRE", "BOUSSOLE", "GALION", "CANON", "CARTE", "CRÂNE", "VOILE", "RHUM", "MÂT", "PONT"], ["SHIPWRECKED", "BUCCANEER", "PRIVATEER", "BOARDING", "GALLEON", "PARROT", "COMPASS", "CUTLASS", "CANNON", "MAP", "SKULL", "SAIL", "RUM", "MAST", "DECK"], cross=11, cover=0.96, decoys=6),
        L(10, 12, 4, 1.0, 5, ("Royaume enchanté", "Enchanted kingdom"), ["COURONNEMENT", "ENCHANTEMENT", "FORTERESSE", "CHEVALIER", "PRINCESSE", "PARCHEMIN", "LICORNE", "SORCIER", "LÉGENDE", "ROYAUME", "DONJON", "DRAGON", "ÉPOPÉE", "TRÔNE", "SCEPTRE", "ÉPÉE", "FÉE", "ELFE"], ["ENCHANTMENT", "CORONATION", "FORTRESS", "KNIGHT", "PRINCESS", "PARCHMENT", "UNICORN", "SORCERER", "LEGEND", "KINGDOM", "DUNGEON", "DRAGON", "EPIC", "THRONE", "SCEPTER", "SWORD", "FAIRY", "ELF"], cross=13, cover=0.97, decoys=10),
    ]),
    dict(id="chapter-05", index=5, palette="lab", theme=("Sciences", "Science"), levels=[
        L(1, 10, 4, 0.62, 4, ("Chimie", "Chemistry"), ["ÉPROUVETTE", "HYDROGÈNE", "MOLÉCULE", "RÉACTION", "SOLUTION", "ÉLÉMENT", "OXYGÈNE", "CARBONE", "SODIUM", "ACIDE", "ATOME"], ["CHEMISTRY", "MOLECULE", "REACTION", "SOLUTION", "NITROGEN", "ELEMENT", "OXYGEN", "CARBON", "SODIUM", "ACID", "ATOM"], cross=9, cover=0.95, decoys=1),
        L(2, 10, 4, 0.66, 4, ("Physique", "Physics"), ["MAGNÉTISME", "GRAVITÉ", "ÉNERGIE", "VITESSE", "LUMIÈRE", "ÉLECTRON", "PROTON", "NEUTRON", "FORCE", "MASSE", "ONDE", "OPTIQUE"], ["MAGNETISM", "GRAVITY", "ENERGY", "VELOCITY", "ELECTRON", "PROTON", "NEUTRON", "FORCE", "MASS", "WAVE", "LIGHT", "OPTICS"], cross=9, cover=0.95, decoys=1),
        L(3, 10, 4, 0.67, 4, ("Biologie", "Biology"), ["ÉVOLUTION", "ORGANISME", "BACTÉRIE", "CELLULE", "ESPÈCE", "ENZYME", "MITOSE", "NOYAU", "VIRUS", "GÈNE", "ADN", "TISSU", "HÉRÉDITÉ"], ["EVOLUTION", "ORGANISM", "BACTERIA", "CELL", "SPECIES", "ENZYME", "MITOSIS", "NUCLEUS", "VIRUS", "GENE", "DNA", "TISSUE", "HEREDITY"], cross=10, cover=0.96, decoys=1),
        L(4, 11, 4, 0.69, 4, ("Corps humain", "Human body"), ["RESPIRATION", "CIRCULATION", "DIGESTION", "SQUELETTE", "MUSCLE", "CERVEAU", "POUMON", "ESTOMAC", "ARTÈRE", "COEUR", "FOIE", "REIN", "PEAU"], ["RESPIRATION", "CIRCULATION", "DIGESTION", "SKELETON", "MUSCLE", "BRAIN", "LUNG", "STOMACH", "ARTERY", "HEART", "LIVER", "KIDNEY", "SKIN"], cross=10, cover=0.95, decoys=1),
        L(5, 11, 4, 0.59, 4, ("Mathématiques", "Mathematics"), ["PROBABILITÉ", "MULTIPLIER", "GÉOMÉTRIE", "ADDITION", "FRACTION", "ALGÈBRE", "TRIANGLE", "ÉQUATION", "CERCLE", "CARRÉ", "SOMME", "VOLUME", "ZÉRO", "DROITE"], ["PROBABILITY", "GEOMETRY", "ADDITION", "FRACTION", "ALGEBRA", "TRIANGLE", "EQUATION", "CIRCLE", "SQUARE", "TOTAL", "VOLUME", "ZERO", "LINE", "MULTIPLY"], cross=10, cover=0.96, decoys=2),
        L(6, 11, 4, 0.74, 5, ("Inventions", "Inventions"), ["PÉNICILLINE", "IMPRIMERIE", "ORDINATEUR", "TÉLÉPHONE", "AMPOULE", "BOUSSOLE", "MACHINE", "MOTEUR", "ROUE", "PILE", "RADIO", "LASER", "VACCIN", "CAMÉRA"], ["PENICILLIN", "TELEPHONE", "LIGHTBULB", "COMPUTER", "AIRPLANE", "COMPASS", "MACHINE", "ENGINE", "WHEEL", "BATTERY", "GEAR", "LASER", "VACCINE", "CAMERA"], cross=10, cover=0.96, decoys=2),
        L(7, 11, 4, 0.71, 5, ("Géologie", "Geology"), ["TREMBLEMENT", "STALACTITE", "ÉRUPTION", "MINÉRAL", "FOSSILE", "GRANITE", "BASALTE", "CRISTAL", "MAGMA", "LAVE", "ROCHE", "FAILLE", "GEYSER", "ARGILE", "SABLE"], ["EARTHQUAKE", "STALACTITE", "ERUPTION", "MINERAL", "FOSSIL", "GRANITE", "BASALT", "CRYSTAL", "MAGMA", "LAVA", "ROCK", "FAULT", "GEYSER", "CLAY", "SAND"], cross=11, cover=0.96, decoys=3),
        L(8, 11, 4, 0.82, 5, ("Électricité", "Electricity"), ["ÉLECTRICITÉ", "GÉNÉRATEUR", "CONDUCTEUR", "ÉOLIENNE", "BATTERIE", "TURBINE", "CENTRALE", "COURANT", "TENSION", "CIRCUIT", "ÉCLAIR", "FOUDRE", "PILE", "FIL", "VOLT"], ["ELECTRICITY", "GENERATOR", "CONDUCTOR", "LIGHTNING", "VOLTAGE", "CIRCUIT", "CURRENT", "TURBINE", "BATTERY", "WINDMILL", "THUNDER", "POWER", "WIRE", "COIL", "FUSE"], cross=11, cover=0.96, decoys=3),
        L(9, 11, 4, 0.69, 5, ("Technologie", "Technology"), ["TÉLÉCHARGER", "ALGORITHME", "NAVIGATEUR", "PROCESSEUR", "IMPRIMANTE", "TÉLÉPHONE", "CLAVIER", "ÉCRAN", "SOURIS", "ROBOT", "DONNÉES", "MÉMOIRE", "INTERNET", "PIXEL", "CODE", "WIFI"], ["PROGRAMMING", "TECHNOLOGY", "ALGORITHM", "PROCESSOR", "BLUETOOTH", "KEYBOARD", "SCREEN", "MOUSE", "ROBOT", "MEMORY", "INTERNET", "PIXEL", "CODE", "WIFI", "DATA", "CLOUD"], cross=12, cover=0.96, decoys=4),
        L(10, 12, 4, 1.0, 5, ("Laboratoire", "Laboratory"), ["SCIENTIFIQUE", "LABORATOIRE", "THERMOMÈTRE", "EXPÉRIENCE", "MICROSCOPE", "HYPOTHÈSE", "ANALYSE", "BALANCE", "THÉORIE", "FORMULE", "RÉSULTAT", "MESURE", "PREUVE", "CALCUL", "DONNÉES", "IDÉE"], ["THERMOMETER", "LABORATORY", "EXPERIMENT", "MICROSCOPE", "HYPOTHESIS", "RESEARCHER", "DISCOVERY", "SCIENTIST", "ANALYSIS", "BALANCE", "THEORY", "FORMULA", "RESULT", "MEASURE", "PROOF", "DATA"], cross=14, cover=0.97, decoys=10),
    ]),
    dict(id="chapter-06", index=6, palette="history", theme=("Histoire", "History"), levels=[
        L(1, 10, 4, 0.57, 4, ("Antiquité", "Antiquity"), ["ACROPOLE", "GLADIATEUR", "PHILOSOPHE", "OLYMPIADE", "AMPHORE", "COLONNE", "TEMPLE", "ESCLAVE", "SPARTE", "ATHÈNES", "ARÈNE", "LYRE"], ["ACROPOLIS", "GLADIATOR", "PHILOSOPHY", "OLYMPICS", "AMPHORA", "COLUMN", "TEMPLE", "SLAVE", "SPARTA", "ATHENS", "ARENA", "LYRE"], cross=9, cover=0.96, decoys=1),
        L(2, 10, 4, 0.59, 4, ("Égypte antique", "Ancient Egypt"), ["PYRAMIDE", "PHARAON", "SPHINX", "MOMIE", "SARCOPHAGE", "PAPYRUS", "CLÉOPÂTRE", "OBÉLISQUE", "SCARABÉE", "TOMBEAU", "DÉSERT", "RAMSÈS", "NIL"], ["PYRAMID", "PHARAOH", "SPHINX", "MUMMY", "HIEROGLYPH", "PAPYRUS", "CLEOPATRA", "OBELISK", "SCARAB", "TOMB", "DESERT", "RAMSES", "NILE"], cross=10, cover=0.96, decoys=1),
        L(3, 10, 4, 0.61, 4, ("Rome antique", "Ancient Rome"), ["COLISÉE", "SÉNATEUR", "CÉSAR", "LÉGION", "AQUEDUC", "EMPEREUR", "TOGE", "FORUM", "CHARIOT", "MOSAÏQUE", "PANTHÉON", "CENTURION", "THERMES"], ["COLOSSEUM", "SENATOR", "CAESAR", "LEGION", "AQUEDUCT", "EMPEROR", "TOGA", "FORUM", "CHARIOT", "MOSAIC", "PANTHEON", "CENTURION", "BATHS"], cross=10, cover=0.96, decoys=2),
        L(4, 11, 4, 0.59, 4, ("Moyen Âge", "Middle Ages"), ["CATHÉDRALE", "TROUBADOUR", "FÉODALITÉ", "CHEVALERIE", "MÉNESTREL", "CHÂTELAIN", "ENLUMINURE", "PARCHEMIN", "MONASTÈRE", "CROISADE", "REMPART", "SERF", "MOINE", "PESTE"], ["CATHEDRAL", "TROUBADOUR", "FEUDALISM", "CHIVALRY", "MINSTREL", "MANUSCRIPT", "PARCHMENT", "MONASTERY", "CRUSADE", "RAMPART", "SERF", "MONK", "PLAGUE", "DRAWBRIDGE"], cross=11, cover=0.96, decoys=1),
        L(5, 11, 4, 0.56, 4, ("Grandes découvertes", "Great explorers"), ["EXPLORATEUR", "CARAVELLE", "NAVIGATEUR", "COLOMB", "MAGELLAN", "ASTROLABE", "BOUSSOLE", "CONTINENT", "AMÉRIQUE", "CARTOGRAPHE", "EXPÉDITION", "ÉQUIPAGE", "TRAVERSÉE", "CAP"], ["EXPLORER", "CARAVEL", "NAVIGATOR", "COLUMBUS", "MAGELLAN", "ASTROLABE", "COMPASS", "CONTINENT", "AMERICA", "EXPEDITION", "SAILOR", "CREW", "SEXTANT", "DISCOVERY"], cross=11, cover=0.96, decoys=2),
        L(6, 11, 4, 0.66, 5, ("Renaissance", "Renaissance"), ["RENAISSANCE", "HUMANISME", "MÉCÈNE", "MÉDICIS", "FLORENCE", "PEINTURE", "SCULPTURE", "FRESQUE", "PERSPECTIVE", "ANATOMIE", "VINCI", "GUTENBERG", "INVENTEUR", "ART"], ["RENAISSANCE", "HUMANISM", "PATRON", "MEDICI", "FLORENCE", "PAINTING", "SCULPTURE", "FRESCO", "PERSPECTIVE", "ANATOMY", "LEONARDO", "GUTENBERG", "INVENTOR", "ART"], cross=11, cover=0.96, decoys=3),
        L(7, 11, 4, 0.63, 5, ("Révolutions", "Revolutions"), ["RÉVOLUTION", "BASTILLE", "LIBERTÉ", "ÉGALITÉ", "FRATERNITÉ", "GUILLOTINE", "NAPOLÉON", "DÉCLARATION", "RÉPUBLIQUE", "PARLEMENT", "DRAPEAU", "TRICOLORE", "CITOYEN", "ASSEMBLÉE", "ROI"], ["REVOLUTION", "BASTILLE", "LIBERTY", "EQUALITY", "FRATERNITY", "GUILLOTINE", "NAPOLEON", "DECLARATION", "REPUBLIC", "PARLIAMENT", "FLAG", "TRICOLOR", "CITIZEN", "ASSEMBLY", "KING"], cross=12, cover=0.96, decoys=3),
        L(8, 11, 4, 0.76, 5, ("Civilisations", "Civilizations"), ["AZTÈQUES", "MAYAS", "INCAS", "VIKINGS", "MÉSOPOTAMIE", "BABYLONE", "PERSES", "PHÉNICIENS", "SUMÉRIENS", "CARTHAGE", "EMPIRE", "CUNÉIFORME", "ZIGGOURAT", "ANDES", "TROIE"], ["AZTECS", "MAYANS", "INCAS", "VIKINGS", "MESOPOTAMIA", "BABYLON", "PERSIANS", "PHOENICIANS", "SUMERIANS", "CARTHAGE", "EMPIRE", "CUNEIFORM", "ZIGGURAT", "ANDES", "TROY"], cross=12, cover=0.96, decoys=4),
        L(9, 11, 4, 0.65, 5, ("Archéologie", "Archaeology"), ["ARCHÉOLOGUE", "FOUILLES", "VESTIGES", "RUINES", "POTERIE", "OSSEMENTS", "DATATION", "ARTEFACT", "MUSÉE", "TROUVAILLE", "SITE", "PELLE", "PINCEAU", "GISEMENT", "PRÉHISTOIRE", "MONUMENT"], ["ARCHAEOLOGY", "EXCAVATION", "RELICS", "RUINS", "POTTERY", "BONES", "DATING", "ARTIFACT", "MUSEUM", "TREASURE", "SITE", "SHOVEL", "BRUSH", "FOSSIL", "PREHISTORY", "MONUMENT"], cross=13, cover=0.96, decoys=5),
        L(10, 12, 4, 1, 5, ("Voyage dans le temps", "Time travel"), ["CIVILISATION", "CHRONOLOGIE", "HISTORIEN", "CHRONIQUE", "DYNASTIE", "MONARCHIE", "PATRIMOINE", "CONQUÉRANT", "MILLÉNAIRE", "GÉNÉRATION", "HÉRITAGE", "ARCHIVES", "ÉPOQUE", "SIÈCLE", "PASSÉ", "TEMPS", "ÈRE"], ["CIVILIZATION", "CHRONOLOGY", "HISTORIAN", "CHRONICLE", "DYNASTY", "MONARCHY", "HERITAGE", "CONQUEROR", "MILLENNIUM", "GENERATION", "ANCESTOR", "ARCHIVES", "CENTURY", "PAST", "TIME", "DATE", "LEGACY"], cross=13, cover=0.95, decoys=9),
    ]),
    dict(id="chapter-07", index=7, palette="arts", theme=("Arts", "Arts"), levels=[
        L(1, 10, 4, 0.59, 4, ("Instruments", "Instruments"), ["GUITARE", "PIANO", "VIOLON", "TROMPETTE", "FLÛTE", "SAXOPHONE", "HARPE", "BATTERIE", "ACCORDÉON", "CLARINETTE", "TAMBOUR", "TUBA"], ["GUITAR", "PIANO", "VIOLIN", "TRUMPET", "FLUTE", "SAXOPHONE", "HARP", "DRUMS", "ACCORDION", "CLARINET", "TAMBOURINE", "TUBA"], cross=9, cover=0.96, decoys=1),
        L(2, 10, 4, 0.63, 4, ("Peinture", "Painting"), ["PEINTRE", "PALETTE", "TOILE", "CHEVALET", "AQUARELLE", "PORTRAIT", "PAYSAGE", "COULEUR", "GALERIE", "FUSAIN", "PASTEL", "VERNISSAGE"], ["PAINTER", "PALETTE", "CANVAS", "EASEL", "WATERCOLOR", "PORTRAIT", "LANDSCAPE", "ARTIST", "GALLERY", "CHARCOAL", "PASTEL", "SKETCH"], cross=9, cover=0.96, decoys=2),
        L(3, 10, 4, 0.66, 4, ("Cinéma", "Cinema"), ["SCÉNARIO", "ACTEUR", "ACTRICE", "ÉCRAN", "PROJECTEUR", "COMÉDIE", "SUSPENSE", "STUDIO", "TOURNAGE", "AFFICHE", "PELLICULE", "POPCORN", "CLAP"], ["SCREENPLAY", "ACTOR", "ACTRESS", "CAMERA", "PROJECTOR", "COMEDY", "SUSPENSE", "STUDIO", "DIRECTOR", "POSTER", "FILM", "POPCORN", "CLAP"], cross=10, cover=0.96, decoys=2),
        L(4, 11, 4, 0.6, 4, ("Théâtre", "Theatre"), ["THÉÂTRE", "SCÈNE", "RIDEAU", "COULISSES", "COMÉDIEN", "TRAGÉDIE", "SPECTATEUR", "PERSONNAGE", "RÉPÉTITION", "COSTUME", "MASQUE", "RÔLE", "MOLIÈRE", "ENTRACTE"], ["THEATRE", "SCENE", "CURTAIN", "BACKSTAGE", "COMEDIAN", "TRAGEDY", "AUDIENCE", "CHARACTER", "REHEARSAL", "COSTUME", "MASK", "SCRIPT", "PLAYWRIGHT", "ROLE"], cross=11, cover=0.96, decoys=1),
        L(5, 11, 4, 0.65, 4, ("Danse", "Dance"), ["BALLET", "TUTU", "VALSE", "TANGO", "SALSA", "FLAMENCO", "DANSEUSE", "PIROUETTE", "CHORÉGRAPHE", "RYTHME", "COUPLE", "MAZURKA", "CHAUSSONS", "SAMBA"], ["BALLET", "TUTU", "WALTZ", "TANGO", "SALSA", "FLAMENCO", "DANCER", "PIROUETTE", "PERFORMANCE", "RHYTHM", "COUPLE", "MAZURKA", "SLIPPERS", "SAMBA"], cross=11, cover=0.96, decoys=3),
        L(6, 11, 4, 0.76, 5, ("Littérature", "Literature"), ["ÉCRIVAIN", "ROMAN", "POÈME", "LIBRAIRIE", "BIOGRAPHIE", "MANUSCRIT", "ÉDITEUR", "CHAPITRE", "NOUVELLE", "HUGO", "VOLTAIRE", "CONTE", "FABLE", "MÉTAPHORE"], ["WRITER", "NOVEL", "POEM", "BOOKSTORE", "BIOGRAPHY", "PUBLISHER", "CHAPTER", "STORYTELLER", "DICKENS", "PROSE", "FABLE", "LIBRARY", "METAPHOR", "POETRY"], cross=11, cover=0.96, decoys=3),
        L(7, 11, 4, 0.64, 5, ("Architecture", "Architecture"), ["ARCHITECTE", "BÂTIMENT", "FAÇADE", "COUPOLE", "VOÛTE", "COLONNADE", "BASILIQUE", "MOSQUÉE", "TOUR", "ESCALIER", "FONDATIONS", "CHARPENTE", "MAQUETTE", "ÉCHAFAUDAGE", "BÉTON"], ["ARCHITECT", "BUILDING", "FACADE", "DOME", "VAULT", "COLONNADE", "BASILICA", "MOSQUE", "TOWER", "STAIRCASE", "FOUNDATION", "SCAFFOLDING", "SKYSCRAPER", "CONCRETE", "BLUEPRINT"], cross=12, cover=0.96, decoys=4),
        L(8, 11, 4, 0.78, 5, ("Opéra", "Opera"), ["OPÉRA", "SOPRANO", "TÉNOR", "BARYTON", "CANTATRICE", "ORCHESTRE", "MAESTRO", "PARTITION", "LIVRET", "ARIA", "CHOEUR", "MOZART", "SYMPHONIE", "CRESCENDO", "DIVA"], ["OPERA", "SOPRANO", "TENOR", "BARITONE", "PRIMADONNA", "ORCHESTRA", "MAESTRO", "LIBRETTO", "ARIA", "CHORUS", "MOZART", "SYMPHONY", "CRESCENDO", "DIVA", "CONDUCTOR"], cross=12, cover=0.96, decoys=4),
        L(9, 11, 4, 0.67, 5, ("Photographie", "Photography"), ["PHOTOGRAPHE", "OBJECTIF", "FLASH", "TRÉPIED", "NÉGATIF", "CLICHÉ", "ZOOM", "ALBUM", "CAMERA", "EXPOSITION", "FOCALE", "RETOUCHE", "CADRAGE", "NUMÉRIQUE", "SELFIE", "PANORAMA"], ["PHOTOGRAPHY", "LENS", "FLASH", "TRIPOD", "NEGATIVE", "SNAPSHOT", "ZOOM", "ALBUM", "APERTURE", "EXPOSURE", "SHUTTER", "RETOUCH", "FRAMING", "DIGITAL", "SELFIE", "PANORAMA"], cross=13, cover=0.96, decoys=5),
        L(10, 12, 4, 1, 5, ("Festival des arts", "Arts festival"), ["ILLUSTRATION", "INSPIRATION", "DANSE", "POETE", "MARIONNETTE", "TALENT", "SPECTACLE", "SCULPTEUR", "MUSICIEN", "JONGLEUR", "ACROBATE", "FESTIVAL", "CIRQUE", "CLOWN", "MIME", "MAGIE", "OEUVRE"], ["ILLUSTRATION", "INSPIRATION", "DANCE", "TALENT", "MARIONETTE", "SCULPTOR", "MUSICIAN", "JUGGLER", "ACROBAT", "FESTIVAL", "SPECTACLE", "CIRCUS", "CLOWN", "MIME", "MAGIC", "ARTWORK", "POET"], cross=13, cover=0.95, decoys=10),
    ]),
    dict(id="chapter-08", index=8, palette="arena", theme=("Sports", "Sports"), levels=[
        L(1, 10, 4, 0.56, 4, ("Football", "Soccer"), ["FOOTBALL", "GARDIEN", "ATTAQUANT", "DÉFENSEUR", "ARBITRE", "PENALTY", "CORNER", "DRIBBLE", "STADE", "MAILLOT", "GOAL", "SIFFLET"], ["SOCCER", "KEEPER", "STRIKER", "MIDFIELDER", "REFEREE", "PENALTY", "CORNER", "DRIBBLE", "STADIUM", "JERSEY", "GOAL", "WHISTLE"], cross=9, cover=0.96, decoys=2),
        L(2, 10, 4, 0.75, 4, ("Basket-ball", "Basketball"), ["BASKET", "PANIER", "DUNK", "REBOND", "MENEUR", "PIVOT", "TERRAIN", "CERCEAU", "LANCER", "ENTRAÎNEUR", "TRIPLE", "BALLON"], ["BASKETBALL", "HOOP", "DUNK", "REBOUND", "GUARD", "CENTER", "FORWARD", "COURT", "SHOOTER", "COACH", "LAYUP", "BACKBOARD"], cross=9, cover=0.96, decoys=2),
        L(3, 10, 4, 0.72, 4, ("Natation", "Swimming"), ["NATATION", "PISCINE", "CRAWL", "BRASSE", "PAPILLON", "PLONGEON", "LUNETTES", "BONNET", "COULOIR", "PLONGEOIR", "PALMES", "RELAIS", "EAU"], ["SWIMMING", "POOL", "CRAWL", "BACKSTROKE", "BUTTERFLY", "DIVING", "GOGGLES", "LANE", "SWIMMER", "FLIPPERS", "RELAY", "WATER", "LIFEGUARD"], cross=10, cover=0.96, decoys=2),
        L(4, 11, 4, 0.59, 4, ("Athlétisme", "Athletics"), ["ATHLÉTISME", "MARATHON", "SPRINT", "HAIES", "SAUT", "PERCHE", "JAVELOT", "DISQUE", "POIDS", "LONGUEUR", "CHRONOMÈTRE", "COUREUR", "RECORD", "DÉCATHLON"], ["ATHLETICS", "MARATHON", "SPRINT", "HURDLES", "JUMP", "POLEVAULT", "JAVELIN", "DISCUS", "SHOTPUT", "RUNNER", "RECORD", "PODIUM", "DECATHLON", "HEPTATHLON"], cross=11, cover=0.96, decoys=2),
        L(5, 11, 4, 0.64, 4, ("Sports d'hiver", "Winter sports"), ["SNOWBOARD", "LUGE", "PATINAGE", "HOCKEY", "BIATHLON", "SLALOM", "BOBSLEIGH", "CURLING", "TREMPLIN", "SKI", "FREESTYLE", "TÉLÉCABINE", "RAQUETTES", "PATINOIRE"], ["SNOWBOARD", "LUGE", "SKATING", "HOCKEY", "BIATHLON", "SLALOM", "BOBSLED", "CURLING", "SKI", "FREESTYLE", "SNOWMOBILE", "SNOWSHOES", "TOBOGGAN", "AVALANCHE"], cross=11, cover=0.96, decoys=3),
        L(6, 11, 4, 0.78, 5, ("Sports de combat", "Combat sports"), ["JUDO", "KARATÉ", "BOXE", "ESCRIME", "LUTTE", "TAEKWONDO", "SUMO", "AÏKIDO", "CEINTURE", "KIMONO", "TATAMI", "ADVERSAIRE", "CHAMPION", "PRISE"], ["JUDO", "KARATE", "RING", "FENCING", "WRESTLING", "TAEKWONDO", "SUMO", "AIKIDO", "KICKBOXING", "KIMONO", "TATAMI", "OPPONENT", "CHAMPION", "PUNCH"], cross=11, cover=0.96, decoys=4),
        L(7, 11, 4, 0.73, 5, ("Cyclisme", "Cycling"), ["CYCLISME", "RAYON", "PÉDALE", "GUIDON", "SELLE", "CHAÎNE", "DÉRAILLEUR", "PELOTON", "ÉCHAPPÉE", "ROUE", "PNEU", "FREIN", "BICYCLETTE", "VELODROME", "ÉTAPE"], ["CYCLING", "BIKE", "PEDAL", "HANDLEBAR", "SADDLE", "CHAIN", "DERAILLEUR", "PELOTON", "BREAKAWAY", "WHEEL", "TIRE", "BRAKE", "BICYCLE", "VELODROME", "SPOKE"], cross=12, cover=0.96, decoys=4),
        L(8, 11, 4, 0.74, 5, ("Jeux olympiques", "Olympic Games"), ["OLYMPIQUES", "MÉDAILLE", "TORCHE", "ATHLÈTE", "CÉRÉMONIE", "ARGENT", "BRONZE", "HYMNE", "DÉLÉGATION", "VILLAGE", "SERMENT", "CANDIDATURE", "COUBERTIN", "ÉPREUVE", "SÉLECTION"], ["OLYMPICS", "MEDAL", "TORCH", "ATHLETE", "CEREMONY", "SILVER", "BRONZE", "ANTHEM", "DELEGATION", "VILLAGE", "OATH", "COUBERTIN", "SELECTION", "GOLD", "PARALYMPICS"], cross=12, cover=0.96, decoys=5),
        L(9, 11, 4, 0.73, 5, ("Sports de raquette", "Racket sports"), ["TENNIS", "BADMINTON", "SQUASH", "RAQUETTE", "FILET", "SERVICE", "VOLÉE", "SMASH", "REVERS", "LIFT", "BALLE", "VOLANT", "WIMBLEDON", "TIEBREAK", "CHAMPIONNAT", "DOUBLE"], ["TENNIS", "BADMINTON", "SQUASH", "RACKET", "LOB", "SERVE", "VOLLEY", "SMASH", "BACKHAND", "FOREHAND", "SHUTTLECOCK", "WIMBLEDON", "TIEBREAK", "TOURNAMENT", "DOUBLES", "PINGPONG"], cross=13, cover=0.96, decoys=5),
        L(10, 12, 4, 1, 5, ("Championnat", "Championship"), ["ENTRAÎNEMENT", "MATCH", "CHAMPIONNAT", "SUPPORTER", "PODIUM", "FINALE", "VICTOIRE", "DÉFAITE", "TROPHÉE", "COUPE", "PERFORMANCE", "ÉQUIPE", "CAPITAINE", "ENDURANCE", "TACTIQUE", "STRATÉGIE", "LIGUE"], ["CHAMPIONSHIP", "TRAINING", "COMPETITION", "SUPPORTER", "STANDINGS", "FINALIST", "VICTORY", "DEFEAT", "TROPHY", "CUP", "PERFORMANCE", "TEAM", "CAPTAIN", "ENDURANCE", "TACTICS", "STRATEGY", "MOMENTUM"], cross=13, cover=0.95, decoys=10),
    ]),
    dict(id="chapter-09", index=9, palette="kitchen", theme=("Gastronomie", "Gastronomy"), levels=[
        L(1, 10, 4, 0.6, 4, ("Légumes", "Vegetables"), ["CAROTTE", "TOMATE", "COURGETTE", "AUBERGINE", "POIVRON", "BROCOLI", "ÉPINARD", "POIREAU", "CHAMPIGNON", "RADIS", "CHOU", "OIGNON"], ["CARROT", "TOMATO", "ZUCCHINI", "EGGPLANT", "PEPPER", "BROCCOLI", "SPINACH", "LEEK", "MUSHROOM", "RADISH", "ARTICHOKE", "ONION"], cross=9, cover=0.96, decoys=2),
        L(2, 10, 4, 0.64, 4, ("Boulangerie", "Bakery"), ["BOULANGER", "BAGUETTE", "CROISSANT", "BRIOCHE", "PAIN", "FARINE", "LEVURE", "PÉTRIN", "FOUR", "TARTE", "CHAUSSON", "FICELLE", "GALETTE"], ["BAKERY", "BAGUETTE", "CROISSANT", "BRIOCHE", "BREAD", "FLOUR", "YEAST", "OVEN", "DOUGH", "PASTRY", "BISCUIT", "MUFFIN", "PRETZEL"], cross=10, cover=0.96, decoys=2),
        L(3, 10, 4, 0.65, 4, ("Fromages", "Cheeses"), ["CAMEMBERT", "ROQUEFORT", "COMTÉ", "BRIE", "CHÈVRE", "EMMENTAL", "MOZZARELLA", "GRUYÈRE", "REBLOCHON", "MUNSTER", "CHEDDAR", "FETA", "RACLETTE"], ["CAMEMBERT", "ROQUEFORT", "BRIE", "EMMENTAL", "MOZZARELLA", "GRUYERE", "CHEDDAR", "PARMESAN", "RICOTTA", "FETA", "GOUDA", "MUNSTER", "MASCARPONE"], cross=10, cover=0.96, decoys=3),
        L(4, 11, 4, 0.57, 4, ("Épices", "Spices"), ["CANNELLE", "GINGEMBRE", "SAFRAN", "CURCUMA", "MUSCADE", "CUMIN", "PAPRIKA", "POIVRE", "CARDAMOME", "CORIANDRE", "PIMENT", "VANILLE", "CIBOULETTE", "ANIS"], ["CINNAMON", "GINGER", "SAFFRON", "TURMERIC", "NUTMEG", "CUMIN", "PAPRIKA", "PEPPERCORN", "CARDAMOM", "CORIANDER", "CHILI", "VANILLA", "CLOVES", "SALT"], cross=11, cover=0.96, decoys=3),
        L(5, 11, 4, 0.63, 4, ("Desserts", "Desserts"), ["CHOCOLAT", "GÂTEAU", "MACARON", "PROFITEROLE", "TIRAMISU", "CRÈME", "SORBET", "BEIGNET", "FLAN", "CLAFOUTIS", "MOUSSE", "CARAMEL", "PÂTISSERIE", "MERINGUE"], ["CHOCOLATE", "MACARON", "PROFITEROLE", "TIRAMISU", "CREAM", "SORBET", "DOUGHNUT", "PUDDING", "CUSTARD", "MOUSSE", "CARAMEL", "MERINGUE", "BROWNIE", "FLAN"], cross=11, cover=0.96, decoys=4),
        L(6, 11, 4, 0.78, 5, ("Boissons", "Drinks"), ["LIMONADE", "CAFÉ", "TISANE", "INFUSION", "SMOOTHIE", "CIDRE", "SIROP", "ORANGEADE", "COCKTAIL", "CAPPUCCINO", "ESPRESSO", "BOUTEILLE", "GLAÇONS", "LAIT"], ["LEMONADE", "COFFEE", "TEA", "INFUSION", "SMOOTHIE", "CIDER", "SYRUP", "ORANGEADE", "COCKTAIL", "CAPPUCCINO", "ESPRESSO", "BOTTLE", "STRAW", "MILK"], cross=11, cover=0.96, decoys=4),
        L(7, 11, 4, 0.68, 5, ("Petit-déjeuner", "Breakfast"), ["CÉRÉALES", "CONFITURE", "TARTINE", "BEURRE", "OEUF", "YAOURT", "MIEL", "GRANOLA", "PANCAKE", "BACON", "OMELETTE", "NUTELLA", "MARMELADE", "CHOCOLATINE", "PORRIDGE"], ["CEREAL", "JAM", "TOAST", "BUTTER", "EGGS", "YOGURT", "HONEY", "GRANOLA", "PANCAKES", "BACON", "OMELETTE", "WAFFLES", "MARMALADE", "BLUEBERRIES", "PORRIDGE"], cross=12, cover=0.96, decoys=5),
        L(8, 11, 4, 0.81, 5, ("Ustensiles", "Kitchen tools"), ["CASSEROLE", "POÊLE", "COUTEAU", "FOURCHETTE", "LOUCHE", "SPATULE", "FOUET", "PASSOIRE", "RÂPE", "ÉPLUCHEUR", "MARMITE", "ASSIETTE", "MIXEUR", "ENTONNOIR", "SALADIER"], ["SAUCEPAN", "SKILLET", "KNIFE", "FORK", "SPOON", "LADLE", "SPATULA", "WHISK", "COLANDER", "GRATER", "PEELER", "POT", "PLATE", "BLENDER", "CHOPSTICKS"], cross=12, cover=0.96, decoys=5),
        L(9, 11, 4, 0.62, 5, ("Marché", "Market"), ["MARCHÉ", "MARCHANDER", "ÉTAL", "LÉGUMES", "FRUITS", "FROMAGER", "BOUCHER", "POISSONNIER", "PRIMEUR", "PRIX", "ÉPICERIE", "SAISON", "BIOLOGIQUE", "PRODUCTEUR", "RÉCOLTE", "TERROIR"], ["MARKET", "MERCHANT", "STALL", "VEGETABLES", "FRUITS", "FISHMONGER", "BUTCHER", "GREENGROCER", "GROCERY", "PRICE", "SEASON", "ORGANIC", "PRODUCER", "HARVEST", "FARMER", "BARGAIN"], cross=13, cover=0.96, decoys=6),
        L(10, 12, 4, 1, 5, ("Grand banquet", "Grand feast"), ["GASTRONOMIE", "RESTAURANT", "TABLE", "REPAS", "SOMMELIER", "BANQUET", "RECETTE", "INGRÉDIENT", "CUISINIER", "PLAT", "SAVEURS", "FESTIN", "MENU", "ENTRÉE", "DESSERT", "APÉRITIF", "GOURMANDISE"], ["GASTRONOMY", "RESTAURANT", "CHOCOLATIER", "SOMMELIER", "BANQUET", "RECIPE", "INGREDIENT", "CUISINE", "TASTING", "FLAVORS", "FEAST", "MENU", "STARTER", "DESSERT", "APERITIF", "GOURMET", "COOKBOOK"], cross=13, cover=0.95, decoys=10),
    ]),
    dict(id="chapter-10", index=10, palette="workshop", theme=("Métiers", "Careers"), levels=[
        L(1, 10, 4, 0.61, 4, ("Santé", "Healthcare"), ["MÉDECIN", "INFIRMIER", "CHIRURGIEN", "PHARMACIEN", "DENTISTE", "HÔPITAL", "URGENCES", "SCALPEL", "SERINGUE", "PANSEMENT", "CLINIQUE", "SOIN"], ["DOCTOR", "NURSE", "SURGEON", "PHARMACIST", "DENTIST", "HOSPITAL", "EMERGENCY", "SCALPEL", "SYRINGE", "BANDAGE", "CLINIC", "CARE"], cross=9, cover=0.96, decoys=2),
        L(2, 10, 4, 0.55, 4, ("Artisans", "Craftsmen"), ["MENUISIER", "FORGERON", "POTIER", "TAILLEUR", "COUTURIER", "BIJOUTIER", "TANNEUR", "TOURNEUR", "LUTHIER", "CUIR", "VERRIER", "ÉBÉNISTE", "ATELIER"], ["CARPENTER", "LOOM", "POTTER", "TAILOR", "SEAMSTRESS", "JEWELER", "SHOEMAKER", "WEAVER", "LUTHIER", "LOCKSMITH", "WORKSHOP", "LEATHER", "WOOD"], cross=10, cover=0.96, decoys=3),
        L(3, 10, 4, 0.71, 4, ("Chantier", "Construction"), ["MAÇON", "GRUE", "BULLDOZER", "BRIQUE", "CIMENT", "PELLETEUSE", "PLÂTRIER", "MARTEAU", "CHANTIER", "PLOMBIER", "COUVREUR", "TRUELLE", "PERCEUSE"], ["MASON", "CRANE", "BULLDOZER", "CEMENT", "EXCAVATOR", "PLASTERER", "HAMMER", "BRICKLAYER", "FOREMAN", "PLUMBER", "ROOFER", "TROWEL", "DRILL"], cross=10, cover=0.96, decoys=3),
        L(4, 11, 4, 0.6, 4, ("École", "School"), ["ENSEIGNANT", "PROFESSEUR", "ÉLÈVE", "CARTABLE", "TABLEAU", "CRAYON", "TROUSSE", "RÉCRÉATION", "CANTINE", "EXAMEN", "DIPLÔME", "UNIVERSITÉ", "BAC", "LEÇON"], ["TEACHER", "PROFESSOR", "STUDENT", "SCHOOLBAG", "BLACKBOARD", "PENCIL", "NOTEBOOK", "RECESS", "CANTEEN", "EXAM", "DIPLOMA", "CALCULATOR", "ERASER", "HOMEWORK"], cross=11, cover=0.96, decoys=3),
        L(5, 11, 4, 0.71, 4, ("Ferme", "Farm"), ["AGRICULTEUR", "TRACTEUR", "MOISSON", "TROUPEAU", "ÉTABLE", "GRANGE", "POULAILLER", "BERGER", "VACHE", "SEMENCE", "CHARRUE", "VIGNERON", "FOIN", "POTAGER"], ["AGRICULTURE", "TRACTOR", "HAY", "BARN", "STABLE", "HENHOUSE", "SHEPHERD", "SHEEP", "FIELD", "SEED", "PLOW", "VINEYARD", "SCARECROW", "LIVESTOCK"], cross=11, cover=0.96, decoys=4),
        L(6, 11, 4, 0.58, 5, ("Ville", "City life"), ["POMPIER", "POLICIER", "FACTEUR", "ÉBOUEUR", "CHAUFFEUR", "CONTRÔLEUR", "MAIRIE", "TRAMWAY", "TROTTOIR", "CARREFOUR", "BOULEVARD", "LAMPADAIRE", "POSTE", "AMBULANCE", "TAXI"], ["FIREFIGHTER", "POLICEMAN", "POSTMAN", "SANITATION", "DRIVER", "MAYOR", "TRAM", "SIDEWALK", "BOULEVARD", "STREETLAMP", "MAIL", "AMBULANCE", "CASHIER", "WAITER", "ROAD"], cross=12, cover=0.96, decoys=5),
        L(7, 11, 4, 0.68, 5, ("Secours", "Rescue"), ["SAUVETEUR", "SECOURS", "AMBULANCIER", "URGENCE", "BRANCARD", "HÉLICOPTÈRE", "ALARME", "SAUVETAGE", "INCENDIE", "TUYAU", "CASERNE", "AVALANCHE", "RADEAU", "GILET", "SIRÈNE"], ["PARAMEDIC", "STRETCHER", "HELICOPTER", "ALARM", "RESCUER", "FIREHOUSE", "HOSE", "SIREN", "SAFETY", "LIFEBOAT", "LIFEJACKET", "FLARE", "EVACUATION", "RESPONDER", "SHELTER"], cross=12, cover=0.96, decoys=5),
        L(8, 11, 4, 0.71, 5, ("Bureau", "Office"), ["SECRÉTAIRE", "COMPTABLE", "DIRECTEUR", "RÉUNION", "AGENDA", "CLASSEUR", "COURRIER", "DOSSIER", "CONTRAT", "ENTREPRISE", "AGRAFEUSE", "TROMBONE", "STYLO", "FACTURE", "FAX"], ["SECRETARY", "ACCOUNTANT", "MANAGER", "MEETING", "AGENDA", "BINDER", "STAPLER", "FOLDER", "CONTRACT", "ENTERPRISE", "PAPERCLIP", "INVOICE", "DESK", "FAX", "CONFERENCE"], cross=12, cover=0.96, decoys=6),
        L(9, 11, 4, 0.67, 5, ("Outils", "Tools"), ["TOURNEVIS", "ESCABEAU", "PINCE", "RABOT", "BOULON", "RONDELLE", "BURIN", "DÉCAPEUR", "ÉTABLI", "MÈTRE", "ÉQUERRE", "PONCEUSE", "SOUDURE", "ABRASIF", "PERFORATEUR", "MENUISERIE"], ["SCREWDRIVER", "SAW", "PLIERS", "PLANE", "BOLT", "NUT", "CHISEL", "NAIL", "WORKBENCH", "RULER", "SANDER", "WELDING", "VISE", "WRENCH", "TOOLBOX", "WHEELBARROW"], cross=13, cover=0.96, decoys=6),
        L(10, 12, 4, 1, 5, ("Tous les métiers", "Every career"), ["ENTREPRENEUR", "INGÉNIEUR", "PILOTE", "AVOCAT", "JUGE", "MAIRE", "CHEF", "TRADUCTEUR", "ASTRONAUTE", "COIFFEUR", "JARDINIER", "ÉLECTRICIEN", "MÉCANICIEN", "LIBRAIRE", "ARTISAN", "MÉTIER", "CARRIÈRE"], ["ENTREPRENEUR", "ENGINEER", "MAYOR", "LAWYER", "JUDGE", "PILOT", "CHEF", "TRANSLATOR", "ASTRONAUT", "HAIRDRESSER", "GARDENER", "ELECTRICIAN", "MECHANIC", "BOOKSELLER", "CAREER", "PROFESSION", "JOB"], cross=13, cover=0.95, decoys=10),
    ]),
]


def candidates(grid, axes, n, w, dirs):
    """Toutes les positions où `w` tient (cases vides ou lettres identiques, jamais deux mots sur le même axe)."""
    cands = []
    for d in dirs:
        dr, dc = DIRS[d]
        ax = frozenset((d, OPPOSITE[d]))
        for r in range(n):
            for c in range(n):
                er, ec = r + dr * (len(w) - 1), c + dc * (len(w) - 1)
                if not (0 <= er < n and 0 <= ec < n):
                    continue
                ov, ok = 0, True
                for t in range(len(w)):
                    y, x = r + dr * t, c + dc * t
                    g = grid[y][x]
                    if g is None:
                        continue
                    if g != w[t] or ax in axes[y][x]:
                        ok = False
                        break
                    ov += 1
                if ok:
                    cands.append((r, c, d, ov))
    return cands


def put(grid, axes, w, r, c, d):
    dr, dc = DIRS[d]
    ax = frozenset((d, OPPOSITE[d]))
    for t in range(len(w)):
        y, x = r + dr * t, c + dc * t
        grid[y][x] = w[t]
        axes[y][x].add(ax)


def cells_of(letters, r, c, d):
    dr, dc = DIRS[d]
    return frozenset((r + dr * t, c + dc * t) for t in range(len(letters)))


def one_decoy(rng, words, alpha):
    """Un leurre : début d'un mot cible (privé de sa fin) ou mot « presque juste » (dernières lettres changées).
    Il donne l'impression d'avoir trouvé un mot qui n'en est pas un. Longueur minimale : 3 lettres (4 si le mot en a 6+)."""
    pool = [w for w in words if len(w) >= 4]
    if not pool:
        return None
    base = rng.choice(pool)
    low = 4 if len(base) >= 6 else 3
    if rng.random() < 0.55:
        s = base[: rng.randint(min(low, len(base) - 1), len(base) - 1)]
    else:
        k = rng.choice([1, 2])
        s = base[: len(base) - k] + "".join(rng.choice(alpha) for _ in range(k))
    if len(s) < 3 or s in words or s == base:
        return None
    return s


def try_place(rng, n, words, dirs, min_cross, max_cover, decoy_count, alpha):
    grid = [[None] * n for _ in range(n)]
    axes = [[set() for _ in range(n)] for _ in range(n)]
    pos = [None] * len(words)
    cross = 0
    order = sorted(range(len(words)), key=lambda i: (-len(words[i]), i))
    for k, i in enumerate(order):
        w = words[i]
        cands = candidates(grid, axes, n, w, dirs)
        if not cands:
            return None
        # Placement « mots croisés » : on privilégie les positions qui croisent le plus de lettres déjà posées, ce qui
        # tasse les mots (et laisse de la place aux suivants) ; de temps en temps un placement libre garde de la variété.
        best = max(x[3] for x in cands)
        crossing = [x for x in cands if x[3] > 0]
        if k > 0 and best > 0 and (cross < min_cross or rng.random() < 0.8):
            top = [x for x in cands if x[3] >= max(best - rng.choice([0, 0, 1]), 1)]
            pool = top
        else:
            pool = crossing if (cross < min_cross and k > 0 and crossing) else cands
        r, c, d, ov = rng.choice(pool)
        put(grid, axes, w, r, c, d)
        pos[i] = (r, c, d)
        cross += ov
    word_cells = [cells_of(words[i], *pos[i]) for i in range(len(words))]
    decoys = []
    attempts = 0
    while len(decoys) < decoy_count and attempts < 120:
        attempts += 1
        s = one_decoy(rng, words, alpha)
        if s is None or any(s == d[0] for d in decoys):
            continue
        cands = [x for x in candidates(grid, axes, n, s, dirs)
                 if not any(cells_of(s, x[0], x[1], x[2]) <= wc for wc in word_cells)]
        if not cands:
            continue
        # Un leurre se cache de préférence là où il croise d'autres lettres (il se confond avec les vrais mots).
        crossing = [x for x in cands if x[3] > 0]
        r, c, d, _ = rng.choice(crossing if crossing and rng.random() < 0.7 else cands)
        put(grid, axes, s, r, c, d)
        decoys.append((s, r, c, d))
    if len(decoys) < decoy_count:
        return None
    distinct = sum(1 for row in grid for ch in row if ch is not None)
    if cross < min_cross or distinct > max_cover * n * n:
        return None
    return grid, pos, decoys


def fill_unique(rng, grid, letters, alpha, ambiguity, planted):
    """Remplit les cases libres puis, tant qu'un mot cible apparaît plusieurs fois, retire au hasard une lettre libre de
    chaque occurrence parasite. Renvoie les lignes, ou None si une occurrence parasite n'a aucune case libre."""
    n = len(grid)
    pool = "".join(letters)
    fixed = [[ch is not None for ch in row] for row in grid]
    cur = [[ch if ch is not None else (rng.choice(pool) if rng.random() < ambiguity else rng.choice(alpha)) for ch in row]
           for row in grid]
    for _ in range(900):
        rows = ["".join(r) for r in cur]
        clean = True
        for w, own in zip(letters, planted):
            found = occurrences(rows, w)
            if len(found) == 1 and own in found:
                continue
            clean = False
            extras = [o for o in found if o != own]
            if not extras or own not in found:
                return None
            for o in extras:
                free = [(y, x) for (y, x) in o if not fixed[y][x]]
                if not free:
                    return None
                y, x = rng.choice(free)
                cur[y][x] = rng.choice(pool) if rng.random() < ambiguity else rng.choice(alpha)
        if clean:
            return rows
    return None


def build_variant(chapter, spec, lang):
    displays = spec[lang]
    letters = [to_letters(w) for w in displays]
    rng = random.Random(f"mots-meles/v3/{chapter['index']}/{spec['number']}/{lang}")
    dirs = tier_directions(spec["tier"])
    for _ in range(MAX_PLACE_TRIES):
        placed = try_place(rng, spec["size"], letters, dirs, spec["cross"], spec["cover"], spec["decoys"], ALPHA[lang])
        if placed is None:
            continue
        base, pos, decoys = placed
        planted = [cells_of(letters[i], *pos[i]) for i in range(len(letters))]
        for _ in range(12):
            rows = fill_unique(rng, base, letters, ALPHA[lang], spec["amb"], planted)
            if rows is not None:
                variant = {
                    "grid": rows,
                    "words": [{"display": displays[i], "letters": letters[i], "row": pos[i][0],
                               "col": pos[i][1], "direction": pos[i][2]} for i in range(len(displays))],
                }
                if decoys:
                    variant["decoys"] = [{"letters": s, "row": r, "col": c, "direction": d} for s, r, c, d in decoys]
                return variant
    raise RuntimeError(f"Impossible de construire c{chapter['index']} l{spec['number']} {lang} : "
                       f"assouplir cover/cross/decoys ou changer les mots")


def build_chapter(ch):
    levels = []
    for spec in ch["levels"]:
        level = {
            "id": f"c{ch['index']}-l{spec['number']:02d}",
            "chapter": ch["index"],
            "number": spec["number"],
            "theme": {"fr": spec["theme"][0], "en": spec["theme"][1]},
            "visualStyle": style_for(ch["index"], spec["number"]),
            "gridSize": spec["size"],
            "difficulty": {"tier": spec["tier"], "ambiguity": spec["amb"], "score": 0},
            "hints": {"maxPerLevel": spec["hints"]},
            "variants": {lang: build_variant(ch, spec, lang) for lang in ("fr", "en")},
        }
        if spec["decoys"]:
            level["difficulty"]["decoys"] = spec["decoys"]
        level["difficulty"]["score"] = level_score(level)
        levels.append(level)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "id": ch["id"],
        "index": ch["index"],
        "paletteKey": ch["palette"],
        "theme": {"fr": ch["theme"][0], "en": ch["theme"][1]},
        "levels": [{k: v for k, v in lv.items() if k != "chapter"} for lv in levels],
    }, levels


def dump(obj):
    return json.dumps(obj, ensure_ascii=False, indent=1) + "\n"


def main():
    check = "--check" in sys.argv
    only = [a for a in sys.argv[1:] if a.startswith("--chapter=")]
    selected = {int(a.split("=")[1]) for a in only}
    outputs = {}
    all_chapters = []
    for ch in CHAPTERS:
        if selected and ch["index"] not in selected:
            continue
        data, levels = build_chapter(ch)
        outputs[f"{ch['id']}.json"] = dump(data)
        all_chapters.append({**data, "levels": levels})
        print(f"{ch['id']} ok", flush=True)
    outputs["index.json"] = dump({"schemaVersion": SCHEMA_VERSION, "chapters": [f"{c['id']}.json" for c in CHAPTERS]})
    issues = validate_chapters(all_chapters)
    if issues:
        for lid, code, msg in issues:
            print(f"ERREUR [{lid or 'catalogue'}] {code} : {msg}")
        sys.exit(1)
    if check:
        stale = [n for n, text in outputs.items() if not (OUT_DIR / n).exists() or (OUT_DIR / n).read_text(encoding="utf-8") != text]
        if stale:
            print("Fichiers obsolètes (relancer scripts/generate_levels.py) :", ", ".join(stale))
            sys.exit(1)
        print("OK : data/levels correspond exactement au générateur.")
        return
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, text in outputs.items():
        (OUT_DIR / name).write_text(text, encoding="utf-8")
    for c in all_chapters:
        print(c["id"], [(lv["number"], lv["gridSize"], lv["difficulty"]["score"]) for lv in c["levels"]])


if __name__ == "__main__":
    main()
