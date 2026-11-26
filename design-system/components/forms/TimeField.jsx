import React from 'react';

export function TimeField({ label, value = '', onChange, className = '', ...rest }) {
  return (
    <label className={'bl-field bl-time ' + className}>
      {label ? <span className="bl-label">{label}</span> : null}
      <input type="time" className="bl-field__input bl-time__input" value={value} onChange={e => onChange && onChange(e.target.value)} {...rest} />
    </label>
  );
}
