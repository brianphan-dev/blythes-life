import React from 'react';
import { Icon } from './Icon.jsx';

export function Badge({ tone = 'neutral', event, icon, className = '', children }) {
  const cls = 'bl-badge ' + (event ? 'bl-badge--event bl-ev--' + event : 'bl-badge--' + tone) + ' ' + className;
  return (
    <span className={cls}>
      {icon ? <Icon name={icon} size={12} /> : null}
      {children}
    </span>
  );
}
