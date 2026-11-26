import React from 'react';
import { Icon } from '../../components/core/Icon.jsx';
import { IconButton } from '../../components/core/IconButton.jsx';
import { Card } from '../../components/core/Card.jsx';
import { NapCard } from '../../components/tracking/NapCard.jsx';
import { GlanceStat } from '../../components/tracking/GlanceStat.jsx';
import { EventRow } from '../../components/tracking/EventRow.jsx';
import { EventIcon } from '../../components/tracking/EventIcon.jsx';
import { QuickTile } from '../../components/tracking/QuickTile.jsx';
import { SCHEDULE, clock, dur, nurseSecs, mmss } from './KitData.jsx';

const TILES = [['feeding', 'Bottle'], ['nursing', 'Nursing'], ['pump', 'Pump'], ['diaper', 'Diaper'], ['meal', 'Meal'], ['bath', 'Bath'], ['medicine', 'Meds'], ['note', 'Note']];

export function TodayScreen({ now, events, nap, nurse, pending, theme, onToggleTheme, onNap, onLog, onEdit, onReview }) {
  const sorted = events.slice().sort((a, b) => b.t - a.t);
  const last = type => sorted.find(e => e.type === type);
  const napsDone = events.filter(e => e.nap).length;
  const ends = events.filter(e => e.type === 'sleep').map(e => e.end);
  const wakeAt = ends.length ? Math.max.apply(null, ends) : null;
  let hero;
  if (nap) {
    const el = now - nap.since, left = SCHEDULE.napCap - el;
    hero = {
      state: 'asleep', label: 'Nap ' + (napsDone + 1) + ' · since ' + clock(nap.since), elapsed: dur(el), progress: el / SCHEDULE.napCap, over: left < 0, actionLabel: 'Wake up',
      caption: <span>Nap cap <b>{clock(nap.since + SCHEDULE.napCap)}</b> · {left < 0 ? dur(-left) + ' over' : dur(left) + ' left'}</span>,
    };
  } else if (wakeAt == null) {
    hero = { state: 'awake', label: 'Awake', elapsed: '—', progress: 0, actionLabel: 'Start nap', caption: 'No sleep logged yet today' };
  } else {
    const isNap = napsDone < SCHEDULE.windows.length;
    const target = isNap ? SCHEDULE.windows[napsDone] : SCHEDULE.bedtime;
    const name = isNap ? 'Nap ' + (napsDone + 1) : 'Bedtime';
    const el = now - wakeAt, left = target - el;
    hero = {
      state: 'awake', label: 'Awake · since ' + clock(wakeAt), elapsed: dur(el), progress: el / target, over: left < 0, actionLabel: isNap ? 'Start nap' : 'Start night sleep',
      caption: <span>{name} sweet spot <b>{clock(wakeAt + target)}</b> · {left < 0 ? dur(-left) + ' ago' : 'in ' + dur(left)}</span>,
    };
  }
  const feed = last('feeding'), diaper = last('diaper');
  const nursed = !!feed && feed.kind === 'nursing';
  return (
    <div className="kit-view">
      <header className="kit-head">
        <div>
          <div className="bl-label">Wednesday, Nov 25</div>
          <h1 className="kit-title">Blythe <span>8 months</span></h1>
        </div>
        <IconButton icon={theme === 'night' ? 'sun' : 'moon'} variant="outline" label="Toggle night mode" onClick={onToggleTheme} />
      </header>
      <div className="kit-scroll">
        <NapCard {...hero} onAction={onNap} secondaryLabel={nap ? 'Change start time' : 'Add a past sleep'} onSecondary={() => onLog('sleep')} />
        {nurse ? (
          <Card tone="accent" onClick={() => onLog('nursing')} className="kit-banner">
            <EventIcon type="nursing" />
            <span className="kit-banner__text"><b>Nursing · {mmss(nurseSecs(nurse).total)}</b><span>{nurse.active ? (nurse.active === 'left' ? 'Left' : 'Right') + ' side running' : 'Paused'} · tap to switch or finish</span></span>
            <Icon name="chevron-right" size={18} />
          </Card>
        ) : null}
        <div className="kit-glance">
          <GlanceStat type={nursed ? 'nursing' : 'feeding'} label="Last feed" value={feed ? dur(now - feed.t) : '—'} sub={feed ? (nursed ? 'Nursed ' : '') + feed.detail : 'None today'} onClick={() => onLog(nursed ? 'nursing' : 'feeding')} />
          <GlanceStat type="diaper" label="Last diaper" value={diaper ? dur(now - diaper.t) : '—'} sub={diaper ? diaper.detail : 'None today'} onClick={() => onLog('diaper')} />
        </div>
        {pending ? (
          <Card tone="accent" onClick={onReview} className="kit-banner">
            <Icon name="scan-text" size={22} />
            <span className="kit-banner__text"><b>Grandma's sheet, 12:50 PM</b><span>3 new entries to review</span></span>
            <Icon name="chevron-right" size={18} />
          </Card>
        ) : null}
        <div className="kit-section"><span className="bl-label">Today</span><span className="bl-label">{events.length} entries · tap to edit</span></div>
        <div className="kit-timeline">
          {sorted.map(e => <EventRow key={e.id} type={e.kind || e.type} time={clock(e.t)} title={e.title} detail={e.detail} source={e.source} onClick={() => onEdit(e)} />)}
        </div>
      </div>
      <div className="kit-dock">
        {TILES.map(t => <QuickTile key={t[0]} size="sm" type={t[0]} label={t[1]} onClick={() => onLog(t[0])} />)}
      </div>
    </div>
  );
}
