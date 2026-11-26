import React from 'react';
import { Icon } from '../core/Icon.jsx';

// Keys match events.event_type, plus nursing (a feeding with method breast) and pump.
export const EVENT_TYPES = {
  sleep: { label: 'Sleep', icon: 'moon' },
  feeding: { label: 'Bottle', icon: 'milk' },
  nursing: { label: 'Nursing', icon: 'baby' },
  pump: { label: 'Pump', icon: 'beaker' },
  diaper: { label: 'Diaper', icon: 'droplets' },
  meal: { label: 'Meal', icon: 'utensils' },
  bath: { label: 'Bath', icon: 'bath' },
  medicine: { label: 'Meds & care', icon: 'pill' },
  note: { label: 'Note', icon: 'notebook-pen' },
};

export function EventIcon({ type = 'note', size = 'md', className = '' }) {
  const meta = EVENT_TYPES[type] || EVENT_TYPES.note;
  const px = size === 'sm' ? 13 : size === 'lg' ? 24 : 18;
  return (
    <span className={'bl-evicon bl-evicon--' + size + ' bl-ev--' + type + ' ' + className}>
      <Icon name={meta.icon} size={px} />
    </span>
  );
}
