import React from 'react';
import { EventIcon, EVENT_TYPES } from './EventIcon.jsx';

export function QuickTile({ type = 'note', label, sub, size = 'md', className = '', ...rest }) {
  const meta = EVENT_TYPES[type] || EVENT_TYPES.note;
  return (
    <button type="button" className={'bl-tile bl-tile--' + size + ' bl-ev--' + type + ' ' + className} {...rest}>
      <EventIcon type={type} size={size === 'lg' ? 'lg' : 'md'} />
      <span className="bl-tile__text">
        <span>{label || meta.label}</span>
        {sub ? <span className="bl-tile__sub">{sub}</span> : null}
      </span>
    </button>
  );
}
