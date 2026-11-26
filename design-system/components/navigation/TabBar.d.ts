import * as React from 'react';

/** Bottom tab bar for the four top-level destinations. */
export interface TabBarProps {
  items: Array<{ id: string; label: string; icon: string; badge?: number | string }>;
  /** Active item id. */
  value?: string;
  onChange?: (id: string) => void;
  className?: string;
}

export declare function TabBar(props: TabBarProps): JSX.Element;
