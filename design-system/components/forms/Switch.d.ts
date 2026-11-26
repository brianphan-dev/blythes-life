import * as React from 'react';

/** Binary on/off setting that applies immediately. */
export interface SwitchProps {
  checked?: boolean;
  onChange?: (checked: boolean) => void;
  /** Accessible label. */
  label?: string;
}

export declare function Switch(props: SwitchProps): JSX.Element;
