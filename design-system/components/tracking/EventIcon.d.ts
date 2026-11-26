import * as React from 'react';

/** Tinted square glyph that identifies an event type everywhere it appears. */
export interface EventIconProps {
  type?: 'sleep' | 'feeding' | 'nursing' | 'pump' | 'diaper' | 'meal' | 'bath' | 'medicine' | 'note';
  /** sm 22px, md 32px, lg 44px. */
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export declare function EventIcon(props: EventIconProps): JSX.Element;
