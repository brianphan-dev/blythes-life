Bottom sheet for logging forms; slides over the current screen.

```jsx
<Sheet open={open} onClose={close} title="Bottle" icon={<EventIcon type="feeding" />} footer={<Button size="lg" block>Log 3.25 oz</Button>}>
  ...
</Sheet>
```

Positions against the nearest positioned ancestor, so the screen container needs position: relative. Keep it mounted and toggle open so it can animate out.
