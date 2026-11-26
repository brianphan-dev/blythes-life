import React from 'react';
import { TabBar } from '../../components/navigation/TabBar.jsx';
import { Toast } from '../../components/navigation/Toast.jsx';
import { PhoneFrame } from './PhoneFrame.jsx';
import { TodayScreen } from './TodayScreen.jsx';
import { RhythmScreen } from './RhythmScreen.jsx';
import { SheetsScreen, ReviewScreen } from './ScanScreens.jsx';
import { SettingsScreen } from './SettingsScreen.jsx';
import { LogSheet } from './LogSheet.jsx';
import { BASE_NOW, INITIAL_EVENTS, clock, dur, range, nurseSecs } from './KitData.jsx';

export function BlythesLifeApp() {
  const t0 = React.useRef(Date.now());
  const [, tick] = React.useState(0);
  React.useEffect(() => {
    const id = setInterval(() => tick(n => n + 1), 1000);
    return () => clearInterval(id);
  }, []);
  const now = BASE_NOW + (Date.now() - t0.current) / 60000;

  const [tab, setTab] = React.useState('today');
  const [theme, setTheme] = React.useState('day');
  const [unit, setUnit] = React.useState('oz');
  const [events, setEvents] = React.useState(INITIAL_EVENTS);
  const [nap, setNap] = React.useState(null);
  const [nurse, setNurse] = React.useState(null); // { startedAt, left, right, active, since }
  const [sheet, setSheet] = React.useState({ type: 'feeding', open: false, edit: null });
  const [pending, setPending] = React.useState(true);
  const [review, setReview] = React.useState(false);
  const [toast, setToast] = React.useState({ open: false, message: '', undo: false });
  const undoRef = React.useRef(null);
  const timer = React.useRef(null);

  const hush = () => setToast(t => Object.assign({}, t, { open: false }));
  const say = (message, undo) => {
    undoRef.current = undo || null;
    setToast({ open: true, message: message, undo: !!undo });
    clearTimeout(timer.current);
    timer.current = setTimeout(hush, 4500);
  };
  const closeSheet = () => setSheet(s => Object.assign({}, s, { open: false }));
  const openSheet = type => { hush(); setSheet({ type: type, open: true, edit: null }); };
  const openEdit = e => { hush(); setSheet({ type: e.kind === 'nursing' ? 'nursing' : e.type, open: true, edit: e }); };
  const openReview = () => { hush(); setReview(true); };

  const add = (list, message) => {
    const stamped = list.map((e, i) => Object.assign({ id: 'n' + Date.now() + i, source: 'manual' }, e));
    const ids = stamped.map(e => e.id);
    setEvents(ev => ev.concat(stamped));
    say(message, () => setEvents(ev => ev.filter(e => ids.indexOf(e.id) < 0)));
  };
  const update = (id, patch, message) => {
    const prev = events.find(e => e.id === id);
    closeSheet();
    setEvents(ev => ev.map(e => (e.id === id ? Object.assign({}, e, patch) : e)));
    say(message, () => setEvents(ev => ev.map(e => (e.id === id ? prev : e))));
  };
  const remove = entry => {
    closeSheet();
    setEvents(ev => ev.filter(e => e.id !== entry.id));
    say(entry.title + ' deleted', () => setEvents(ev => ev.concat([entry])));
  };

  const toggleNap = () => {
    if (!nap) {
      setNap({ since: now });
      say('Nap timer started on every device', () => setNap(null));
      return;
    }
    const n = events.filter(e => e.nap).length + 1;
    add([{ type: 'sleep', nap: true, t: nap.since, start: nap.since, end: now, title: 'Nap ' + n, detail: range(nap.since, now) + ' · ' + dur(now - nap.since) }], 'Nap ' + n + ' saved');
    setNap(null);
  };

  // Tap a side to start; tap the running side to pause; tap the other side to switch.
  const nurseSide = side => {
    const ms = Date.now();
    if (!nurse) { setNurse({ startedAt: now, left: 0, right: 0, active: side, since: ms }); return; }
    const s = nurseSecs(nurse);
    setNurse(Object.assign({}, nurse, { left: s.left, right: s.right, active: nurse.active === side ? null : side, since: ms }));
  };
  const finishNurse = () => {
    const s = nurseSecs(nurse), m = x => Math.max(1, Math.round(x / 60));
    const both = s.left > 0 && s.right > 0, side = both ? 'Both' : s.left > 0 ? 'Left' : 'Right';
    const lm = m(s.left), rm = m(s.right);
    const total = both ? lm + rm : m(s.total);
    const detail = total + 'm · ' + (both ? 'Left ' + lm + 'm, Right ' + rm + 'm' : side + ' side');
    closeSheet();
    setNurse(null);
    add([{ type: 'feeding', kind: 'nursing', t: nurse.startedAt, min: total, title: 'Nursing', detail: detail, form: { minutes: String(total), side: side } }], 'Nursing logged · ' + total + 'm');
  };
  const discardNurse = () => {
    const s = nurseSecs(nurse);
    const paused = Object.assign({}, nurse, { left: s.left, right: s.right, active: null });
    closeSheet();
    setNurse(null);
    say('Nursing timer discarded', () => setNurse(paused));
  };

  const toggleTheme = () => setTheme(t => (t === 'night' ? 'day' : 'night'));
  const scan = () => (pending ? openReview() : say('The camera opens here in the app'));

  return (
    <PhoneFrame theme={theme}>
      {tab === 'today' ? <TodayScreen now={now} events={events} nap={nap} nurse={nurse} pending={pending} theme={theme} onToggleTheme={toggleTheme} onNap={toggleNap} onLog={openSheet} onEdit={openEdit} onReview={openReview} /> : null}
      {tab === 'rhythm' ? <RhythmScreen now={now} events={events} nap={nap} /> : null}
      {tab === 'sheets' ? <SheetsScreen pending={pending} onScan={scan} onReview={openReview} /> : null}
      {tab === 'settings' ? <SettingsScreen theme={theme} onToggleTheme={toggleTheme} unit={unit} onUnit={setUnit} onAction={m => say(m)} /> : null}
      <TabBar value={tab} onChange={setTab} items={[
        { id: 'today', label: 'Today', icon: 'sun' },
        { id: 'rhythm', label: 'Rhythm', icon: 'calendar-range' },
        { id: 'sheets', label: 'Sheets', icon: 'scan-text', badge: pending ? 1 : null },
        { id: 'settings', label: 'Settings', icon: 'settings' },
      ]} />
      <div className="kit-home"></div>
      {review ? <ReviewScreen onCancel={() => setReview(false)} onSave={list => { setReview(false); setPending(false); add(list, list.length + (list.length === 1 ? ' entry' : ' entries') + " saved from Grandma's sheet"); }} /> : null}
      <LogSheet type={sheet.type} open={sheet.open} edit={sheet.edit} now={now} unit={unit} nap={nap} nurse={nurse} napsDone={events.filter(e => e.nap).length}
        onClose={closeSheet} onSave={(list, message) => { closeSheet(); add(list, message); }} onUpdate={update} onDelete={remove}
        onNapStart={since => { closeSheet(); setNap({ since: since }); say('Nap start set to ' + clock(since)); }}
        onNurseSide={nurseSide} onNurseFinish={finishNurse} onNurseDiscard={discardNurse} />
      <Toast open={toast.open} message={toast.message} actionLabel={toast.undo ? 'Undo' : null} onAction={() => { if (undoRef.current) undoRef.current(); hush(); }} style={{ bottom: tab === 'today' ? 252 : 94 }} />
    </PhoneFrame>
  );
}
