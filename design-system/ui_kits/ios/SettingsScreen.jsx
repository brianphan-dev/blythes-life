import React from 'react';
import { Card } from '../../components/core/Card.jsx';
import { ListRow } from '../../components/core/ListRow.jsx';
import { SegmentedControl } from '../../components/forms/SegmentedControl.jsx';
import { Switch } from '../../components/forms/Switch.jsx';

function Group({ title, children }) {
  return (
    <React.Fragment>
      <div className="kit-section"><span className="bl-label">{title}</span></div>
      <Card flush>{children}</Card>
    </React.Fragment>
  );
}

export function SettingsScreen({ theme, onToggleTheme, unit, onUnit, onAction }) {
  return (
    <div className="kit-view">
      <header className="kit-head">
        <div>
          <div className="bl-label">Blythe's household</div>
          <h1 className="kit-title">Settings</h1>
        </div>
      </header>
      <div className="kit-scroll">
        <Group title="Nap schedule">
          <ListRow label="Awake before nap 1" value="2½h" chevron onClick={() => onAction('Wake window editor opens here')} />
          <ListRow label="Awake before nap 2" value="3¼h" chevron onClick={() => onAction('Wake window editor opens here')} />
          <ListRow label="Nap cap" value="90m" chevron onClick={() => onAction('Nap cap editor opens here')} />
          <ListRow label="Backup catnap cutoff" value="4:30 PM" chevron onClick={() => onAction('Cutoff editor opens here')} />
        </Group>
        <Group title="Logging">
          <ListRow label="Bottle unit" trailing={<SegmentedControl size="sm" options={['oz', 'mL']} value={unit} onChange={onUnit} />} />
          <ListRow label="Night mode" detail="True black with warm, dim text" trailing={<Switch checked={theme === 'night'} onChange={onToggleTheme} label="Night mode" />} />
        </Group>
        <Group title="Household">
          <ListRow icon="users" label="Members" value="3" chevron onClick={() => onAction('Member list opens here')} />
          <ListRow icon="key-round" label="Invite code" value="482 913" />
        </Group>
        <Group title="Your data">
          <ListRow icon="download" label="Import from Huckleberry" detail="CSV. Re-importing never duplicates." chevron onClick={() => onAction('File picker opens here')} />
          <ListRow icon="upload" label="Export everything" detail="JSON bundle you can re-import" chevron onClick={() => onAction('Share sheet opens here')} />
          <ListRow icon="file-text" label="Export for the pediatrician" detail="Readable CSV" chevron onClick={() => onAction('Share sheet opens here')} />
        </Group>
        <Group title="Account">
          <ListRow label="Signed in with Apple" />
          <ListRow label="Sign out" danger onClick={() => onAction('Signs out on this device only')} />
        </Group>
      </div>
    </div>
  );
}
