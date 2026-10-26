// webR の起動・パッケージ読込・データ配置・コード実行をまとめる。
// GitHub Pages では独自ヘッダー（COOP/COEP）を付けられないため PostMessage チャンネルを使う。
import { WebR, ChannelType } from 'webr';
import type { RCharacter, RList } from 'webr';

export type OutputLine = { type: 'stdout' | 'stderr' | 'message' | 'warning' | 'error'; text: string };

export type RunResult = {
  lines: OutputLine[];
  images: ImageBitmap[];
  /** "ok" | "error\t<msg>\t<call>" | "parse\t<msg>" */
  status: string;
};

type Listener = (s: RuntimeState) => void;
export type RuntimeState = {
  phase: 'idle' | 'starting' | 'ready' | 'busy' | 'failed';
  message: string;
  startupSeconds?: number;
};

const BASE = import.meta.env.BASE_URL;
const HOME = '/home/web_user';

let webR: WebR | null = null;
/** 起動のたびに増える番号。再起動後に環境を作り直すために使う */
let generation = 0;
export const getGeneration = () => generation;
let starting: Promise<WebR> | null = null;
const installed = new Set<string>();
const mounted = new Set<string>();
let state: RuntimeState = { phase: 'idle', message: 'R はまだ起動していません' };
const listeners = new Set<Listener>();
// webR は1つずつしか実行できないので、呼び出しを直列化する
let queue: Promise<unknown> = Promise.resolve();

function setState(s: Partial<RuntimeState>) {
  state = { ...state, ...s };
  listeners.forEach((l) => l(state));
}

export function subscribeRuntime(l: Listener): () => void {
  listeners.add(l);
  l(state);
  return () => listeners.delete(l);
}

export function getRuntimeState(): RuntimeState {
  return state;
}

function serial<T>(fn: () => Promise<T>): Promise<T> {
  const p = queue.then(fn, fn);
  queue = p.catch(() => undefined);
  return p;
}

export function startR(): Promise<WebR> {
  if (webR) return Promise.resolve(webR);
  if (starting) return starting;
  const t0 = performance.now();
  setState({ phase: 'starting', message: 'R を起動しています…（初回は数十秒かかります）' });
  starting = (async () => {
    const w = new WebR({ channelType: ChannelType.PostMessage, interactive: false });
    await w.init();
    const src = await fetch(`${BASE}r/r108check.R`).then((r) => {
      if (!r.ok) throw new Error('判定用スクリプト r108check.R を読み込めませんでした');
      return r.text();
    });
    await w.FS.writeFile(`${HOME}/r108check.R`, new TextEncoder().encode(src));
    await w.evalRVoid(`
      local({
        e <- new.env()
        sys.source("${HOME}/r108check.R", envir = e)
        attach(e, name = "r108check", warn.conflicts = FALSE)
      })
      options(width = 80, warn = 1, pillar.width = 80)
      dir.create("data", showWarnings = FALSE)
    `);
    webR = w;
    generation++;
    const sec = Math.round((performance.now() - t0) / 100) / 10;
    setState({ phase: 'ready', message: `R の準備ができました（起動 ${sec} 秒）`, startupSeconds: sec });
    return w;
  })();
  starting.catch((e) => {
    starting = null;
    setState({ phase: 'failed', message: `R を起動できませんでした: ${String(e?.message ?? e)}` });
  });
  return starting;
}

/** 無限ループなどで固まったときの再起動（PostMessage 方式では実行中断ができないため） */
export async function restartR(): Promise<void> {
  try {
    webR?.close();
  } catch {
    /* 終了済み */
  }
  webR = null;
  starting = null;
  installed.clear();
  mounted.clear();
  queue = Promise.resolve();
  await startR();
}

export function ensurePackages(pkgs: string[]): Promise<void> {
  return serial(async () => {
    const w = await startR();
    const todo = pkgs.filter((p) => !installed.has(p));
    if (todo.length === 0) return;
    setState({ phase: 'busy', message: `パッケージを読み込んでいます: ${todo.join(', ')}（初回のみ）` });
    await w.installPackages(todo, { quiet: true, mount: true });
    todo.forEach((p) => installed.add(p));
    setState({ phase: 'ready', message: 'R の準備ができました' });
  });
}

/** パッケージ検証ページ用：指定した配布元から入れてみる（失敗しても installed には記録しない） */
export function tryInstall(pkg: string, repos: string[]): Promise<void> {
  return serial(async () => {
    const w = await startR();
    await w.installPackages([pkg], { quiet: true, mount: true, repos });
  });
}

export function ensureData(files: string[]): Promise<void> {
  return serial(async () => {
    const w = await startR();
    for (const f of files) {
      if (mounted.has(f)) continue;
      const res = await fetch(`${BASE}data/${f}`);
      if (!res.ok) throw new Error(`データ ${f} を取得できませんでした（${res.status}）`);
      const buf = new Uint8Array(await res.arrayBuffer());
      await w.FS.writeFile(`${HOME}/data/${f}`, buf);
      mounted.add(f);
    }
  });
}

/** 戻り値の文字列だけが欲しい R の式を評価する */
export function evalString(code: string): Promise<string> {
  return serial(async () => {
    const w = await startR();
    return w.evalRString(code);
  });
}

async function bindString(w: WebR, name: string, value: string) {
  await w.objs.globalEnv.bind(name, value);
}

/** R の文字列リテラルの代わりに、値をグローバル変数に渡してから関数を呼ぶ */
export function callR(fn: string, args: Record<string, string>): Promise<string> {
  return serial(async () => {
    const w = await startR();
    const names: string[] = [];
    for (const [k, v] of Object.entries(args)) {
      const name = `.r108_arg_${k}`;
      await bindString(w, name, v);
      names.push(`${k} = ${name}`);
    }
    return w.evalRString(`as.character(${fn}(${names.join(', ')}))`);
  });
}

/** 学生のコードを実行し、出力・図・状態を返す */
export function runStudentCode(code: string, plot = { width: 720, height: 480 }): Promise<RunResult> {
  return serial(async () => {
    const w = await startR();
    setState({ phase: 'busy', message: '実行中…' });
    await bindString(w, '.r108_code', code);
    const shelter = await new w.Shelter();
    try {
      const cap = await shelter.captureR('run_student(.r108_code)', {
        withAutoprint: false,
        captureStreams: true,
        captureConditions: true,
        captureGraphics: { width: plot.width, height: plot.height, pointsize: 14, bg: 'white' },
      });
      const lines: OutputLine[] = [];
      for (const o of cap.output) {
        const type = o.type as OutputLine['type'];
        if (type === 'stdout' || type === 'stderr') {
          lines.push({ type, text: String(o.data) });
          continue;
        }
        // message / warning / error は R の条件オブジェクト
        let text = '';
        try {
          const msg = await (o.data as RList).get('message');
          text = (await (msg as RCharacter).toArray()).join('');
        } catch {
          text = String(o.data);
        }
        lines.push({ type, text: text.replace(/\n$/, '') });
      }
      const status = await w.evalRString('run_status()');
      return { lines, images: cap.images, status };
    } finally {
      await shelter.purge();
      setState({ phase: 'ready', message: 'R の準備ができました' });
    }
  });
}
