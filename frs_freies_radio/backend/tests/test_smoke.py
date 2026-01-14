from datetime import datetime

from app import create_app


def test_health_endpoint():
    app = create_app(lambda: [])
    client = app.test_client()
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"ok": True}


def test_today_and_week_shape():
    today = datetime.now().date().strftime("%Y-%m-%d")
    items = [
        {
            "date": today,
            "start": "08:00",
            "end": "09:00",
            "show": "Test Show",
            "episode": "Episode",
            "teaser": None,
            "audioUrl": "https://www.freies-radio.de/systemfiles/mediathek/20250113-0800.mp3",
            "audioAvailable": False,
        }
    ]
    app = create_app(lambda: items)
    client = app.test_client()

    today_resp = client.get("/mediathek/today")
    assert today_resp.status_code == 200
    today_data = today_resp.get_json()
    assert isinstance(today_data, list)
    assert today_data[0]["date"] == today

    week_resp = client.get("/mediathek/week")
    assert week_resp.status_code == 200
    week_data = week_resp.get_json()
    assert isinstance(week_data, list)
    assert week_data[0]["date"] == today
    assert isinstance(week_data[0]["items"], list)
