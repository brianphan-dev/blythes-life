Hero card showing the live awake or asleep timer, the wake-window rail and the nap action.

```jsx
<NapCard state="awake" label="Awake · since 10:32 AM" elapsed="2h 22m" progress={0.73} caption={<span>Nap 2 sweet spot <b>1:47 PM</b> · in 53m</span>} actionLabel="Start nap" onAction={startNap} secondaryLabel="Add a past sleep" onSecondary={enterTimes} />
```

The tick at the end of the rail is the sweet spot (awake) or the nap cap (asleep). Asleep state floods the card with the sleep tint.
