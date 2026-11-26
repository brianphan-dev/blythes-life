import React from 'react';
import { Icon } from './Icon.jsx';

export function ListRow({ icon, label, detail, value, trailing, chevron, danger, onClick, className = '' }) {
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag type={onClick ? 'button' : undefined} className={'bl-row' + (danger ? ' bl-row--danger' : '') + ' ' + className} onClick={onClick}>
      {icon ? <Icon name={icon} size={20} /> : null}
      <span className="bl-row__main">
        <span>{label}</span>
        {detail ? <span className="bl-row__detail">{detail}</span> : null}
      </span>
      {value != null ? <span className="bl-row__value">{value}</span> : null}
      {trailing}
      {chevron ? <Icon name="chevron-right" size={18} className="bl-row__chev" /> : null}
    </Tag>
  );
}
