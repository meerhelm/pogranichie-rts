extends GutHookScript
## Runs once before the tests: points the player's settings and campaign progress at files of
## their own, so the tests start from the defaults (English, the Samogitia map) whatever the
## player last picked in the game on this computer, and never write over the player's files.

const SETTINGS := "user://test_settings.cfg"
const CAMPAIGN := "user://test_campaign_progress.cfg"


func run() -> void:
	for path: String in [SETTINGS, CAMPAIGN]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	GameSettings.path = SETTINGS
	CampaignProgress.path = CAMPAIGN
