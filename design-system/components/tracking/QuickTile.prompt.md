One-tap tile in the quick-log grid; opens the log sheet for its event type.

```jsx
<div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0, 1fr))', gap: 8 }}>
  <QuickTile size="sm" type="feeding" onClick={logBottle} />
  <QuickTile size="sm" type="nursing" />
  <QuickTile size="sm" type="pump" />
  <QuickTile size="sm" type="diaper" />
</div>
```

size="sm" stacks the glyph over the label so eight tiles fit in two rows on a phone. Press state floods the tile with the event tint.
