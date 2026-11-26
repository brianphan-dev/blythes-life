import * as React from 'react';

/** Pick exactly one of 2 to 4 short options (S / M / L, oz / mL, None / Some / Most). */
export interface SegmentedControlProps {
  /** Strings, or { value, label } pairs. */
  options: Array<string | { value: string; label: React.ReactNode }>;
  value?: string;
  onChange?: (value: string) => void;
  /** sm 30px (inline in rows), md 38px, lg 52px (in log sheets). */
  size?: 'sm' | 'md' | 'lg';
  /** Full width, equal columns. */
  block?: boolean;
}

export declare function SegmentedControl(props: SegmentedControlProps): JSX.Element;
