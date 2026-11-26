import * as React from 'react';

/** Single or multi-line text input with an uppercase form label. */
export interface TextFieldProps {
  label?: React.ReactNode;
  value?: string;
  onChange?: (value: string) => void;
  placeholder?: string;
  multiline?: boolean;
  /** Rows when multiline. Default 3. */
  rows?: number;
}

export declare function TextField(props: TextFieldProps): JSX.Element;
