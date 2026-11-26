import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Badge } from '../core/Badge.jsx';
import { Button } from '../core/Button.jsx';
import { EventIcon } from './EventIcon.jsx';

// Keys match match_action in the extraction schema.
const STATUS = { create: ['New', 'accent'], skip_duplicate: ['Already logged', 'neutral'], update_existing: ['Updates entry', 'ok'] };

export function DraftCard({ type = 'note', time, title, detail, status = 'create', suggestion, included = true, onToggle, selected, onSelect, ambiguity, options = [], onResolve }) {
  const pair = suggestion ? ['Suggested', 'neutral'] : STATUS[status] || STATUS.create;
  return (
    <div className={'bl-draft' + (selected ? ' is-selected' : '') + (included ? '' : ' is-skipped')}>
      <div className="bl-draft__main" onClick={onSelect}>
        <button type="button" role="checkbox" aria-checked={!!included} aria-label="Include this entry" className="bl-draft__check" onClick={e => { e.stopPropagation(); if (onToggle) onToggle(!included); }}>
          <span className="bl-check__box"><Icon name="check" size={16} /></span>
        </button>
        <EventIcon type={type} />
        <span className="bl-draft__text">
          <span className="bl-draft__time">{time}</span>
          <span className="bl-draft__title">{title}</span>
          {detail ? <span className="bl-draft__detail">{detail}</span> : null}
        </span>
        <Badge tone={pair[1]}>{pair[0]}</Badge>
      </div>
      {ambiguity && included ? (
        <div className="bl-draft__amb">
          <Icon name="triangle-alert" size={16} />
          <span className="bl-draft__ambtext">{ambiguity}</span>
          <span className="bl-draft__opts">
            {options.map(o => <Button key={o} size="sm" variant="secondary" onClick={() => onResolve && onResolve(o)}>{o}</Button>)}
          </span>
        </div>
      ) : null}
    </div>
  );
}
