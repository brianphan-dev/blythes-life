import * as React from 'react';

/** One logged event in the day timeline: time, type glyph, title and detail. */
export interface EventRowProps {
  type?: 'sleep' | 'feeding' | 'nursing' | 'pump' | 'diaper' | 'meal' | 'bath' | 'medicine' | 'note';
  /** Clock time, e.g. "10:45 AM". */
  time?: React.ReactNode;
  title?: React.ReactNode;
  detail?: React.ReactNode;
  /** Where the event came from; non-manual sources show a small glyph. */
  source?: 'manual' | 'paper_scan' | 'import_huckleberry' | 'control_center';
  trailing?: React.ReactNode;
  onClick?: React.MouseEventHandler<HTMLElement>;
}

export declare function EventRow(props: EventRowProps): JSX.Element;
