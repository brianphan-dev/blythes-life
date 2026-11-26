import * as React from 'react';

/** One-tap tile in the quick-log grid; opens the log sheet for its event type. */
export interface QuickTileProps {
  type?: 'sleep' | 'feeding' | 'nursing' | 'pump' | 'diaper' | 'meal' | 'bath' | 'medicine' | 'note';
  /** Overrides the default label for the type. */
  label?: React.ReactNode;
  /** Secondary line, e.g. "2h 9m ago". */
  sub?: React.ReactNode;
  /** sm = compact stacked tile (four across in the phone dock), md = row tile, lg = large stacked tile (iPad, tabletop). */
  size?: 'sm' | 'md' | 'lg';
  onClick?: React.MouseEventHandler<HTMLButtonElement>;
}

export declare function QuickTile(props: QuickTileProps): JSX.Element;
