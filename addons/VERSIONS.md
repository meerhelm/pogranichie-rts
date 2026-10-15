# Vendored addons

Addons are committed to the repository so the project opens in the editor right after cloning.
Upgrade an addon only in a dedicated PR and update this table.

| Addon | Version | Source | Notes |
| --- | --- | --- | --- |
| GUT | 9.7.1 | https://github.com/bitwes/Gut/tree/v9.7.1 | `addons/gut` as-is. The 9.7.x line targets Godot 4.7. |
| LimboAI | 1.8.1 (GDExtension, API 4.6) | https://github.com/limbonaut/limboai/releases/tag/v1.8.1, asset `limboai+v1.8.1.gdextension-4.6.zip`, SHA-256 `0910411f8dbc0da8920f6c8bbbb6397c347cd9f2f193942468a702dfb11d5f0e` | Only desktop x86_64 (Windows, Linux) and macOS libraries are kept; `limboai.gdextension` lists just those. Demo project not included. |
| Dialogic | 2.0-alpha-20 | https://github.com/dialogic-godot/dialogic/tree/2.0-alpha-20 (commit e301e1b) | `addons/dialogic` as-is. Dialogic 2 has no stable release yet; alpha-20 is the latest tag. |
