# Freies Radio fuer Stuttgart (All-in-One)

Dieses Unterprojekt enthaelt:
- `backend/`: Python Proxy (Flask) mit Scraper fuer die Drupal Mediathek
- `flutter/`: Mobile UI (Flutter)
- `react/`: Web Preview Komponente (React)

## Backend starten

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
```

Healthcheck:
```bash
curl http://localhost:5000/health
```

Tests:
```bash
cd backend
source .venv/bin/activate
pytest
```

## Flutter App

```bash
cd flutter
flutter pub get
flutter run
```

API Base URL setzen (z.B. fuer Emulator/Device):
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

## React Preview

Die Komponente liegt in `react/src/PreviewApp.jsx`.

In einem bestehenden Vite/React Projekt:
```jsx
import PreviewApp from './PreviewApp.jsx';
root.render(<PreviewApp />);
```

API Base URL im React Projekt:
```
VITE_API_BASE=http://localhost:5000
```
