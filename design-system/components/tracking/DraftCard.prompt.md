An extracted entry in scan review: include or skip it, see its match status, resolve ambiguity.

```jsx
<DraftCard type="diaper" time="11:20 AM" title="Diaper" detail="Pee L" ambiguity="Time was written over. Which is it?" options={['11:20 AM', '11:30 AM']} onResolve={setTime} />
```

Nothing is saved until the parent confirms. Duplicates default to not included.
