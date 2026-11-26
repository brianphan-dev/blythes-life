import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function Toast({ open, icon = 'check', message, actionLabel, onAction, style }) {
  return (
    <div role="status" className={'bl-toast' + (open ? ' is-open' : '')} style={style}>
      {icon ? <Icon name={icon} size={18} /> : null}
      <span className="bl-toast__msg">{message}</span>
      {actionLabel ? <button type="button" className="bl-toast__action" onClick={onAction}>{actionLabel}</button> : null}
    </div>
  );
}
