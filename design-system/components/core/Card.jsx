import React from 'react';

export function Card({ tone = 'surface', flush, onClick, className = '', children, ...rest }) {
  const cls = 'bl-card bl-card--' + tone + (flush ? ' bl-card--flush' : '') + (onClick ? ' is-pressable' : '') + ' ' + className;
  if (onClick) return <button type="button" className={cls} onClick={onClick} {...rest}>{children}</button>;
  return <div className={cls} {...rest}>{children}</div>;
}
