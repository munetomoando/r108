import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import OutputPane from '../components/OutputPane';
import { ensureData, ensurePackages, evalString, runStudentCode, tryInstall } from '../runtime/webr';
import type { RunResult } from '../runtime/webr';
import { JA_PLOT, PKG_CASES, WEBR_REPO, universeRepo } from '../content/pkgcheck';

type Row = {
  pkg: string;
  steps: string;
  source: string;
  version: string;
  seconds: number;
  result: string;
};

const has = async (pkg: string) => (await evalString(`as.character(requireNamespace("${pkg}", quietly = TRUE))`)) === 'TRUE';

/** M4：第2〜12部で使うパッケージが webR で動くかを1つずつ確かめる（目次には出さない検証用の画面） */
export default function PkgCheck() {
  const [rows, setRows] = useState<Row[]>([]);
  const [running, setRunning] = useState(false);
  const [plot, setPlot] = useState<RunResult>();
  const [done, setDone] = useState(false);
  // #/pkgcheck?only=ranger,testthat で一部だけ試せる
  const [params] = useSearchParams();
  const only = params.get('only')?.split(',').filter(Boolean);
  const cases = only ? PKG_CASES.filter((c) => only.includes(c.pkg)) : PKG_CASES;

  const start = async () => {
    setRunning(true);
    setRows([]);
    const out: Row[] = [];
    for (const c of cases) {
      const t0 = performance.now();
      let source = '入らない';
      let result = '';
      try {
        await tryInstall(c.pkg, [WEBR_REPO]).catch(() => undefined);
        if (await has(c.pkg)) source = 'repo.r-wasm.org';
        else if (c.universe) {
          await tryInstall(c.pkg, [universeRepo(c.universe), WEBR_REPO]).catch(() => undefined);
          if (await has(c.pkg)) source = `${c.universe}.r-universe.dev`;
        }
        if (source !== '入らない') {
          if (c.data) await ensureData(c.data);
          result = await evalString(
            `tryCatch({ ${c.test} }, error = function(e) paste("NG:", conditionMessage(e)))`,
          );
        } else result = 'NG: インストールできない';
      } catch (e) {
        result = `NG: ${String((e as Error).message ?? e)}`;
      }
      const version = source === '入らない' ? '' : await evalString(`as.character(packageVersion("${c.pkg}"))`).catch(() => '');
      out.push({ pkg: c.pkg, steps: c.steps, source, version, seconds: Math.round((performance.now() - t0) / 100) / 10, result });
      setRows([...out]);
    }
    try {
      await ensurePackages(['ggplot2']);
      setPlot(await runStudentCode(JA_PLOT));
    } catch {
      /* 図が描けないことは画面で分かる */
    }
    (window as unknown as { __pkgcheck: Row[] }).__pkgcheck = out;
    setRunning(false);
    setDone(true);
  };

  const ng = rows.filter((r) => r.result !== 'ok').length;
  return (
    <div className="page playground">
      <h1>パッケージ検証</h1>
      <p className="lead">
        第2〜12部で使う {cases.length} 個のパッケージを、この R（webR）に入れて試します。全部で数分かかります。
      </p>
      <div className="actions">
        <button type="button" className="btn btn-primary" onClick={start} disabled={running}>
          {running ? `検証中…（${rows.length} / ${cases.length}）` : '検証を始める'}
        </button>
      </div>
      {rows.length > 0 && (
        <div className="prose" style={{ maxWidth: 'none' }}>
          <table className="pkg-table">
            <thead>
              <tr><th>パッケージ</th><th>使うステップ</th><th>入手元</th><th>版</th><th>秒</th><th>結果</th></tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.pkg}>
                  <td><code>{r.pkg}</code></td><td>{r.steps}</td><td>{r.source}</td><td>{r.version}</td><td>{r.seconds}</td>
                  <td>{r.result === 'ok' ? '✓ 動く' : r.result}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {done && <p className="note" data-testid="pkgcheck-done">検証が終わりました。動かないもの：{ng} 個</p>}
      {plot && (
        <>
          <h2>日本語の図</h2>
          <p>見出し・軸・凡例・注記・出所の日本語が読めるかを目で確かめます。</p>
          <OutputPane run={plot} />
        </>
      )}
    </div>
  );
}
