# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [1.0.0] - 2026-04-27

### Added

#### Group Management
- Create, edit, and delete football groups (e.g. "Futebol de Quinta")
- Each group maintains its own independent roster, sessions, and statistics
- Groups persist locally across app restarts via `shared_preferences`

#### Sessions (Peladas)
- Create match sessions with a custom name, date picker, players-per-team count, and duration
- Sessions are sorted newest-first and display live/finished status with a visual indicator
- Edit or delete existing sessions at any time

#### Live Match Screen
- **Arrival Queue** — add players as they show up and drag to reorder the priority list
- **Random Team Draw** — auto-shuffle the arrival queue into two balanced teams
- **Live Scoreboard** — real-time score counter with a match timer and overtime detection
- **Goal & Assist Logging** — record goal scorers and assist providers with timestamps
- **Goal Scorers Panel** — live display of who scored for each team below the scoreboard
- **Own Goal support** — log own goals correctly attributed to the opposing team
- **Goalkeeper Rotation** — swap in a goalkeeper from the waiting list mid-match
- **Next Teams tab** — preview which players are queued for the next match
- Audio whistle sound effect on match start and when overtime is reached
- Full match state persistence (timer, score, teams, events) across screen changes

#### Player Management
- Full player roster per group with custom avatar icons and star ratings (1–5)
- Add, edit, and remove players from the group roster
- Player icons chosen from a built-in set of football player avatars

#### Player Detail & Advanced Analytics
- Individual player profile with all-time stats: Goals, Assists, G+A, Wins, Draws, Losses, Games
- Win/draw/loss ratio visualised as a colour bar
- Historical ranking position within the group
- **Advanced stats section:**
  - Hat-tricks (3+ goals in a single match)
  - Favourite assist partner (who they most set up)
  - Favourite assister (who most sets them up)
  - Most played with teammate
  - Most wins / most losses with a teammate
  - Biggest rival (most losses against)
  - Most dominated opponent (most wins against)
  - Most balanced rival (most draws against)
- Edit player name directly from the detail screen

#### Rankings
- Per-session ranking screen with sortable columns: G+A, Goals, Assists, Wins, Draws, Losses, Games
- Performance score ("Nota") calculated from match results and goal contributions
- Group-wide all-time leaderboard with month filter (view any specific month's standings)
- Medal icons (🥇🥈🥉) for the top 3 players
- Tap a player row to navigate directly to their detail screen

#### Data Sync & Backup
- **Cloud Sync** via Firebase Firestore — back up and restore all data across devices using a personal sync code
- **Export** — save the full local database as a structured JSON file
- **Import** — restore data from a previously exported JSON file via the file picker

#### App Infrastructure
- Dark-themed Material 3 UI with a consistent blue colour palette
- Firebase Core initialisation on app launch
- MIT License
