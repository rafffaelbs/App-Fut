<h1 align="center">⚽ Pelada Manager (App-Fut)</h1>

<p align="center">
  The ultimate Flutter app for managing your <em>pelada</em> (casual football match) groups. Draft teams, log goals, calculate automatic player ratings, and track everything in a comprehensive statistics dashboard!
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-Firestore-FFCA28?logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white" />
</p>

---

## 📸 Screenshots

| Home | Sessions | Live Match |
|:----:|:--------:|:----------:|
| ![Home](screenshots/home.png) | ![Sessions](screenshots/sessions.png) | ![Match](screenshots/match.png) |

| Statistics Dashboard | Player Detail | Sync |
|:--------:|:-------------:|:----:|
| *(Insert image here)* | ![Player](screenshots/player_detail.png) | ![Sync](screenshots/sync.png) |

---

## 📱 Core Features

### 🏘️ Group & Season Management
- **Multiple Groups:** Create independent football groups (e.g., "Thursday Football", "Work Match").
- **Season Management (Admin):** Define date intervals (e.g., "Season 2026.1") protected by a password to organize your match history.
- **Roster Management:** Control the player roster, add custom avatars, and configure technical levels (1-5 stars) for automatic team drafting.

### ⚔️ Live Match & Team Draft
- **Arrival Queue:** Add players in the order they arrive at the pitch.
- **Balanced Draft:** The app instantly shuffles players into two balanced teams based on their star ratings.
- **Live Scoreboard:** Real-time score tracker with a built-in match timer.
- **In-game Events:** Log Goals, Assists, Own Goals, Yellow Cards, and Red Cards as they happen.
- **Goalkeeper Rotation:** Easily swap goalkeepers from the waiting list mid-match.

### 📊 Statistics Dashboard
- **Dynamic Filters:** Filter the dashboard by **Current Month**, specific **Season**, or **All-Time** history.
- **The Podium (Top 3):** Highlight cards featuring the top 3 players with Gold, Silver, and Bronze borders for the following categories:
  - 🥇 **Golden Balls:** Highest average ratings.
  - ⚽ **Offensive Contributions:** Most Goals + Assists (G+A).
  - 🥅 **Top Scorers:** Most Goals.
  - 👟 **Playmakers:** Most Assists.
- **Expanded Rankings:** Tap on any Podium card to view the full, pre-sorted leaderboard for that specific metric.
- **Pelada Evolution:** A line chart showing the variation of the group's overall technical quality over time.

### 👤 Player Profile & Trophy Room
- **Individual Evolution:** Interactive charts showing the player's performance trend over time.
- **Trophy Room:** 
  - *Automatic Badges:* The app automatically awards medals based on match history (e.g., "King of Wins", "Playmaker").
  - *Manual Badges:* Group admins can award custom, funny, or honorary badges to players.

### 📤 Cloud Sync & Backup
- **Cloud Sync:** Sync your data across multiple devices using Firebase Firestore with a personal group access code.
- **Export / Import:** Take full local backups of your database via JSON files.

---

## 🧠 Rating System Algorithm

App-Fut stands out with its **Dynamic Rating System**. Every player receives an automatic rating at the end of each match based on the match result and their individual performance. The single source of truth for this logic is located in `lib/utils/rating_calculator.dart`.

**How is the rating calculated?**
1. **Base Rating:** Every player starts the match with a base rating of `7.0`.
2. **Result Impact:** Winning the match adds `+1.5`. Losing subtracts `-1.5`. Draws have no impact.
3. **Win Streak:** Winning consecutive matches on the same day grants bonuses: `+0.5` (2 wins) and `+1.0` (3+ wins).
4. **Offensive Impact:** Each Goal is worth `+1.5` and each Assist `+1.0`.
5. **Defensive Impact:** Every goal conceded by the team penalizes the player's rating by `-0.3`.
6. **Disciplinary & Errors:** Yellow Card (`-1.0`), Red Card (`-2.0`), Own Goal (`-1.0`).
7. **Dynamic Bonuses (Highlights):**
   - **Hat Trick:** `+1.0` bonus for scoring 3 or more goals in a single match.
   - **Playmaker:** `+1.0` bonus for providing 3 or more assists in a single match.
   - **Offensive Team:** `+0.5` bonus if the player's team scores at least 1 goal in the match.

> The application aggregates these ratings to generate a weighted Average Rating displayed on the Statistics Dashboard and the Player Profile.

---

## 🛠️ Architecture & Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Material 3, Dark Theme) |
| Language | Dart 3 |
| Local Storage | `shared_preferences` |
| Cloud Sync | Firebase Firestore (`cloud_firestore`) |
| Charts | `fl_chart` |
| Audio | `audioplayers` |
| State Management | `StatefulWidget` & Callbacks |

## 📁 Folder Structure

```text
lib/
├── constants/
│   └── app_colors.dart             # Centralized color palette
├── screens/
│   ├── group_dashboard_screen.dart # Main hub with bottom navigation tabs
│   ├── group_ranking_screen.dart   # Statistics Dashboard / Podiums
│   ├── match_screen.dart           # Live Match scoreboard
│   ├── player_detail.dart          # Individual stats & charts
│   ├── manage_seasons_screen.dart  # Admin Panel: Season creation
│   ├── manage_badges_screen.dart   # Admin Panel: Custom badge creation
│   └── ...
├── utils/
│   ├── rating_calculator.dart      # The brain of the Rating System
│   ├── stats_calculator.dart       # JSON history parsing & aggregation
│   └── constants.dart              # Avatars and boundaries
└── widgets/
    └── shared/                     # Reusable UI components
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.10
- Android SDK / Android device or emulator
- A Firebase project with Firestore enabled (for cloud sync)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/rafffaelbs/App-Fut.git
cd App-Fut

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run
```

> **Note:** Cloud Sync requires a valid `google-services.json` file placed in `android/app/`. See [Firebase setup](https://firebase.google.com/docs/flutter/setup) for instructions.

### Build Release APK

```bash
flutter build apk --release
```
The generated APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'feat: add my feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Open a Pull Request

## 📄 License

This project is open source. See the [LICENSE](LICENSE) file for details.
