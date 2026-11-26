import * as React from 'react';

/** Selectable quick-pick chip for presets (amounts, time offsets, medicine names). */
export interface ChipProps {
  selected?: boolean;
  /** md 44px, lg 52px. */
  size?: 'md' | 'lg';
  /** Lucide icon name. */
  icon?: string;
  disabled?: boolean;
  onClick?: React.MouseEventHandler<HTMLButtonElement>;
  children?: React.ReactNode;
}

export declare function Chip(props: ChipProps): JSX.Element;
