import * as React from 'react';

/** An extracted entry in scan review: include or skip it, see its match status, resolve ambiguity. */
export interface DraftCardProps {
  type?: 'sleep' | 'feeding' | 'nursing' | 'pump' | 'diaper' | 'meal' | 'bath' | 'medicine' | 'note';
  time?: React.ReactNode;
  title?: React.ReactNode;
  detail?: React.ReactNode;
  /** match_action from the extraction. */
  status?: 'create' | 'skip_duplicate' | 'update_existing';
  /** Optional suggestion (e.g. Vitamin D from a "+ VIT D" label). */
  suggestion?: boolean;
  included?: boolean;
  onToggle?: (included: boolean) => void;
  /** Highlights the card and its region on the photo. */
  selected?: boolean;
  onSelect?: () => void;
  /** Reason shown in the amber strip when the reading is uncertain. */
  ambiguity?: React.ReactNode;
  /** Candidate readings offered as buttons. */
  options?: string[];
  onResolve?: (option: string) => void;
}

export declare function DraftCard(props: DraftCardProps): JSX.Element;
