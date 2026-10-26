import { useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import { allSteps, parts, stages, TOTAL_STEPS } from '../content/loader';
import { doneCount, exportJson, importJson, useProgress } from '../store/progress';
import type { Progress as P } from '../store/progress';

const AUTHOR = '安藤至大（日本大学経済学部）';

function stageDone(p: P, stageId: number) {
  const st = stages.find((s) => s.id === stageId)!;
  const ids = parts.filter((x) => st.parts.includes(x.id)).flatMap((x) => x.steps.map((s) => s.id));
  const done = ids.filter((id) => p.steps[id]?.done);
  const dates = done.map((id) => p.steps[id]?.doneAt).filter(Boolean).sort() as string[];
  return { total: ids.length, done: done.length, completedAt: done.length === ids.length ? dates.at(-1) : undefined };
}

function Certificate({ stageId, completedAt, name }: { stageId: number; completedAt: string; name: string }) {
  const st = stages.find((s) => s.id === stageId)!;
  const last = Number(st.gate);
  return (
    <div className="certificate">
      <p className="cert-kicker">修了証</p>
      <h3>Rデータ分析 108ステップ</h3>
      <p className="cert-stage">
        {st.name}「{st.title}」（ステップ {last - 26}–{last}）
      </p>
      <p className="cert-name">{name || '（氏名）'}</p>
      <p>上記の者は、本教材の{st.name}の全ステップを修了したことを証します。</p>
      <p className="cert-date">{completedAt.slice(0, 10)}</p>
      <p className="cert-author">{AUTHOR}</p>
    </div>
  );
}

export default function Progress() {
  const p = useProgress();
  const [name, setName] = useState('');
  const [msg, setMsg] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);
  const [cert, setCert] = useState<number | null>(null);

  const download = () => {
    const blob = new Blob([exportJson()], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `r108-progress-${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const upload = async (f: File) => {
    try {
      importJson(await f.text(), 'merge');
      setMsg('進捗を読み込み、この端末の記録と合わせました。');
    } catch (e) {
      setMsg(`読み込めませんでした: ${(e as Error).message}`);
    }
  };

  return (
    <div className="page progress-page">
      <h1 className="no-print">進捗と修了証</h1>
      <p className="lead no-print">
        完了 <strong>{doneCount(p)}</strong> / {TOTAL_STEPS} ステップ
      </p>

      <section className="no-print">
        <h2>段階ごとの進み具合</h2>
        <div className="stage-progress">
          {stages.map((st) => {
            const s = stageDone(p, st.id);
            return (
              <div key={st.id} className="sp-row">
                <span className="sp-label">
                  {st.name} {st.title}
                </span>
                <div className="bar" role="progressbar" aria-valuemin={0} aria-valuemax={s.total} aria-valuenow={s.done} aria-label={`${st.name}の進捗`}>
                  <div className="bar-fill" style={{ width: `${(100 * s.done) / s.total}%` }} />
                </div>
                <span className="sp-num">
                  {s.done} / {s.total}
                </span>
                {s.completedAt ? (
                  <button type="button" className="btn" onClick={() => setCert(st.id)}>
                    修了証を表示
                  </button>
                ) : (
                  <span className="sp-hint">ステップ{Number(st.gate)}までで修了証</span>
                )}
              </div>
            );
          })}
        </div>
      </section>

      {cert !== null && (
        <section className="cert-area">
          <div className="no-print cert-tools">
            <label>
              修了証に載せる氏名{' '}
              <input value={name} onChange={(e) => setName(e.target.value)} placeholder="氏名" />
            </label>
            <button type="button" className="btn btn-primary" onClick={() => window.print()}>
              印刷する
            </button>
          </div>
          <Certificate stageId={cert} completedAt={stageDone(p, cert).completedAt!} name={name} />
        </section>
      )}

      <section className="no-print">
        <h2>別の端末に移す</h2>
        <p>進捗はこのブラウザにだけ保存されています。書き出したファイルを別の端末で読み込むと、続きから学べます。</p>
        <div className="actions">
          <button type="button" className="btn" onClick={download}>
            進捗を書き出す（JSON）
          </button>
          <button type="button" className="btn" onClick={() => fileRef.current?.click()}>
            進捗を読み込む
          </button>
          <input
            ref={fileRef}
            type="file"
            accept="application/json,.json"
            hidden
            onChange={(e) => e.target.files?.[0] && upload(e.target.files[0])}
          />
        </div>
        {msg && <p className="note" role="status">{msg}</p>}
      </section>

      <section className="no-print">
        <h2>完了したステップ</h2>
        <ul className="done-list">
          {allSteps
            .filter((s) => p.steps[s.id]?.done)
            .map((s) => (
              <li key={s.id}>
                <Link to={`/step/${s.id}`}>
                  {Number(s.id)}. {s.title}
                </Link>
                <span className="muted">{p.steps[s.id]?.doneAt?.slice(0, 10)}</span>
              </li>
            ))}
        </ul>
        {doneCount(p) === 0 && <p className="muted">まだ完了したステップはありません。</p>}
      </section>
    </div>
  );
}
