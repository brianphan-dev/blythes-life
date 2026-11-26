import * as React from 'react';

/** Live nursing timer: total time over two large Left / Right buttons that start, switch and pause. */
export interface NursingTimerProps {
  /** Seconds nursed on the left side so far. */
  left?: number;
  /** Seconds nursed on the right side so far. */
  right?: number;
  /** Side currently running, or null when paused or not started. */
  active?: 'left' | 'right' | null;
  /** Called with the tapped side. Tapping the running side pauses; tapping the other side switches. */
  onSide?: (side: 'left' | 'right') => void;
}

export declare function NursingTimer(props: NursingTimerProps): JSX.Element;
