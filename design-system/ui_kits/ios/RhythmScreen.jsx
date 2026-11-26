import React from 'react';
import { Card } from '../../components/core/Card.jsx';
import { dur } from './KitData.jsx';

const DAYS = [['Thu', 19], ['Fri', 20], ['Sat', 21], ['Sun', 22], ['Mon', 23], ['Tue', 24], ['Wed', 25]];
const HOURS = [[0, '12a'], [3, '3a'], [6, '6a'], [9, '9a'], [12, '12p'], [15, '3p'], [18, '6p'], [21, '9p']];
const PX = 16 / 60; // 16px per hour

function rnd(i) { const x = Math.sin(i * 99.13) * 43758.5453; return x - Math.floor(x); }
function pastDay(d) {
  const j = k => Math.round((rnd(d * 11 + k) - 0.5) * 36);
  const wake = 405 + j(1), n1 = 555 + j(2), n1e = n1 + 72 + j(3) / 2, n2 = 835 + j(4), n2e = n2 + 78 + j(5) / 2, bed = 1150 + j(6);
  return {
    sleep: [[0, wake], [n1, n1e], [n2, n2e], [bed, 1440]],
    feeds: [[wake + 15, 4, false], [n1e + 13, 2.5, true], [n2e + 10, 4, false], [bed - 30, 5, false]],
    meals: [480 + j(7), 720 + j(8) / 3, 1050 + j(9)],
    diapers: [wake + 20, n1e + 8, 740 + j(10), n2e + 5, 1085 + j(11)],
    nursing: [],
  };
}
function today(events, nap, now) {
  const sleep = events.filter(e => e.type === 'sleep').map(e => [Math.max(0, e.start), e.end]);
  if (nap) sleep.push([nap.since, now]);
  return {
    sleep: sleep,
    feeds: events.filter(e => e.type === 'feeding' && e.kind !== 'nursing').map(e => [e.t, e.oz || 0, !!e.breast]),
    nursing: events.filter(e => e.kind === 'nursing').map(e => [e.t, e.min || 0]),
    meals: events.filter(e => e.type === 'meal').map(e => e.t),
    diapers: events.filter(e => e.type === 'diaper').map(e => e.t),
  };
}

export function RhythmScreen({ now, events, nap }) {
  const [sel, setSel] = React.useState(6);
  const days = DAYS.map((_, i) => (i === 6 ? today(events, nap, now) : pastDay(i + 1)));
  const d = days[sel];
  const sleepMin = d.sleep.reduce((s, x) => s + (x[1] - x[0]), 0);
  const oz = Math.round(d.feeds.reduce((s, x) => s + x[1], 0) * 100) / 100;
  return (
    <div className="kit-view">
      <header className="kit-head">
        <div>
          <div className="bl-label">Nov 19 – 25</div>
          <h1 className="kit-title">Rhythm</h1>
        </div>
      </header>
      <div className="kit-scroll">
        <div className="rh-legend">
          <span><i className="rh-key rh-key--sleep"></i>Sleep</span>
          <span><i className="rh-key rh-key--formula"></i>Formula</span>
          <span><i className="rh-key rh-key--breast"></i>Breast milk</span>
          {days.some(x => x.nursing.length) ? <span><i className="rh-key rh-key--nurse"></i>Nursing</span> : null}
          <span><i className="rh-key rh-key--meal"></i>Meal</span>
          <span><i className="rh-key rh-key--diaper"></i>Diaper</span>
        </div>
        <div className="rh-chart">
          <span></span>
          {DAYS.map((day, i) => (
            <button key={i} type="button" className={'rh-day' + (sel === i ? ' is-selected' : '')} onClick={() => setSel(i)}>
              <span>{day[0][0]}</span><b>{day[1]}</b>
            </button>
          ))}
          <div className="rh-hours">{HOURS.map(h => <span key={h[0]} style={{ top: h[0] * 16 }}>{h[1]}</span>)}</div>
          {days.map((day, i) => (
            <button key={i} type="button" aria-label={DAYS[i][0]} className={'rh-col' + (sel === i ? ' is-selected' : '')} onClick={() => setSel(i)}>
              {day.sleep.map((s, k) => <span key={'s' + k} className="rh-sleep" style={{ top: s[0] * PX, height: Math.max(2, (s[1] - s[0]) * PX) }}></span>)}
              {day.feeds.map((x, k) => <span key={'f' + k} className={'rh-feed' + (x[2] ? ' is-breast' : '')} style={{ top: x[0] * PX }}></span>)}
              {day.nursing.map((x, k) => <span key={'n' + k} className="rh-nurse" style={{ top: x[0] * PX, height: Math.max(5, x[1] * PX) }}></span>)}
              {day.meals.map((m, k) => <span key={'m' + k} className="rh-meal" style={{ top: m * PX }}></span>)}
              {day.diapers.map((m, k) => <span key={'d' + k} className="rh-diaper" style={{ top: m * PX }}></span>)}
              {i === 6 ? <span className="rh-now" style={{ top: now * PX }}></span> : null}
            </button>
          ))}
        </div>
        <Card className="rh-card">
          <div className="rh-card__head"><span className="bl-label">{DAYS[sel][0]}, Nov {DAYS[sel][1]}</span>{sel === 6 ? <span className="bl-label">So far</span> : null}</div>
          <div className="rh-totals">
            <div><b>{dur(sleepMin)}</b><span>Sleep</span></div>
            <div><b>{oz} oz</b><span>{d.feeds.length} bottles{d.nursing.length ? ' · ' + d.nursing.length + ' nursing' : ''}</span></div>
            <div><b>{d.diapers.length}</b><span>Diapers</span></div>
            <div><b>{d.meals.length}</b><span>Meals</span></div>
          </div>
        </Card>
      </div>
    </div>
  );
}
