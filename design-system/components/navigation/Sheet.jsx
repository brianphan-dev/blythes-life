import React from 'react';
import { IconButton } from '../core/IconButton.jsx';

export function Sheet({ open, onClose, title, icon, footer, children }) {
  return (
    <React.Fragment>
      <div className={'bl-sheet-scrim' + (open ? ' is-open' : '')} onClick={onClose}></div>
      <section role="dialog" aria-modal="true" aria-hidden={!open} className={'bl-sheet' + (open ? ' is-open' : '')}>
        <div className="bl-sheet__grab"></div>
        <header className="bl-sheet__head">
          {icon}
          <h2 className="bl-sheet__title">{title}</h2>
          <IconButton icon="x" label="Close" onClick={onClose} />
        </header>
        <div className="bl-sheet__body">{children}</div>
        {footer ? <footer className="bl-sheet__foot">{footer}</footer> : null}
      </section>
    </React.Fragment>
  );
}
