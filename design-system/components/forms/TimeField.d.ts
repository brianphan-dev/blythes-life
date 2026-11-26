import * as React from 'react';

/** Exact clock-time entry for an event's time, or a sleep's start and end. */
export interface TimeFieldProps {
  /** Uppercase form label, e.g. "Start". Omit when a label sits elsewhere and pass aria-label instead. */
  label?: React.ReactNode;
  /** 24-hour "HH:MM", e.g. "13:47". */
  value?: string;
  onChange?: (value: string) => void;
  className?: string;
  'aria-label'?: string;
}

export declare function TimeField(props: TimeFieldProps): JSX.Element;
