import * as React from 'react';

/** Flat paper surface with a hairline border; the default container. */
export interface CardProps {
  /** surface = paper, sunken = recessed, accent = honey tint for things needing attention. */
  tone?: 'surface' | 'sunken' | 'accent';
  /** Remove padding (for lists of ListRow). */
  flush?: boolean;
  /** Makes the whole card a pressable button. */
  onClick?: React.MouseEventHandler<HTMLElement>;
  className?: string;
  children?: React.ReactNode;
}

export declare function Card(props: CardProps): JSX.Element;
