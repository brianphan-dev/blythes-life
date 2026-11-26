import * as React from 'react';

/** Square icon-only button (44px minimum) for close, edit and theme toggles. */
export interface IconButtonProps {
  /** Lucide icon name. */
  icon: string;
  /** Accessible label (required, not shown). */
  label: string;
  variant?: 'plain' | 'outline' | 'filled';
  size?: 'md' | 'lg';
  onClick?: React.MouseEventHandler<HTMLButtonElement>;
}

export declare function IconButton(props: IconButtonProps): JSX.Element;
