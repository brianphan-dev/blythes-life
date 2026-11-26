import React from 'react';

export function AmountField({ value = '', onChange, unit, size = 'lg', placeholder = '0', ...rest }) {
  const len = Math.max(String(value).length, String(placeholder).length, 1);
  const handle = e => {
    const v = e.target.value.replace(',', '.');
    if (/^\d*\.?\d*$/.test(v) && onChange) onChange(v);
  };
  return (
    <label className={'bl-amount bl-amount--' + size}>
      <input className="bl-amount__input" inputMode="decimal" value={value} placeholder={placeholder} style={{ width: (len + 0.3) + 'ch' }} onChange={handle} {...rest} />
      {unit ? <span className="bl-amount__unit">{unit}</span> : null}
    </label>
  );
}
