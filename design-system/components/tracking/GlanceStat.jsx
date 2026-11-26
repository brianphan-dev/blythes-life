import React from 'react';
import { EventIcon } from './EventIcon.jsx';

export function GlanceStat({ type, label, value, sub, className = '', ...rest }) {
  return (
    <button type="button" className={'bl-glance ' + className} {...rest}>
      <span className="bl-glance__label bl-label">
        {type ? <EventIcon type={type} size="sm" /> : null}
        {label}
      </span>
      <span className="bl-glance__value">{value}</span>
      {sub ? <span className="bl-glance__sub">{sub}</span> : null}
    </button>
  );
}
