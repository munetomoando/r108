// 進捗を localStorage（キー r108.v1）に保存する。形は設計書「進捗データの形」のとおり。
import { useSyncExternalStore } from 'react';

export const STORAGE_KEY = 'r108.v1';

export type StepProgress = {
  done: boolean;
  doneAt?: string;
  exercises: Record<string, boolean>;
  code: Record<string, string>;
};

export type Progress = {
  version: 1;
  steps: Record<string, StepProgress>;
  localCodes: Record<string, string>;
};

const empty = (): Progress => ({ version: 1, steps: {}, localCodes: {} });

function read(): Progress {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return empty();
    return normalize(JSON.parse(raw));
  } catch {
    return empty();
  }
}

/** 読み込んだ JSON を検証し、足りない項目を補う。形が違えば例外 */
export function normalize(x: unknown): Progress {
  if (!x || typeof x !== 'object') throw new Error('進捗データの形式が正しくありません');
  const o = x as Partial<Progress>;
  if (o.version !== 1) throw new Error('進捗データの版が違います（version: 1 が必要です）');
  const steps: Record<string, StepProgress> = {};
  for (const [id, s] of Object.entries(o.steps ?? {})) {
    if (!/^\d{3}$/.test(id) || !s || typeof s !== 'object') continue;
    steps[id] = {
      done: Boolean(s.done),
      doneAt: typeof s.doneAt === 'string' ? s.doneAt : undefined,
      exercises: { ...(s.exercises ?? {}) },
      code: { ...(s.code ?? {}) },
    };
  }
  const localCodes: Record<string, string> = {};
  for (const [id, c] of Object.entries(o.localCodes ?? {})) {
    if (typeof c === 'string') localCodes[id] = c;
  }
  return { version: 1, steps, localCodes };
}

let current: Progress = typeof localStorage === 'undefined' ? empty() : read();
const listeners = new Set<() => void>();

function commit(next: Progress) {
  current = next;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
  } catch {
    /* 保存できない環境（プライベートモード等）では画面上だけ保持 */
  }
  listeners.forEach((l) => l());
}

export function subscribe(l: () => void) {
  listeners.add(l);
  return () => listeners.delete(l);
}

export function getProgress(): Progress {
  return current;
}

export function useProgress(): Progress {
  return useSyncExternalStore(subscribe, getProgress, getProgress);
}

/** 日本時間のオフセット付き ISO 文字列（例 2026-11-02T10:15:00+09:00） */
export function nowIso(d = new Date()): string {
  const off = -d.getTimezoneOffset();
  const sign = off >= 0 ? '+' : '-';
  const pad = (n: number) => String(Math.floor(Math.abs(n))).padStart(2, '0');
  const local = new Date(d.getTime() + off * 60000).toISOString().slice(0, 19);
  return `${local}${sign}${pad(off / 60)}:${pad(off % 60)}`;
}

function stepOf(p: Progress, id: string): StepProgress {
  return p.steps[id] ?? { done: false, exercises: {}, code: {} };
}

export function saveCode(stepId: string, exId: string, code: string) {
  const s = stepOf(current, stepId);
  if (s.code[exId] === code) return;
  commit({ ...current, steps: { ...current.steps, [stepId]: { ...s, code: { ...s.code, [exId]: code } } } });
}

/** 小課題の正誤を記録し、全問正解ならステップを完了にする */
export function recordResult(stepId: string, exId: string, ok: boolean, allExIds: string[]) {
  const s = stepOf(current, stepId);
  const exercises = { ...s.exercises, [exId]: ok || Boolean(s.exercises[exId]) };
  const allDone = allExIds.length > 0 && allExIds.every((id) => exercises[id]);
  const done = s.done || allDone;
  const doneAt = s.doneAt ?? (allDone ? nowIso() : undefined);
  commit({ ...current, steps: { ...current.steps, [stepId]: { ...s, exercises, done, doneAt } } });
}

export function completeLocal(stepId: string, code: string) {
  const s = stepOf(current, stepId);
  commit({
    ...current,
    localCodes: { ...current.localCodes, [stepId]: code },
    steps: { ...current.steps, [stepId]: { ...s, done: true, doneAt: s.doneAt ?? nowIso() } },
  });
}

export function resetStep(stepId: string) {
  const steps = { ...current.steps };
  delete steps[stepId];
  const localCodes = { ...current.localCodes };
  delete localCodes[stepId];
  commit({ ...current, steps, localCodes });
}

export function doneCount(p: Progress = current): number {
  return Object.values(p.steps).filter((s) => s.done).length;
}

export function exportJson(): string {
  return JSON.stringify(current, null, 2);
}

/** JSON を読み込み、端末の進捗と合わせる（完了・正解は残す方を優先） */
export function importJson(text: string, mode: 'merge' | 'replace' = 'merge') {
  const incoming = normalize(JSON.parse(text));
  if (mode === 'replace') return commit(incoming);
  const steps = { ...current.steps };
  for (const [id, s] of Object.entries(incoming.steps)) {
    const mine = steps[id];
    if (!mine) {
      steps[id] = s;
      continue;
    }
    const exercises = { ...mine.exercises };
    for (const [k, v] of Object.entries(s.exercises)) exercises[k] = exercises[k] || v;
    steps[id] = {
      done: mine.done || s.done,
      doneAt: [mine.doneAt, s.doneAt].filter(Boolean).sort()[0],
      exercises,
      code: { ...s.code, ...mine.code },
    };
  }
  commit({ version: 1, steps, localCodes: { ...incoming.localCodes, ...current.localCodes } });
}

/** テスト用 */
export function _resetForTest(p: Progress = empty()) {
  current = p;
}
