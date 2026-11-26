import * as React from 'react';

/** Settings-style row with label, optional value, trailing control and chevron. */
export interface ListRowProps {
  /** Lucide icon name. */
  icon?: string;
  label: React.ReactNode;
  /** Secondary line under the label. */
  detail?: React.ReactNode;
  /** Right-aligned value text. */
  value?: React.ReactNode;
  /** Right-aligned control, e.g. a Switch. */
  trailing?: React.ReactNode;
  chevron?: boolean;
  danger?: boolean;
  onClick?: React.MouseEventHandler<HTMLElement>;
}

export declare function ListRow(props: ListRowProps): JSX.Element;
