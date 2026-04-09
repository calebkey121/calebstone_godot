# Web Build

This project is already close to web-ready:

- Godot project version: `4.6`
- Renderer: `GL Compatibility`
- API endpoint: HTTPS remote origin in `scripts/autoload/NetworkManager.gd`
- Server CORS: enabled in `calebstone_server/app/__init__.py`

## What Was Added

- A tracked Web export preset in `export_presets.cfg`
- `.gitignore` updated so exported artifacts go to `build/` and the preset stays in repo

## Export Steps

1. Open the project in Godot `4.6`.
2. Install matching Web export templates if Godot prompts for them.
3. Open `Project -> Export`.
4. Select the existing `Web` preset.
5. Export to `build/web/index.html`.

## Runtime Notes

- The web build will talk to the existing remote API configured in `NetworkManager.gd`.
- Because requests come from a browser, the API must remain on HTTPS and keep CORS enabled.
- Do not test the exported HTML by double-clicking it from disk. Serve it over HTTP instead.

Example local test:

```bash
cd calebstone_godot/build/web
python3 -m http.server 8080
```

Then open:

```text
http://127.0.0.1:8080
```

## Known Unknowns

- This repo does not include a Godot binary in the workspace, so the export itself was not run here.
- If the canvas sizing or input feel is off in-browser, adjust the Web preset and project window settings after the first export test.
