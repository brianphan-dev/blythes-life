import React from 'react';

export function TextField({ label, value, onChange, multiline, rows = 3, className = '', ...rest }) {
  const Tag = multiline ? 'textarea' : 'input';
  return (
    <label className={'bl-field ' + className}>
      {label ? <span className="bl-label">{label}</span> : null}
      <Tag className="bl-field__input" value={value} rows={multiline ? rows : undefined} onChange={e => onChange && onChange(e.target.value)} {...rest} />
    </label>
  );
}
