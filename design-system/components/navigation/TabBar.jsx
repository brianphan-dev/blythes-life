import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function TabBar({ items = [], value, onChange, className = '' }) {
  return (
    <nav className={'bl-tabbar ' + className}>
      {items.map(it => (
        <button key={it.id} type="button" aria-current={it.id === value ? 'page' : undefined} className={'bl-tabbar__item' + (it.id === value ? ' is-active' : '')} onClick={() => onChange && onChange(it.id)}>
          <Icon name={it.icon} size={24} />
          <span>{it.label}</span>
          {it.badge ? <span className="bl-tabbar__badge">{it.badge}</span> : null}
        </button>
      ))}
    </nav>
  );
}
