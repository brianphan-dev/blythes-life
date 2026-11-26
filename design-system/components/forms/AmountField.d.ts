import * as React from 'react';

/** Large decimal entry on a ruled line for bottle amounts and doses. */
export interface AmountFieldProps {
  /** Decimal string, e.g. "3.25". */
  value?: string;
  onChange?: (value: string) => void;
  /** Unit shown after the number: oz, mL, drops, mg. */
  unit?: string;
  /** lg 64px numeral, md 40px. */
  size?: 'md' | 'lg';
  placeholder?: string;
}

export declare function AmountField(props: AmountFieldProps): JSX.Element;
