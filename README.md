# TapTalk (Flutter)

Cross-platform offline AAC communication app converted from the XAMPP web prototype (`c:\xampp\htdocs\API`).

## Features

- Welcome splash, login, register (learner / parent / teacher), theme picker
- Learner home: categories, phrases, text-to-speech, voice input, favorites, history
- Settings: language (English / Filipino), speech speed, 10 color themes
- **Offline-first**: SQLite local database (no server required)
- Responsive layout: phone, tablet, and desktop (centered shell, wider phrase grids)

## Run

```bash
flutter pub get
flutter run
```

For Windows desktop:

```bash
flutter run -d windows
```

## First use

1. Open the app → **Sign up** as **Learner**
2. Pick a theme → explore the home screen
3. Data is stored on-device in `taptalk.db`

## Project structure

- `lib/core/` — spacing, themes, strings
- `lib/data/` — SQLite models and repository
- `lib/screens/` — UI screens matching the web app flow
- `lib/widgets/` — shared shell, header, nav, phrase cards

## Note

Parent/teacher accounts register locally but the full class management UI from the PHP admin is not included yet; learner flow is complete.
