// Sample data for the click-through. Times are minutes since midnight on Wed, Nov 25.
export const BASE_NOW = 774; // 12:54 PM
export const SCHEDULE = { windows: [150, 195], napCap: 90, bedtime: 240 };

export function clock(min) {
  const m = ((Math.round(min) % 1440) + 1440) % 1440;
  const h = Math.floor(m / 60);
  return ((h + 11) % 12 + 1) + ':' + String(m % 60).padStart(2, '0') + ' ' + (h < 12 ? 'AM' : 'PM');
}
export function dur(min) {
  const m = Math.max(0, Math.round(min));
  const h = Math.floor(m / 60);
  return h ? h + 'h ' + (m % 60) + 'm' : m + 'm';
}
export function range(a, b) {
  const x = clock(a), y = clock(b);
  return (x.slice(-2) === y.slice(-2) ? x.slice(0, -3) : x) + ' – ' + y;
}
export function toHM(min) {
  const m = ((Math.round(min) % 1440) + 1440) % 1440;
  return String(Math.floor(m / 60)).padStart(2, '0') + ':' + String(m % 60).padStart(2, '0');
}
export function fromHM(s) {
  const p = String(s).split(':');
  return (+p[0]) * 60 + (+p[1]);
}
// Live seconds per side for a running nursing session { left, right, active, since }.
export function nurseSecs(n) {
  if (!n) return { left: 0, right: 0, total: 0 };
  const live = n.active ? (Date.now() - n.since) / 1000 : 0;
  const left = n.left + (n.active === 'left' ? live : 0), right = n.right + (n.active === 'right' ? live : 0);
  return { left: left, right: right, total: left + right };
}
export function mmss(sec) {
  const s = Math.max(0, Math.floor(sec));
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

// `form` holds the log-sheet field values so an entry can be reopened for editing.
export const INITIAL_EVENTS = [
  { id: 'a1', type: 'sleep', nap: false, t: 405, start: -290, end: 405, title: 'Night sleep', detail: '7:10 PM – 6:45 AM · 11h 35m', source: 'manual' },
  { id: 'a2', type: 'feeding', t: 420, oz: 4, title: 'Bottle', detail: '4 oz formula', source: 'manual', form: { amount: '4', unit: 'oz', substance: 'Formula' } },
  { id: 'a3', type: 'diaper', t: 425, title: 'Diaper', detail: 'Pee M', source: 'manual', form: { pee: 'M', poop: 'None' } },
  { id: 'a4', type: 'meal', t: 480, title: 'Breakfast', detail: 'Oatmeal, banana · Some eaten', source: 'manual', form: { slot: 'Breakfast', ate: 'Oatmeal, banana', portion: 'Some' } },
  { id: 'a5', type: 'sleep', nap: true, t: 555, start: 555, end: 632, title: 'Nap 1', detail: '9:15 – 10:32 AM · 1h 17m', source: 'paper_scan' },
  { id: 'a5p', type: 'pump', t: 585, title: 'Pump', detail: '4.5 oz · Both sides', source: 'manual', form: { amount: '4.5', unit: 'oz', pumpSide: 'Both' } },
  { id: 'a6', type: 'diaper', t: 640, title: 'Diaper', detail: 'Pee L · Poop S', source: 'paper_scan', form: { pee: 'L', poop: 'S' } },
  { id: 'a7', type: 'feeding', t: 645, oz: 2.5, breast: true, title: 'Bottle', detail: '2.5 oz breast milk', source: 'paper_scan', form: { amount: '2.5', unit: 'oz', substance: 'Breast milk' } },
];

// Extraction result for the 12:50 PM photo. `row` ties a draft to its line on the sheet; `ev` is merged into the saved event.
export const DRAFTS = [
  { id: 's1', row: 'nap', type: 'sleep', t: 555, time: '9:15 AM', title: 'Nap 1', detail: 'Until 10:32 AM · 1h 17m', status: 'skip_duplicate', ev: { nap: true, start: 555, end: 632, detail: '9:15 – 10:32 AM · 1h 17m' } },
  { id: 's2', row: 'd1', type: 'diaper', t: 640, time: '10:40 AM', title: 'Diaper', detail: 'Pee L · Poop S', status: 'skip_duplicate', ev: { form: { pee: 'L', poop: 'S' } } },
  { id: 's3', row: 'b1', type: 'feeding', t: 645, time: '10:45 AM', title: 'Bottle', detail: '2.5 oz breast milk', status: 'skip_duplicate', ev: { oz: 2.5, breast: true, form: { amount: '2.5', unit: 'oz', substance: 'Breast milk' } } },
  { id: 's4', row: 'b1', type: 'medicine', t: 645, time: '10:45 AM', title: 'Vitamin D', detail: 'The row is labelled + VIT D', saved: '1 drop · supplement', status: 'create', suggestion: true, ev: { form: { med: 'Vitamin D', dose: '1', doseUnit: 'drops' } } },
  { id: 's5', row: 'd2', type: 'diaper', t: 680, time: '11:20 AM', title: 'Diaper', detail: 'Pee L', status: 'create', ambiguity: 'The time was written over. Which is it?', options: ['11:20 AM', '11:30 AM'], ev: { form: { pee: 'L', poop: 'None' } } },
  { id: 's6', row: 'lunch', type: 'meal', t: 720, time: '12:00 PM', title: 'Lunch', detail: 'Most eaten', status: 'create', ev: { form: { slot: 'Lunch', portion: 'Most' } } },
  { id: 's7', row: 'd3', type: 'diaper', t: 740, time: '12:20 PM', title: 'Diaper', detail: 'Pee M', status: 'create', ev: { form: { pee: 'M', poop: 'None' } } },
];
