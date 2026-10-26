import YAML from 'yaml';
import partsRaw from '../../content/parts.yaml?raw';
import type { Part, Stage, Step, CatalogStep } from './types';

const catalog = YAML.parse(partsRaw) as { stages: Stage[]; parts: Part[] };

export const stages: Stage[] = catalog.stages;
export const parts: Part[] = catalog.parts;
export const allSteps: (CatalogStep & { part: number; index: number })[] = parts.flatMap((p) =>
  p.steps.map((s, i) => ({ ...s, part: p.id, index: i + 1 })),
);
export const TOTAL_STEPS = allSteps.length;

const stepFiles = import.meta.glob('../../content/steps/*/step.yaml', {
  query: '?raw',
  import: 'default',
}) as Record<string, () => Promise<string>>;
const bodyFiles = import.meta.glob('../../content/steps/*/body.md', {
  query: '?raw',
  import: 'default',
}) as Record<string, () => Promise<string>>;

const key = (id: string, file: string) => `../../content/steps/${id}/${file}`;

/** 本体（step.yaml）が用意されているステップの番号 */
export const availableIds = new Set(
  Object.keys(stepFiles).map((k) => k.split('/').at(-2) as string),
);

export function catalogStep(id: string) {
  return allSteps.find((s) => s.id === id);
}

export function partOf(id: string) {
  const s = catalogStep(id);
  return s ? parts.find((p) => p.id === s.part) : undefined;
}

export function stageOfPart(partId: number) {
  return stages.find((s) => s.parts.includes(partId));
}

export function neighbor(id: string, delta: number) {
  const i = allSteps.findIndex((s) => s.id === id);
  return allSteps[i + delta];
}

export async function loadStep(id: string): Promise<{ step: Step; body: string } | null> {
  const sf = stepFiles[key(id, 'step.yaml')];
  if (!sf) return null;
  const step = YAML.parse(await sf()) as Step;
  const bf = bodyFiles[key(id, 'body.md')];
  const body = bf ? await bf() : '';
  return { step, body };
}
