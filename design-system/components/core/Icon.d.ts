import * as React from 'react';

/** Lucide icon-font glyph; use for every icon so stroke weight stays consistent. */
export interface IconProps {
  /** Lucide icon name, e.g. "moon", "milk", "scan-text". */
  name: string;
  /** Pixel size. Default 20. */
  size?: number;
  className?: string;
  style?: React.CSSProperties;
}

export declare function Icon(props: IconProps): JSX.Element;
