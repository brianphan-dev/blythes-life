import React from 'react';

export function Switch({ checked, onChange, label, ...rest }) {
  return <button type="button" role="switch" aria-checked={!!checked} aria-label={label} className="bl-switch" onClick={() => onChange && onChange(!checked)} {...rest}></button>;
}
