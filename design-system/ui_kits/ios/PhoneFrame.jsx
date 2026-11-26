import React from 'react';
import { Icon } from '../../components/core/Icon.jsx';

export function PhoneFrame({ theme = 'day', children }) {
  return (
    <div className="kit-phone">
      <div className="kit-phone__screen" data-theme={theme === 'night' ? 'night' : undefined}>
        <div className="kit-status">
          <span>9:41</span>
          <span className="kit-status__island"></span>
          <span className="kit-status__sys"><Icon name="signal" size={16} /><Icon name="wifi" size={16} /><Icon name="battery-full" size={22} /></span>
        </div>
        <div className="kit-body">{children}</div>
      </div>
    </div>
  );
}
