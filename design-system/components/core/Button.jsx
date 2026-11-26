import React from 'react';
import { Icon } from './Icon.jsx';

export function Button({ variant = 'primary', size = 'md', icon, block, className = '', children, ...rest }) {
  const cls = 'bl-btn bl-btn--' + variant + ' bl-btn--' + size + (block ? ' bl-btn--block' : '') + ' ' + className;
  return (
    <button type="button" className={cls} {...rest}>
      {icon ? <Icon name={icon} size={size === 'sm' ? 16 : size === 'lg' ? 22 : 20} /> : null}
      {children}
    </button>
  );
}
