import React from 'react';
import { Icon } from '../core/Icon.jsx';

function fmt(sec) {
  const s = Math.max(0, Math.floor(sec || 0));
  return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
}

export function NursingTimer({ left = 0, right = 0, active = null, onSide }) {
  const side = (id, label, sec) => {
    const on = active === id;
    return (
      <button type="button" aria-pressed={on} className={'bl-nurse__side' + (on ? ' is-active' : '')} onClick={() => onSide && onSide(id)}>
        <span className="bl-label">{label}</span>
        <span className="bl-nurse__time">{fmt(sec)}</span>
        <span className="bl-nurse__state"><Icon name={on ? 'pause' : 'play'} size={16} />{on ? 'Pause' : active ? 'Switch' : sec > 0 ? 'Resume' : 'Start'}</span>
      </button>
    );
  };
  return (
    <div className="bl-nurse">
      <div className="bl-nurse__total">{fmt(left + right)}</div>
      <div className="bl-nurse__sides">{side('left', 'Left', left)}{side('right', 'Right', right)}</div>
    </div>
  );
}
