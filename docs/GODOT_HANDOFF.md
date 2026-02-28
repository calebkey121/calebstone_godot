# Godot Handoff

## Purpose
This document gives a high-level map of the Godot client so a new contributor can quickly understand where game flow, UI, card visuals, and networking are implemented.

## Project layout
- `project.godot`
- `scenes/`
- `scripts/`
- `scripts/autoload/`
- `assets/`
- `card_data/`
- `decklists/`

### Key scene files
- `scenes/game.tscn`: Main in-game scene. Owns board nodes, hand nodes, HUD, and `HTTPRequest`.
- `scenes/card.tscn`: Reusable card visual + interaction prefab used for hand cards and board allies.
- `scenes/board.tscn`: Board surface + `Area2D` drop target shape for play-card drag/drop.

### Key script files
- `scripts/game.gd`: Main game controller for rendering state, wiring inputs, and submitting actions.
- `scripts/hand.gd`: Hand container logic (add/remove/sync cards, spacing/compression, card anchoring).
- `scripts/Card.gd`: Card behavior (hover tween, drag/click, face-down mode, UI label updates).
- `scripts/CardData.gd`: Data object mapped from server payload fields.

### Key autoloads
- `scripts/autoload/NetworkManager.gd`: API endpoints + request helpers (`new_game`, `load_game`, `submit_action`).
- `scripts/autoload/GameState.gd`: Client-side state cache from server responses.
- `scripts/autoload/CardManager.gd`: Card instancing, frame/art setup, drag tracking, drop detection.
- `scripts/autoload/Settings.gd`: Gameplay/UI tuning constants (timings, widths, padding, hover scale).
- `scripts/autoload/TextureManager.gd`: Texture preload registry for frames and art.
- `scripts/autoload/CardLibrary.gd`: Loads static card library API data for tooling/UI.
- `scripts/autoload/Tools.gd`: JSON loading helpers and utility lookups.

## How runtime flow works
1. `game.tscn` loads and `scripts/game.gd::_ready()` runs.
2. `game.gd` connects card/drag signals and calls `NetworkManager.load_game(...)`.
3. HTTP response is parsed and passed into `setup(...)`.
4. `GameState.update_from_response(...)` stores `current_player`, `opposing_player`, round, and game-over state.
5. `game.gd` rebuilds visuals:
- player hand via `Hand.sync_from_card_data(...)`
- both boards via `_rebuild_boards()` using `CardManager.create_card(...)`
- opponent hand via `Hand.sync_from_card_data(...)` then `card.set_face_down(true)`
- HUD labels via `_update_hud()`
6. Player interactions:
- Drag hand card to board drop area -> `_on_card_drag_ended(...)` -> submit `play_card` action.
- Click player board card and then enemy board card -> submit `attack` action.
- End Turn button -> submit `end_turn` action.
7. Action responses are parsed and scene is rebuilt from server-authoritative state.

## Interaction model summary
- Hand and board units currently share one prefab: `card.tscn` + `Card.gd`.
- Board mode is enabled through `card.setup_board(...)`:
- click enabled
- drag enabled (currently visual only for board cards)
- attack/select highlighting through border color
- Opponent hand uses the same card prefab in face-down mode.

## Data contract notes
- Play card action uses `card_instance_id`.
- Attack action uses `attacker_id` and `target_id`.
- `GameState` consumes `round` with fallback to legacy `current_round`.
- Current known backend behavior: `POST /api/action` may return pre-action `game_state`, while subsequent `GET /api/game_state` reflects updated state.

## Near-Term TODOs
- Add a smooth animation from card release point to final board slot when a hand card is played.
- Animate board cards repositioning smoothly when a card is added or removed from the board.
- Show remaining deck count in the in-game UI.
- Keep dragged cards on a consistent top visual layer until their return animation fully completes, to prevent release-time z-order mismatches (for example frame above another card while art is below it).

## Recently Completed
- Prevent illegal `play_card` actions client-side using `legal_actions`, and avoid temporary hand desync/visual corruption when legal plays resolve.

## Larger Roadmap Items
- Implement hero entities and integrate them into gameplay and HUD.
- Implement combat actions and attack resolution flow.
- Highlight only legal moves/actions based on server-provided state.
- Complete a broader UI overhaul for consistency, readability, and polish.
