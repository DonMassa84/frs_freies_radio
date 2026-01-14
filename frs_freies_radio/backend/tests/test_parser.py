from pathlib import Path

from mediathek import parse_mediathek


def test_parse_mediathek_fixture():
    fixture_path = Path(__file__).parent.parent / "fixtures" / "mediathek_sample.html"
    html = fixture_path.read_text(encoding="utf-8")
    items = parse_mediathek(html)

    assert len(items) == 2
    first = items[0]
    assert first["date"] == "2025-01-13"
    assert first["start"] == "08:00"
    assert first["end"] == "09:00"
    assert first["show"] == "Morgenmagazin"
    assert first["episode"] == "Folge 1"
    assert first["teaser"] == "Start in den Tag."
    assert first["audioUrl"].endswith("/systemfiles/mediathek/20250113-0800.mp3")
