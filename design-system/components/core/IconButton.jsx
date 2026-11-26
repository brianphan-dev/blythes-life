import React from 'react';
import { Icon } from './Icon.jsx';

export function IconButton({ icon, label, variant = 'plain', size = 'md', className = '', ...rest }) {
  return (
    <button type="button" aria-label={label} className={'bl-iconbtn bl-iconbtn--' + variant + ' bl-iconbtn--' + size + ' ' + className} {...rest}>
      <Icon name={icon} size={size === 'lg' ? 26 : 22} />
    </button>
  );
}
