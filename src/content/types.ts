export type ExerciseType = 'write' | 'fill' | 'predict' | 'fix' | 'interpret';

export type Exercise = {
  id: string;
  type: ExerciseType;
  review?: boolean;
  prompt: string;
  starter?: string;
  solution?: string;
  check?: string;
  hints?: string[];
  choices?: string[];
  answer?: number;
  explain?: string;
  free?: boolean;
};

export type Step = {
  id: string;
  part: number;
  title: string;
  question: string;
  minutes: number;
  mode: 'browser' | 'local';
  packages?: string[];
  data?: string[];
  learn: string[];
  setup?: string;
  review_of?: string;
  local?: { script: string; code_sha256: string; instructions?: string };
  exercises?: Exercise[];
};

export type CatalogStep = {
  id: string;
  title: string;
  question: string;
  mode: 'browser' | 'local';
  capstone?: boolean;
};

export type Part = { id: number; title: string; steps: CatalogStep[] };
export type Stage = { id: number; name: string; title: string; parts: number[]; gate: string };

export const isChoice = (e: Exercise) => Array.isArray(e.choices);

export const typeLabel: Record<ExerciseType, string> = {
  write: '書く',
  fill: '穴埋め',
  predict: '予想',
  fix: '直す',
  interpret: '解釈',
};
