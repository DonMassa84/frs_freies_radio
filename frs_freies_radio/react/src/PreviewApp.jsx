import { useEffect, useMemo, useState } from 'react';

const ACCENT = '#FF6600';
const API_BASE = import.meta.env?.VITE_API_BASE || 'http://localhost:5000';

const tabs = [
  { id: 'live', label: 'Live' },
  { id: 'today', label: 'Heute' },
  { id: 'week', label: 'Mediathek' },
  { id: 'more', label: 'Mehr' },
];

export default function PreviewApp() {
  const [active, setActive] = useState('live');
  const [today, setToday] = useState([]);
  const [week, setWeek] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (active === 'today') {
      loadToday();
    }
    if (active === 'week') {
      loadWeek();
    }
  }, [active]);

  const header = useMemo(
    () => (
      <header style={styles.header}>
        <div>
          <div style={styles.title}>Freies Radio fuer Stuttgart</div>
          <div style={styles.subtitle}>Live-Stream · Programm · Mediathek</div>
        </div>
        <div style={styles.pill}>Live-Sender</div>
      </header>
    ),
    []
  );

  async function loadToday() {
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${API_BASE}/mediathek/today`);
      if (!res.ok) throw new Error('Request failed');
      setToday(await res.json());
    } catch (err) {
      setError('Konnte Daten nicht laden.');
    } finally {
      setLoading(false);
    }
  }

  async function loadWeek() {
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${API_BASE}/mediathek/week`);
      if (!res.ok) throw new Error('Request failed');
      setWeek(await res.json());
    } catch (err) {
      setError('Konnte Daten nicht laden.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={styles.page}>
      {header}
      <main style={styles.content}>
        {active === 'live' && (
          <section style={styles.liveCard}>
            <div style={styles.icon}>🎧</div>
            <div style={styles.liveTitle}>Jetzt live hoeren</div>
            <div style={styles.liveStatus}>Bereit zum Abspielen</div>
            <button style={styles.primary}>Play</button>
          </section>
        )}

        {active === 'today' && (
          <section>
            <h3 style={styles.sectionTitle}>Heute</h3>
            {loading && <div style={styles.loading}>Laedt...</div>}
            {error && <div style={styles.error}>{error}</div>}
            {today.map((item) => (
              <div key={`${item.date}-${item.start}`} style={styles.card}>
                <div style={styles.time}>{item.start} - {item.end}</div>
                <div style={styles.cardTitle}>{item.show}</div>
                <div style={styles.cardSubtitle}>{item.episode}</div>
              </div>
            ))}
          </section>
        )}

        {active === 'week' && (
          <section>
            <h3 style={styles.sectionTitle}>Letzte 7 Tage</h3>
            {loading && <div style={styles.loading}>Laedt...</div>}
            {error && <div style={styles.error}>{error}</div>}
            {week.map((day) => (
              <div key={day.date} style={{ marginBottom: 16 }}>
                <div style={styles.dayLabel}>{day.date}</div>
                {day.items.map((item) => (
                  <div key={`${day.date}-${item.start}`} style={styles.card}>
                    <div style={styles.time}>{item.start} - {item.end}</div>
                    <div style={styles.cardTitle}>{item.show}</div>
                    <div style={styles.cardSubtitle}>{item.episode}</div>
                  </div>
                ))}
              </div>
            ))}
          </section>
        )}

        {active === 'more' && (
          <section>
            <h3 style={styles.sectionTitle}>Mehr</h3>
            <button style={styles.secondary}>Website oeffnen</button>
            <button style={styles.secondary}>Impressum</button>
            <button style={styles.secondary}>Datenschutz</button>
          </section>
        )}
      </main>

      <nav style={styles.nav}>
        {tabs.map((tab) => (
          <button
            key={tab.id}
            onClick={() => setActive(tab.id)}
            style={{
              ...styles.navItem,
              color: active === tab.id ? ACCENT : '#A7B0BD',
            }}
          >
            {tab.label}
          </button>
        ))}
      </nav>
    </div>
  );
}

const styles = {
  page: {
    minHeight: '100vh',
    background: '#0F1113',
    color: '#F6F7F9',
    fontFamily: 'Sora, system-ui, sans-serif',
    padding: '20px 20px 80px',
    boxSizing: 'border-box',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 18,
  },
  title: { fontSize: 20, fontWeight: 700 },
  subtitle: { fontSize: 12, color: '#A7B0BD' },
  pill: {
    padding: '6px 12px',
    borderRadius: 999,
    background: 'rgba(255,255,255,0.06)',
    border: '1px solid rgba(255,255,255,0.12)',
    fontSize: 11,
    color: '#A7B0BD',
  },
  content: { display: 'flex', flexDirection: 'column', gap: 12 },
  liveCard: {
    background: 'linear-gradient(135deg, rgba(255,102,0,0.95), rgba(199,83,35,0.95))',
    borderRadius: 16,
    padding: 20,
    textAlign: 'center',
    boxShadow: '0 16px 32px rgba(0,0,0,0.3)',
  },
  icon: { fontSize: 40, marginBottom: 6 },
  liveTitle: { fontSize: 16, fontWeight: 700 },
  liveStatus: { fontSize: 12, opacity: 0.9, margin: '6px 0 10px' },
  primary: {
    background: '#0F1113',
    color: '#FFFFFF',
    border: 'none',
    padding: '10px 16px',
    borderRadius: 12,
    cursor: 'pointer',
  },
  sectionTitle: {
    textTransform: 'uppercase',
    letterSpacing: 1,
    fontSize: 12,
    color: '#A7B0BD',
  },
  card: {
    background: '#1A1E24',
    borderRadius: 12,
    padding: 14,
    border: '1px solid rgba(255,255,255,0.06)',
    marginTop: 10,
  },
  time: { fontSize: 12, color: ACCENT, fontWeight: 700 },
  cardTitle: { fontSize: 15, fontWeight: 600, marginTop: 4 },
  cardSubtitle: { fontSize: 12, color: '#A7B0BD', marginTop: 4 },
  dayLabel: { fontSize: 12, color: '#F6F7F9', marginTop: 8 },
  loading: { color: '#A7B0BD' },
  error: { color: '#FF9A8B' },
  secondary: {
    display: 'block',
    width: '100%',
    marginTop: 10,
    padding: '10px 14px',
    background: '#1A1E24',
    color: '#F6F7F9',
    border: '1px solid rgba(255,255,255,0.06)',
    borderRadius: 12,
    textAlign: 'left',
  },
  nav: {
    position: 'fixed',
    left: 0,
    right: 0,
    bottom: 0,
    display: 'flex',
    justifyContent: 'space-around',
    padding: '10px 0',
    background: 'rgba(15,17,19,0.95)',
    borderTop: '1px solid rgba(255,255,255,0.08)',
  },
  navItem: {
    background: 'transparent',
    border: 'none',
    fontSize: 12,
    cursor: 'pointer',
  },
};
