import React from 'react';

export function SegmentedControl({ options = [], value, onChange, size = 'md', block, className = '', ...rest }) {
  const opts = options.map(o => (o && typeof o === 'object' ? o : { value: o, label: o }));
  return (
    <div role="radiogroup" className={'bl-seg bl-seg--' + size + (block ? ' bl-seg--block' : '') + ' ' + className} {...rest}>
      {opts.map(o => (
        <button key={String(o.value)} type="button" role="radio" aria-checked={o.value === value} className={'bl-seg__opt' + (o.value === value ? ' is-selected' : '')} onClick={() => onChange && onChange(o.value)}>
          {o.label}
        </button>
      ))}
    </div>
  );
}
