extends Node

var textures = {}

func _ready():
	preload_textures()

func preload_textures():
	textures["card_frame"] = preload("res://assets/card_frames/card_frame.png")
	textures["card_frame_1"] = preload("res://assets/card_frames/card_frame_1.png")
	textures["card_frame_5"] = preload("res://assets/card_frames/card_frame_5.png")
	textures["card_frame_10"] = preload("res://assets/card_frames/card_frame_10.png")
	textures["card_frame_11"] = preload("res://assets/card_frames/card_frame_11.png")
	textures["card_frame_12"] = preload("res://assets/card_frames/card_frame_12.png")
	textures["card_frame_cf1"] = preload("res://assets/card_frames/cf1.png")
	textures["Wyndhaven Enclave"] = preload("res://assets/card_art/WyndhavenEnclave.png")
	textures["Ruthless Baroness"] = preload("res://assets/card_art/RuthlessBaroness.png")
	textures["Underground Kingpin"] = preload("res://assets/card_art/UndergroundKingpin.png")
	textures["Crown's Secretkeeper"] = preload("res://assets/card_art/CrownsSecretkeeper.png")
	textures["Forgebound Smith"] = preload("res://assets/card_art/ForgeboundSmith.png")
	textures["Guild Enforcer"] = preload("res://assets/card_art/GuildEnforcer.png")
	textures["Plague Doctor"] = preload("res://assets/card_art/PlagueDoctor.png")
	textures["Bandit Outlaw"] = preload("res://assets/card_art/BanditOutlaw.png")
	textures["Banshee's Wail"] = preload("res://assets/card_art/BansheesWail.png")
	textures["Bone Collector"] = preload("res://assets/card_art/BoneCollector.png")
	textures["Bow Marshal"] = preload("res://assets/card_art/BowMarshal.png")
	textures["Castle Ward"] = preload("res://assets/card_art/CastleWard.png")
	textures["Court Alchemist"] = preload("res://assets/card_art/CourtAlchemist.png")
	textures["Crypt Creeper"] = preload("res://assets/card_art/CryptCreeper.png")
	textures["Cursed Squire"] = preload("res://assets/card_art/CursedSquire.png")
	textures["Dire Wolf"] = preload("res://assets/card_art/DireWolf.png")
	textures["Ghoul Vanguard"] = preload("res://assets/card_art/GhoulVanguard.png")
	textures["Ghostly Raider"] = preload("res://assets/card_art/GhostlyRaider.png")
	textures["Graveyard Sentinel"] = preload("res://assets/card_art/GraveyardSentinel.png")
	textures["Highland Scout"] = preload("res://assets/card_art/HighlandScout.png")
	textures["Highwayman's Ambush"] = preload("res://assets/card_art/HighwaymansAmbush.png")
	textures["Jousting Champion"] = preload("res://assets/card_art/JoustingChampion.png")
	textures["Mercenary Captain"] = preload("res://assets/card_art/MercenaryCaptain.png")
	textures["Mournful Spirit"] = preload("res://assets/card_art/MournfulSpirit.png")
	textures["Necromancer of the Forgotten Depths"] = preload("res://assets/card_art/NecromancerOfTheForgottenDepths.png")
	textures["Necromancer of the Vale"] = preload("res://assets/card_art/NecromancerOfTheVale.png")
	textures["Necropolis Guard"] = preload("res://assets/card_art/NecropolisGuard.png")
	textures["Phantom Steed"] = preload("res://assets/card_art/PhantomSteed.png")
	textures["Revenant Archer"] = preload("res://assets/card_art/RevenantArcher.png")
	textures["Royal Falconer"] = preload("res://assets/card_art/RoyalFalconer.png")
	textures["Shadow of the Past"] = preload("res://assets/card_art/ShadowOfThePast.png")
	textures["Siege Engineer"] = preload("res://assets/card_art/SiegeEngineer.png")
	textures["Skeletal Knight"] = preload("res://assets/card_art/SkeletalKnight.png")
	textures["Spectral Ferryman"] = preload("res://assets/card_art/SpectralFerryman.png")
	textures["Tomb Warden"] = preload("res://assets/card_art/TombWarden.png")
	textures["Undead Creature"] = preload("res://assets/card_art/UndeadCreature.png")
	textures["Village Blacksmith"] = preload("res://assets/card_art/VillageBlacksmith.png")
	textures["Icelord of Despair"] = preload("res://assets/card_art/IcelordOfDespair.webp")
	textures["Wandering Minstrel"] = preload("res://assets/card_art/WanderingMinstrel.png")
	textures["Wandering Ronin"] = preload("res://assets/card_art/WanderingRonin.png")
	textures["Auctor Noctis"] = preload("res://assets/card_art/AuctorNoctis.png")
	textures["Ebon Mortem"] = preload("res://assets/card_art/EbonMortem.png")
	textures["Forest Guardian"] = preload("res://assets/card_art/ForestGuardian.png")
	textures["Undead Creatures"] = preload("res://assets/card_art/UndeadCreatures.png")

	# Add more textures as needed
	
func get_texture(tex_name):
	if textures.has(tex_name):
		return textures[tex_name]
	else:
		print("Texture not found: ", tex_name)
		return null
