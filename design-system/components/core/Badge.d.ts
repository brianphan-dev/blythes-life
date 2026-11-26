import * as React from 'react';

/** Small uppercase status label: scan match status, confidence, counts. */
export interface BadgeProps {
  /** Status tone. Ignored when event is set. */
  tone?: 'neutral' | 'accent' | 'warn' | 'ok' | 'danger';
  /** Tint with an event colour instead of a status tone. */
  event?: 'sleep' | 'feeding' | 'nursing' | 'pump' | 'diaper' | 'meal' | 'bath' | 'medicine' | 'note';
  /** Lucide icon name. */
  icon?: string;
  children?: React.ReactNode;
}

export declare function Badge(props: BadgeProps): JSX.Element;
