import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { EventIcon } from './EventIcon.jsx';

const SOURCE_ICON = { paper_scan: 'scan-text', import_huckleberry: 'download', control_center: 'zap' };

export function EventRow({ type = 'note', time, title, detail, source, trailing, onClick }) {
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag type={onClick ? 'button' : undefined} className="bl-event" onClick={onClick}>
      <span className="bl-event__time">{time}</span>
      <EventIcon type={type} />
      <span className="bl-event__main">
        <span className="bl-event__title">{title}</span>
        {detail ? <span className="bl-event__detail">{detail}</span> : null}
      </span>
      <span className="bl-event__trail">
        {trailing}
        {SOURCE_ICON[source] ? <Icon name={SOURCE_ICON[source]} size={16} /> : null}
      </span>
    </Tag>
  );
}
