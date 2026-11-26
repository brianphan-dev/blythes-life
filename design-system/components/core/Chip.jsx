import React from 'react';
import { Icon } from './Icon.jsx';

export function Chip({ selected, size = 'md', icon, className = '', children, ...rest }) {
  return (
    <button type="button" aria-pressed={!!selected} className={'bl-chip bl-chip--' + size + (selected ? ' is-selected' : '') + ' ' + className} {...rest}>
      {icon ? <Icon name={icon} size={16} /> : null}
      {children}
    </button>
  );
}
