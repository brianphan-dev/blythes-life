Live nursing timer: total time over two large Left / Right buttons that start, switch and pause.

```jsx
<NursingTimer left={252} right={95} active="left" onSide={toggleSide} />
```

The component is controlled and does not tick itself; pass fresh seconds each render. Tapping the running side pauses it, tapping the other side switches. The running side floods with the feeding tint. Keep the layout around it fixed so the buttons never move under the thumb when the timer starts.
