import * as React from 'react';

/** Text button for committing an action; one primary (honey) button per view. */
export interface ButtonProps {
  /** primary = honey fill, ink = dark fill (wake up), secondary = outlined, ghost = text only, danger = destructive. */
  variant?: 'primary' | 'ink' | 'secondary' | 'ghost' | 'danger';
  /** sm 36px, md 48px, lg 60px (sleepy-thumb). */
  size?: 'sm' | 'md' | 'lg';
  /** Lucide icon name shown before the label. */
  icon?: string;
  /** Full width. */
  block?: boolean;
  disabled?: boolean;
  onClick?: React.MouseEventHandler<HTMLButtonElement>;
  children?: React.ReactNode;
}

export declare function Button(props: ButtonProps): JSX.Element;
