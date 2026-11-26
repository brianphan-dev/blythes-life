import React from 'react';
import { Button } from '../../components/core/Button.jsx';
import { Badge } from '../../components/core/Badge.jsx';
import { Chip } from '../../components/core/Chip.jsx';
import { SegmentedControl } from '../../components/forms/SegmentedControl.jsx';
import { Checkbox } from '../../components/forms/Checkbox.jsx';
import { TextField } from '../../components/forms/TextField.jsx';
import { AmountField } from '../../components/forms/AmountField.jsx';
import { TimeField } from '../../components/forms/TimeField.jsx';
import { Sheet } from '../../components/navigation/Sheet.jsx';
import { EventIcon } from '../../components/tracking/EventIcon.jsx';
import { NursingTimer } from '../../components/tracking/NursingTimer.jsx';
import { clock, dur, range, toHM, fromHM, nurseSecs } from './KitData.jsx';

const TITLES = { sleep: 'Sleep', feeding: 'Bottle', nursing: 'Nursing', pump: 'Pump', diaper: 'Diaper', meal: 'Meal', bath: 'Bath', medicine: 'Meds & care', note: 'Note' };
const PRESETS = { oz: ['2', '2.5', '3', '3.25', '4', '5'], mL: ['60', '75', '90', '100', '120', '150'] };
const PUMP_PRESETS = { oz: ['2', '3', '4', '5', '6', '8'], mL: ['60', '90', '120', '150', '180', '240'] };
const NURSE_PRESETS = ['5', '10', '15', '20', '25', '30'];
// name -> [dose, unit, category]; null dose = topical, no dose asked.
const MEDS = { 'Vitamin D': ['1', 'drops', 'supplement'], 'Infant Tylenol': ['2.5', 'mL', 'medicine'], 'Butt cream': [null, null, 'topical'], 'Saline drops': ['2', 'drops', 'medicine'], 'Gas drops': ['0.3', 'mL', 'medicine'], 'Custom': ['', 'mL', 'medicine'] };
const AGO = [[0, 'Now'], [5, '5m ago'], [15, '15m ago']];
const DEFAULTS = { ago: 0, at: null, amount: '3.25', unit: 'oz', substance: 'Formula', vitd: false, nurseMode: 'Timer', minutes: '10', side: 'Left', pumpSide: 'Both', kind: 'Nap', start: 0, end: 0, pee: 'M', poop: 'None', rash: false, slot: 'Lunch', ate: '', portion: 'Most', hair: 'No', bathNote: '', med: 'Vitamin D', dose: '1', doseUnit: 'drops', note: '' };

function slotFor(now) { return now < 630 ? 'Breakfast' : now < 900 ? 'Lunch' : now < 1020 ? 'Snack' : 'Dinner'; }
function convert(amount, unit) {
  const n = parseFloat(amount);
  if (!n) return '';
  return unit === 'mL' ? String(Math.round(n * 29.57 / 5) * 5) : String(Math.round(n / 29.57 * 4) / 4);
}
function sides(s) { return s === 'Both' ? 'Both sides' : s + ' side'; }
function unitText(dose, u) { return u === 'drops' && parseFloat(dose) === 1 ? 'drop' : u; }
function Field({ label, children }) {
  return <div className="kit-field"><span className="bl-label">{label}</span>{children}</div>;
}

export function LogSheet({ type = 'feeding', open, now, unit = 'oz', nap, napsDone = 0, edit, nurse, onClose, onSave, onUpdate, onDelete, onNapStart, onNurseSide, onNurseFinish, onNurseDiscard }) {
  const [f, setF] = React.useState(DEFAULTS);
  const set = patch => setF(s => Object.assign({}, s, patch));
  React.useEffect(() => {
    if (!open) return;
    const n = Math.round(now), ml = unit === 'mL';
    const base = Object.assign({}, DEFAULTS, {
      unit: unit, amount: type === 'pump' ? (ml ? '120' : '4') : (ml ? '95' : '3.25'), slot: slotFor(now),
      start: nap ? Math.round(nap.since) : n - 60, end: n,
    });
    if (edit) {
      Object.assign(base, edit.form, { ago: 0, at: Math.round(edit.t), nurseMode: 'Enter minutes' });
      if (edit.type === 'sleep') Object.assign(base, { kind: edit.nap ? 'Nap' : 'Night sleep', start: Math.round(edit.start), end: Math.round(edit.end) });
    }
    setF(base);
  }, [open, type, edit && edit.id]);

  const t = f.at != null ? f.at : now - f.ago;
  const topical = MEDS[f.med][0] === null;
  const setUnit = u => set({ unit: u, amount: u === f.unit ? f.amount : convert(f.amount, u) });
  const amountRow = (
    <div className="kit-amount">
      <AmountField value={f.amount} onChange={v => set({ amount: v })} unit={f.unit} />
      <SegmentedControl size="sm" options={['oz', 'mL']} value={f.unit} onChange={setUnit} />
    </div>
  );
  const presetRow = list => (
    <div className="kit-chips kit-chips--even" style={{ gridTemplateColumns: 'repeat(6, 1fr)' }}>
      {list.map(p => <Chip key={p} selected={f.amount === p} onClick={() => set({ amount: p })}>{p}</Chip>)}
    </div>
  );
  const modeSwitch = <SegmentedControl block options={['Timer', 'Enter minutes']} value={f.nurseMode} onChange={v => set({ nurseMode: v })} />;
  let body, cta, events, message, ok = true, timeLabel = 'Time', save = null, aside = null;

  if (type === 'sleep' && nap && !edit) {
    timeLabel = null;
    cta = 'Set start to ' + clock(f.start);
    save = () => onNapStart(f.start);
    body = (
      <React.Fragment>
        <TimeField label="Fell asleep" value={toHM(f.start)} onChange={v => v && set({ start: fromHM(v) })} />
        <p className="kit-hint">The timer keeps running on every device.</p>
      </React.Fragment>
    );
  } else if (type === 'sleep') {
    timeLabel = null;
    const night = f.kind === 'Night sleep';
    const s = night && f.start >= f.end ? f.start - 1440 : f.start;
    const len = f.end - s;
    ok = len > 0;
    cta = ok ? 'Log ' + dur(len) + (night ? ' night sleep' : ' nap') : 'End is before start';
    events = [{ type: 'sleep', nap: !night, t: night ? f.end : s, start: s, end: f.end, title: night ? 'Night sleep' : (edit && edit.nap ? edit.title : 'Nap ' + (napsDone + 1)), detail: range(s, f.end) + ' · ' + dur(len) }];
    message = (night ? 'Night sleep' : 'Nap') + ' logged · ' + dur(len);
    body = (
      <React.Fragment>
        <SegmentedControl block size="lg" options={['Nap', 'Night sleep']} value={f.kind} onChange={v => set({ kind: v })} />
        <div className="kit-pair">
          <TimeField label="Start" value={toHM(f.start)} onChange={v => v && set({ start: fromHM(v) })} />
          <TimeField label="End" value={toHM(f.end)} onChange={v => v && set({ end: fromHM(v) })} />
        </div>
        <p className="kit-hint">{ok ? dur(len) + ' asleep' + (s < 0 ? ' · started yesterday' : '') : 'Pick an end time after the start.'}</p>
      </React.Fragment>
    );
  } else if (type === 'feeding') {
    cta = 'Log ' + (f.amount || '0') + ' ' + f.unit;
    const detail = f.amount + ' ' + f.unit + ' ' + f.substance.toLowerCase();
    events = [{ type: 'feeding', t: t, oz: f.unit === 'oz' ? parseFloat(f.amount) || 0 : (parseFloat(f.amount) || 0) / 29.57, breast: f.substance === 'Breast milk', title: 'Bottle', detail: detail }];
    if (f.vitd && !edit) events.push({ type: 'medicine', t: t, title: 'Vitamin D', detail: '1 drop · supplement' });
    message = 'Bottle logged · ' + f.amount + ' ' + f.unit;
    body = (
      <React.Fragment>
        {amountRow}
        {presetRow(PRESETS[f.unit])}
        <SegmentedControl block size="lg" options={['Formula', 'Breast milk', 'Mixed']} value={f.substance} onChange={v => set({ substance: v })} />
        {edit ? null : <Checkbox checked={f.vitd} onChange={v => set({ vitd: v })} label="+ Vitamin D" sub="Logs a supplement alongside this bottle" />}
      </React.Fragment>
    );
  } else if (type === 'nursing' && !edit && (nurse || f.nurseMode === 'Timer')) {
    timeLabel = null;
    const s = nurseSecs(nurse);
    ok = !!nurse;
    cta = nurse ? 'Log ' + Math.max(1, Math.round(s.total / 60)) + ' min nursing' : 'Tap a side to start';
    save = onNurseFinish;
    aside = nurse ? <Button variant="danger" size="lg" icon="trash-2" aria-label="Discard timer" onClick={onNurseDiscard} /> : null;
    body = (
      <React.Fragment>
        {nurse
          ? <div className="kit-nursehead"><span className="bl-label">Started {clock(nurse.startedAt)}</span><Badge event="nursing">{nurse.active ? 'Running' : 'Paused'}</Badge></div>
          : modeSwitch}
        <NursingTimer left={s.left} right={s.right} active={nurse ? nurse.active : null} onSide={onNurseSide} />
        <p className="kit-hint">{nurse ? 'Runs on every device. You can close this.' : 'Tap a side to start the timer.'}</p>
      </React.Fragment>
    );
  } else if (type === 'nursing') {
    timeLabel = 'Started';
    const mins = f.minutes || '0';
    cta = 'Log ' + mins + ' min nursing';
    events = [{ type: 'feeding', kind: 'nursing', t: t, min: parseFloat(mins) || 0, title: 'Nursing', detail: mins + 'm · ' + sides(f.side) }];
    message = 'Nursing logged · ' + mins + 'm';
    body = (
      <React.Fragment>
        {edit ? null : modeSwitch}
        <AmountField value={f.minutes} onChange={v => set({ minutes: v })} unit="min" />
        <div className="kit-chips kit-chips--even" style={{ gridTemplateColumns: 'repeat(6, 1fr)' }}>
          {NURSE_PRESETS.map(p => <Chip key={p} selected={f.minutes === p} onClick={() => set({ minutes: p })}>{p}</Chip>)}
        </div>
        <Field label="Side"><SegmentedControl block size="lg" options={['Left', 'Right', 'Both']} value={f.side} onChange={v => set({ side: v })} /></Field>
      </React.Fragment>
    );
  } else if (type === 'pump') {
    cta = 'Log ' + (f.amount || '0') + ' ' + f.unit + ' pumped';
    events = [{ type: 'pump', t: t, title: 'Pump', detail: f.amount + ' ' + f.unit + ' · ' + sides(f.pumpSide) }];
    message = 'Pump logged · ' + f.amount + ' ' + f.unit;
    body = (
      <React.Fragment>
        {amountRow}
        {presetRow(PUMP_PRESETS[f.unit])}
        <Field label="Side"><SegmentedControl block size="lg" options={['Left', 'Right', 'Both']} value={f.pumpSide} onChange={v => set({ pumpSide: v })} /></Field>
      </React.Fragment>
    );
  } else if (type === 'diaper') {
    cta = 'Log diaper';
    const parts = [f.pee !== 'None' && 'Pee ' + f.pee, f.poop !== 'None' && 'Poop ' + f.poop, f.rash && 'Rash'].filter(Boolean);
    events = [{ type: 'diaper', t: t, title: 'Diaper', detail: parts.join(' · ') || 'Dry' }];
    message = 'Diaper logged · ' + (parts.join(' · ') || 'Dry');
    body = (
      <React.Fragment>
        <Field label="Pee"><SegmentedControl block size="lg" options={['None', 'S', 'M', 'L']} value={f.pee} onChange={v => set({ pee: v })} /></Field>
        <Field label="Poop"><SegmentedControl block size="lg" options={['None', 'S', 'M', 'L']} value={f.poop} onChange={v => set({ poop: v })} /></Field>
        <Checkbox checked={f.rash} onChange={v => set({ rash: v })} label="Rash" />
      </React.Fragment>
    );
  } else if (type === 'meal') {
    cta = 'Log ' + f.slot.toLowerCase();
    events = [{ type: 'meal', t: t, title: f.slot, detail: [f.ate, f.portion + ' eaten'].filter(Boolean).join(' · ') }];
    message = f.slot + ' logged';
    body = (
      <React.Fragment>
        <SegmentedControl block options={['Breakfast', 'Lunch', 'Dinner', 'Snack']} value={f.slot} onChange={v => set({ slot: v })} />
        <TextField label="What she ate" placeholder="Optional" value={f.ate} onChange={v => set({ ate: v })} />
        <Field label="How much"><SegmentedControl block size="lg" options={['None', 'Some', 'Most']} value={f.portion} onChange={v => set({ portion: v })} /></Field>
      </React.Fragment>
    );
  } else if (type === 'bath') {
    cta = 'Log bath';
    events = [{ type: 'bath', t: t, title: 'Bath', detail: [f.hair === 'Yes' ? 'Hair shampooed' : 'No shampoo', f.bathNote].filter(Boolean).join(' · ') }];
    message = 'Bath logged';
    body = (
      <React.Fragment>
        <Field label="Shampooed hair?"><SegmentedControl block size="lg" options={['No', 'Yes']} value={f.hair} onChange={v => set({ hair: v })} /></Field>
        <TextField label="Notes" placeholder="Optional" value={f.bathNote} onChange={v => set({ bathNote: v })} />
      </React.Fragment>
    );
  } else if (type === 'medicine') {
    cta = 'Log ' + (f.med === 'Custom' ? 'care' : f.med);
    events = [{ type: 'medicine', t: t, title: f.med, detail: topical ? 'Topical' : f.dose + ' ' + unitText(f.dose, f.doseUnit) + ' · ' + MEDS[f.med][2] }];
    message = f.med + ' logged';
    body = (
      <React.Fragment>
        <div className="kit-chips">
          {Object.keys(MEDS).map(m => <Chip key={m} selected={f.med === m} onClick={() => set({ med: m, dose: MEDS[m][0] || '', doseUnit: MEDS[m][1] || 'mL' })}>{m}</Chip>)}
        </div>
        {topical ? <p className="kit-hint">Topical care. No dose needed.</p> : (
          <div className="kit-amount">
            <AmountField size="md" value={f.dose} onChange={v => set({ dose: v })} unit={f.doseUnit} />
            <SegmentedControl size="sm" options={['mL', 'drops', 'mg']} value={f.doseUnit} onChange={v => set({ doseUnit: v })} />
          </div>
        )}
      </React.Fragment>
    );
  } else {
    cta = 'Save note';
    events = [{ type: 'note', t: t, title: 'Note', detail: f.note || 'No text' }];
    message = 'Note saved';
    body = <TextField multiline rows={4} placeholder="Anything worth remembering about today" value={f.note} onChange={v => set({ note: v })} />;
  }

  if (edit && events) {
    if (ok) cta = 'Save changes';
    save = () => onUpdate(edit.id, Object.assign({ form: f }, events[0]), events[0].title + ' updated');
    aside = <Button variant="danger" size="lg" icon="trash-2" aria-label="Delete entry" onClick={() => onDelete(edit)} />;
  }
  const commit = save || (() => onSave(events.map(e => Object.assign({ form: f }, e)), message));

  return (
    <Sheet open={open} onClose={onClose} title={TITLES[type]} icon={<EventIcon type={type} />}
      footer={<div className="kit-foot">{aside}<Button size="lg" block disabled={!ok} onClick={commit}>{cta}</Button></div>}>
      {body}
      {timeLabel ? (
        <div className="kit-field">
          <span className="bl-label">{timeLabel}</span>
          {edit ? <TimeField aria-label={timeLabel} value={toHM(t)} onChange={v => v && set({ at: fromHM(v) })} /> : (
            <div className="kit-time">
              <TimeField aria-label={timeLabel} value={toHM(t)} onChange={v => v && set({ at: fromHM(v) })} />
              {AGO.map(a => <Chip key={a[0]} selected={f.at == null && f.ago === a[0]} onClick={() => set({ ago: a[0], at: null })}>{a[1]}</Chip>)}
            </div>
          )}
        </div>
      ) : null}
    </Sheet>
  );
}
