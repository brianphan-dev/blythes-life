import * as React from 'react';

/** Time-since-last stat that doubles as a shortcut to log that event again. */
export interface GlanceStatProps {
  type?: 'sleep' | 'feeding' | 'nursing' | 'pump' | 'diaper' | 'meal' | 'bath' | 'medicine' | 'note';
  /** Uppercase label, e.g. "Last bottle". */
  label?: React.ReactNode;
  /** Elapsed time, e.g. "2h 9m". */
  value?: React.ReactNode;
  /** What was logged, e.g. "2.5 oz breast milk". */
  sub?: React.ReactNode;
  onClick?: React.MouseEventHandler<HTMLButtonElement>;
}

export declare function GlanceStat(props: GlanceStatProps): JSX.Element;
