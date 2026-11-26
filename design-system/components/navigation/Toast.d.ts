import * as React from 'react';

/** Brief confirmation with an Undo action; replaces confirm dialogs after logging. */
export interface ToastProps {
  open?: boolean;
  /** Lucide icon name. Default "check". */
  icon?: string;
  message?: React.ReactNode;
  actionLabel?: string;
  onAction?: () => void;
  style?: React.CSSProperties;
}

export declare function Toast(props: ToastProps): JSX.Element;
