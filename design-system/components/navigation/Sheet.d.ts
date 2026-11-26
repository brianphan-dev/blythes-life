import * as React from 'react';

/** Bottom sheet for logging forms; slides over the current screen. */
export interface SheetProps {
  open?: boolean;
  onClose?: () => void;
  title?: React.ReactNode;
  /** Element shown before the title, usually an EventIcon. */
  icon?: React.ReactNode;
  /** Pinned footer, usually one block Button. */
  footer?: React.ReactNode;
  children?: React.ReactNode;
}

export declare function Sheet(props: SheetProps): JSX.Element;
