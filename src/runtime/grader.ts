// 判定の流れ（設計書「判定の流れ」1〜5）:
//  1. ステップを開いたら新しいR環境を作り setup を実行
//  2. 別の環境で各小課題の solution を実行して .sol として保持（ステップ内で1回）
//  3. 学生のコードを実行し、標準出力・図・エラーを取得
//  4. 学生の環境で check を実行。失敗メッセージがあれば表示、なければ正解
//  5. R のエラーは日本語の説明に置き換える
import type { Exercise, Step } from '../content/types';
import { isChoice } from '../content/types';
import { callR, ensureData, ensurePackages, getGeneration, runStudentCode, startR } from './webr';
import type { RunResult } from './webr';
import { parseStatus } from './errors';

export type Verdict =
  | { kind: 'pass' }
  | { kind: 'fail'; message: string }
  | { kind: 'error'; message: string; ja: string | null; call?: string };

export type Attempt = { run?: RunResult; verdict: Verdict; prepared?: string[] };

let activeKey = '';
let preparing: Promise<void> | null = null;
const ranOk = new Set<string>();

const codeExercises = (step: Step) =>
  (step.exercises ?? []).filter((e) => !isChoice(e) && !e.free && e.solution);

/** このステップ用の R 環境を用意する（必要なときだけ作り直す） */
export function prepareStep(step: Step, onProgress?: (msg: string) => void): Promise<void> {
  const key = () => `${step.id}#${getGeneration()}`;
  if (activeKey === key() && preparing) return preparing;
  preparing = (async () => {
    await startR();
    if (step.packages?.length) {
      onProgress?.('パッケージを読み込んでいます…');
      await ensurePackages(step.packages);
    }
    if (step.data?.length) {
      onProgress?.('データを読み込んでいます…');
      await ensureData(step.data);
    }
    onProgress?.('課題を準備しています…');
    await callR('session_start', { setup: step.setup ?? '' });
    for (const ex of codeExercises(step)) {
      await callR('run_solution', { id: ex.id, code: ex.solution ?? '' });
    }
    ranOk.clear();
    activeKey = key();
  })();
  const p = preparing;
  p.catch(() => {
    if (preparing === p) {
      preparing = null;
      activeKey = '';
    }
  });
  return p;
}

async function ensureActive(step: Step) {
  if (activeKey !== `${step.id}#${getGeneration()}` || !preparing) await prepareStep(step);
  else await preparing;
}

/** 前の小課題をまだ実行していなければ、その正解コードを流して準備する */
async function runPrerequisites(step: Step, ex: Exercise): Promise<string[]> {
  const prepared: string[] = [];
  for (const prev of codeExercises(step)) {
    if (prev.id === ex.id) break;
    if (ranOk.has(prev.id)) continue;
    const r = await runStudentCode(prev.solution ?? '');
    if (r.status === 'ok') {
      ranOk.add(prev.id);
      prepared.push(prev.id);
    }
  }
  return prepared;
}

function stdoutText(run: RunResult) {
  return run.lines
    .filter((l) => l.type === 'stdout')
    .map((l) => l.text)
    .join('\n');
}

function verdictFromCheck(res: string): Verdict {
  if (res === 'ok') return { kind: 'pass' };
  const [kind, ...rest] = res.split('\t');
  const message = rest.join('\t');
  if (kind === 'fail') return { kind: 'fail', message };
  return { kind: 'error', message: `判定中にエラーが起きました: ${message}`, ja: null };
}

/** コードを実行するだけ（判定しない） */
export async function tryRun(step: Step, ex: Exercise, code: string): Promise<Attempt> {
  await ensureActive(step);
  const prepared = await runPrerequisites(step, ex);
  const run = await runStudentCode(code);
  const st = parseStatus(run.status);
  if (st.kind === 'ok') return { run, verdict: { kind: 'pass' }, prepared };
  return { run, verdict: { kind: 'error', message: st.message, ja: st.ja, call: st.call }, prepared };
}

/** コードを実行して判定する */
export async function runAndCheck(step: Step, ex: Exercise, code: string): Promise<Attempt> {
  await ensureActive(step);
  const prepared = await runPrerequisites(step, ex);
  const run = await runStudentCode(code);
  const st = parseStatus(run.status);
  if (st.kind !== 'ok') {
    return { run, verdict: { kind: 'error', message: st.message, ja: st.ja, call: st.call }, prepared };
  }
  const res = await callR('check_exercise', {
    id: ex.id,
    check: ex.check ?? '',
    code,
    output: stdoutText(run),
  });
  const verdict = verdictFromCheck(res);
  if (verdict.kind === 'pass') ranOk.add(ex.id);
  return { run, verdict, prepared };
}

/** 記述式の回答を判定する（回答文を .output として check に渡す） */
export async function checkFreeText(step: Step, ex: Exercise, text: string): Promise<Attempt> {
  await ensureActive(step);
  const res = await callR('check_exercise', { id: ex.id, check: ex.check ?? '', code: '', output: text });
  return { verdict: verdictFromCheck(res) };
}

/** 選択式の判定（TypeScript 側） */
export function checkChoice(ex: Exercise, selected: number): Verdict {
  if (selected === ex.answer) return { kind: 'pass' };
  return { kind: 'fail', message: 'もう一度考えてみましょう。' };
}

/** 修了コードの SHA-256 を計算する（ローカル実行ステップ用） */
export async function sha256Hex(text: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text.trim().toUpperCase()));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}
