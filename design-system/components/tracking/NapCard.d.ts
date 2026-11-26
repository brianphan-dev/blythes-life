import * as React from 'react';

/** Hero card showing the live awake or asleep timer, the wake-window rail and the nap action. */
export interface NapCardProps {
  state?: 'awake' | 'asleep';
  /** Uppercase context line, e.g. "Awake · since 10:32 AM". */
  label?: React.ReactNode;
  /** Duration string, e.g. "2h 22m". Digits render large, units small. */
  elapsed?: string;
  /** 0 to 1 along the wake window (awake) or nap cap (asleep). */
  progress?: number;
  /** Past the sweet spot or nap cap; turns the rail amber. */
  over?: boolean;
  caption?: React.ReactNode;
  actionLabel?: string;
  onAction?: () => void;
  /** Text button under the main action, e.g. "Add a past sleep" or "Change start time". */
  secondaryLabel?: string;
  onSecondary?: () => void;
}

export declare function NapCard(props: NapCardProps): JSX.Element;
