import * as React from 'react';

/** Optional add-on to an entry (+ Vitamin D, rash) with a label and helper line. */
export interface CheckboxProps {
  checked?: boolean;
  onChange?: (checked: boolean) => void;
  label?: React.ReactNode;
  /** Helper line under the label. */
  sub?: React.ReactNode;
}

export declare function Checkbox(props: CheckboxProps): JSX.Element;
