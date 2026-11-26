import React from 'react';

export function Icon({ name, size = 20, className = '', style, ...rest }) {
  return <i aria-hidden="true" className={'icon-' + name + ' bl-icon ' + className} style={{ fontSize: size, ...style }} {...rest}></i>;
}
