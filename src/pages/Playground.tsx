import { useState } from 'react';
import CodeEditor from '../components/CodeEditor';
import OutputPane from '../components/OutputPane';
import { ensurePackages, getRuntimeState, runStudentCode } from '../runtime/webr';
import type { RunResult } from '../runtime/webr';
import { parseStatus } from '../runtime/errors';

const SAMPLE = `1 + 1

library(ggplot2)
d <- data.frame(年 = 2016:2025, 最低賃金 = c(823, 848, 874, 901, 902, 930, 961, 1004, 1055, 1121))
ggplot(d, aes(年, 最低賃金)) +
  geom_line() + geom_point() +
  labs(title = "全国加重平均の最低賃金（円/時）")`;

/** 動作確認用の自由なエディタ（M0 の受け入れ確認・パッケージ検証に使う） */
export default function Playground() {
  const [code, setCode] = useState(SAMPLE);
  const [pkgs, setPkgs] = useState('ggplot2');
  const [run, setRun] = useState<RunResult>();
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const exec = async () => {
    setBusy(true);
    setErr('');
    try {
      const list = pkgs.split(/[\s,]+/).filter(Boolean);
      if (list.length) await ensurePackages(list);
      const r = await runStudentCode(code);
      setRun(r);
      const st = parseStatus(r.status);
      if (st.kind !== 'ok') setErr(`${st.ja ?? ''} R のメッセージ: ${st.message}`);
    } catch (e) {
      setErr(String((e as Error).message ?? e));
    } finally {
      setBusy(false);
    }
  };

  const sec = getRuntimeState().startupSeconds;
  return (
    <div className="page playground">
      <h1>自由に試す</h1>
      <p className="lead">判定のないエディタです。ステップの外で R を試したり、パッケージが動くかを確かめたりできます。</p>
      {sec !== undefined && <p className="note">R の起動にかかった時間: {sec} 秒</p>}
      <label className="pkg-field">
        読み込むパッケージ（カンマ区切り）
        <input value={pkgs} onChange={(e) => setPkgs(e.target.value)} />
      </label>
      <CodeEditor value={code} onChange={setCode} onRun={exec} ariaLabel="自由に試すコード" minLines={10} />
      <div className="actions">
        <button type="button" className="btn btn-primary" onClick={exec} disabled={busy}>
          {busy ? '実行中…' : '実行'}
          <kbd>Ctrl/⌘+Enter</kbd>
        </button>
      </div>
      {err && <div className="feedback feedback-error" role="alert">{err}</div>}
      <OutputPane run={run} />
    </div>
  );
}
