Bottom tab bar for the four top-level destinations.

```jsx
<TabBar value="today" onChange={setTab} items={[
  { id: 'today', label: 'Today', icon: 'sun' },
  { id: 'rhythm', label: 'Rhythm', icon: 'calendar-range' },
  { id: 'sheets', label: 'Sheets', icon: 'scan-text', badge: 1 },
  { id: 'settings', label: 'Settings', icon: 'settings' },
]} />
```

Active tab gets a honey tick on the top hairline. Leave room below for the home indicator.
