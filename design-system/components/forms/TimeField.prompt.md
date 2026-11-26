Exact clock-time entry for an event's time, or a sleep's start and end.

```jsx
<TimeField label="Start" value="09:15" onChange={setStart} />
<TimeField label="End" value="10:32" onChange={setEnd} />
```

Value is 24-hour "HH:MM"; the field displays it in the device's format. Tapping anywhere opens the system time picker. In a log sheet, place one beside Now / 5m ago / 15m ago chips so relative time stays one tap and exact time is always available.
