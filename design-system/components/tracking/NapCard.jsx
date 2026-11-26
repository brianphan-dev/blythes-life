import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Button } from '../core/Button.jsx';

export function NapCard({ state = 'awake', label, elapsed = '', progress = 0, over, caption, actionLabel, onAction, secondaryLabel, onSecondary }) {
  const asleep = state === 'asleep';
  const parts = String(elapsed).split(/(\d+)/).filter(p => p.trim() !== '');
  const pct = Math.min(1, Math.max(0, progress)) * 100;
  return (
    <section className={'bl-nap bl-nap--' + state + ' bl-ev--sleep'}>
      <div className="bl-nap__top">
        <span className="bl-label">{label}</span>
        <Icon name={asleep ? 'moon' : 'sun'} size={18} />
      </div>
      <div className="bl-nap__timer">
        {parts.map((p, i) => (/\d/.test(p) ? <span key={i}>{p}</span> : <span key={i} className="bl-nap__unit">{p.trim()}</span>))}
      </div>
      <div className="bl-nap__rail">
        <div className={'bl-nap__fill' + (over ? ' is-over' : '')} style={{ width: pct + '%' }}></div>
        <div className="bl-nap__tick"></div>
      </div>
      {caption ? <div className="bl-nap__caption">{caption}</div> : null}
      {actionLabel ? <Button variant={asleep ? 'ink' : 'primary'} size="lg" block icon={asleep ? 'sun' : 'moon'} onClick={onAction}>{actionLabel}</Button> : null}
      {secondaryLabel ? <Button variant="ghost" block className="bl-nap__secondary" onClick={onSecondary}>{secondaryLabel}</Button> : null}
    </section>
  );
}
