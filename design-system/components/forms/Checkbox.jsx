import React from 'react';
import { Icon } from '../core/Icon.jsx';

export function Checkbox({ checked, onChange, label, sub, ...rest }) {
  return (
    <button type="button" role="checkbox" aria-checked={!!checked} className="bl-check" onClick={() => onChange && onChange(!checked)} {...rest}>
      <span className="bl-check__box"><Icon name="check" size={16} /></span>
      {label ? (
        <span>
          <span>{label}</span>
          {sub ? <span className="bl-check__sub">{sub}</span> : null}
        </span>
      ) : null}
    </button>
  );
}
