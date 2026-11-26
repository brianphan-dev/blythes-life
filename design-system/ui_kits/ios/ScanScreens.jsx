import React from 'react';
import { Button } from '../../components/core/Button.jsx';
import { IconButton } from '../../components/core/IconButton.jsx';
import { Badge } from '../../components/core/Badge.jsx';
import { Card } from '../../components/core/Card.jsx';
import { ListRow } from '../../components/core/ListRow.jsx';
import { DraftCard } from '../../components/tracking/DraftCard.jsx';
import { DRAFTS } from './KitData.jsx';

// Stand-in for the scanned photo. The real app shows the camera image here.
const ROWS = [
  { k: 'nap', label: 'NAP 1', target: '9:15–10:45', hand: '9:15 – 10:32' },
  { k: 'd1', label: 'DIAPER', hand: '10:40  pee L  poop S' },
  { k: 'b1', label: 'BOTTLE', pills: ['BREAST MILK', '+ VIT D'], target: '2–4 oz', hand: '2½ oz  10:45' },
  { k: 'd2', label: 'DIAPER', hand: <span>11:<span className="rv-over">2<i>3</i></span>0  pee L</span> },
  { k: 'lunch', label: 'LUNCH', target: '12:00', hand: '12:00  most' },
  { k: 'd3', label: 'DIAPER', hand: '12:20  pee M' },
];

export function SheetsScreen({ pending, onScan, onReview }) {
  return (
    <div className="kit-view">
      <header className="kit-head">
        <div>
          <div className="bl-label">Grandma's paper logs</div>
          <h1 className="kit-title">Sheets</h1>
        </div>
      </header>
      <div className="kit-scroll">
        <Card>
          <p className="kit-lede">Photograph today's sheet. Nothing is saved until you confirm each entry.</p>
          <div className="kit-stack">
            <Button size="lg" block icon="scan-text" onClick={onScan}>Scan today's sheet</Button>
            <Button variant="secondary" block icon="image" onClick={onScan}>Import a photo</Button>
          </div>
        </Card>
        <div className="kit-section"><span className="bl-label">Recent</span></div>
        <Card flush>
          {pending
            ? <ListRow label="Today, 12:50 PM" detail="3 new · 3 already logged" trailing={<Badge tone="warn">Needs review</Badge>} chevron onClick={onReview} />
            : <ListRow label="Today, 12:50 PM" detail="Entries saved" trailing={<Badge tone="ok">Confirmed</Badge>} chevron />}
          <ListRow label="Today, 11:02 AM" detail="3 entries saved" trailing={<Badge tone="ok">Confirmed</Badge>} chevron />
          <ListRow label="Tue, Nov 24" detail="11 entries saved · 2 photos" trailing={<Badge tone="ok">Confirmed</Badge>} chevron />
          <ListRow label="Mon, Nov 23" detail="12 entries saved · 2 photos" trailing={<Badge tone="ok">Confirmed</Badge>} chevron />
        </Card>
      </div>
    </div>
  );
}

export function ReviewScreen({ onCancel, onSave }) {
  const [sel, setSel] = React.useState('s5');
  const [inc, setInc] = React.useState(() => {
    const m = {};
    DRAFTS.forEach(d => { m[d.id] = d.status === 'create' && !d.suggestion; });
    return m;
  });
  const [res, setRes] = React.useState({});
  const listRef = React.useRef(null);
  React.useEffect(() => {
    const box = listRef.current;
    const el = box && box.querySelector('.bl-draft.is-selected');
    if (el) box.scrollTop = Math.max(0, el.offsetTop - box.offsetTop - 44);
  }, []);
  const rank = d => (d.options ? 0 : d.status === 'skip_duplicate' ? 3 : d.suggestion ? 2 : 1);
  const ordered = DRAFTS.slice().sort((a, b) => rank(a) - rank(b) || a.t - b.t);
  const hot = (DRAFTS.find(d => d.id === sel) || {}).row;
  const chosen = DRAFTS.filter(d => inc[d.id]);
  const open = chosen.filter(d => d.options && !res[d.id]).length;
  const save = () => onSave(chosen.map(d => Object.assign({
    type: d.type, t: res[d.id] === '11:30 AM' ? 690 : d.t, title: d.title, detail: d.saved || d.detail, source: 'paper_scan',
  }, d.ev)));
  return (
    <div className="rv">
      <div className="rv-photo">
        <div className="rv-paper">
          <div className="rv-paper__head"><b>Blythe's Daily Log</b><span>Wed 11/25</span></div>
          {ROWS.map(r => (
            <div key={r.k} className={'rv-line' + (r.k === hot ? ' is-hot' : '')}>
              <span className="rv-line__label">{r.label}{(r.pills || []).map(p => <i key={p}>{p}</i>)}</span>
              <span className="rv-line__target">{r.target}</span>
              <span className="rv-line__hand">{r.hand}</span>
            </div>
          ))}
        </div>
        <div className="rv-bar">
          <IconButton icon="x" label="Cancel review" variant="outline" onClick={onCancel} />
          <Badge>Today, 12:50 PM</Badge>
        </div>
      </div>
      <div className="kit-scroll rv-list" ref={listRef}>
        <div className="kit-section"><span className="bl-label">{DRAFTS.length} entries found</span><span className="bl-label">{chosen.length} selected</span></div>
        <div className="kit-stack">
          {ordered.map(d => (
            <DraftCard key={d.id} type={d.type} time={res[d.id] || d.time} title={d.title} detail={d.detail} status={d.status} suggestion={d.suggestion}
              included={inc[d.id]} onToggle={v => setInc(Object.assign({}, inc, { [d.id]: v }))}
              selected={sel === d.id} onSelect={() => setSel(d.id)}
              ambiguity={d.options && !res[d.id] ? d.ambiguity : null} options={d.options} onResolve={o => setRes(Object.assign({}, res, { [d.id]: o }))} />
          ))}
        </div>
      </div>
      <div className="rv-foot">
        <Button size="lg" block disabled={!chosen.length || open > 0} onClick={save}>
          {open ? open + (open === 1 ? ' entry needs' : ' entries need') + ' a look' : 'Save ' + chosen.length + (chosen.length === 1 ? ' entry' : ' entries')}
        </Button>
      </div>
    </div>
  );
}
