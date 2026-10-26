import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { catalogStep, loadStep, neighbor, partOf, TOTAL_STEPS, availableIds } from '../content/loader';
import type { Step as StepT } from '../content/types';
import { doneCount, recordResult, useProgress } from '../store/progress';
import { prepareStep } from '../runtime/grader';
import Markdown from '../components/Markdown';
import Exercise from '../components/Exercise';
import PartMap from '../components/PartMap';
import LocalStep from '../components/LocalStep';

export default function Step() {
  const { id = '' } = useParams();
  const progress = useProgress();
  const [data, setData] = useState<{ step: StepT; body: string } | null | undefined>(undefined);
  const [prep, setPrep] = useState<{ phase: 'loading' | 'ready' | 'error'; msg: string }>({ phase: 'loading', msg: '' });
  const cat = catalogStep(id);
  const part = partOf(id);

  useEffect(() => {
    let alive = true;
    setData(undefined);
    loadStep(id).then((d) => {
      if (!alive) return;
      setData(d);
      if (d) document.title = `${Number(id)}. ${d.step.title} | R108`;
      if (d && d.step.mode === 'browser') {
        setPrep({ phase: 'loading', msg: 'R を準備しています…' });
        prepareStep(d.step, (msg) => alive && setPrep({ phase: 'loading', msg }))
          .then(() => alive && setPrep({ phase: 'ready', msg: '' }))
          .catch((e) => alive && setPrep({ phase: 'error', msg: String(e?.message ?? e) }));
      }
    });
    window.scrollTo(0, 0);
    return () => {
      alive = false;
    };
  }, [id]);

  if (!cat || !part) {
    return (
      <div className="page">
        <p>ステップ {id} は見つかりません。</p>
        <Link to="/">目次へ</Link>
      </div>
    );
  }
  const prev = neighbor(id, -1);
  const next = neighbor(id, 1);
  const sp = progress.steps[id];

  const nav = (
    <nav className="step-nav" aria-label="前後のステップ">
      {prev ? <Link to={`/step/${prev.id}`}>← {Number(prev.id)}. {prev.title}</Link> : <span />}
      {next && availableIds.has(next.id) ? (
        <Link to={`/step/${next.id}`}>
          {Number(next.id)}. {next.title} →
        </Link>
      ) : (
        <Link to="/">目次へ</Link>
      )}
    </nav>
  );

  const head = (
    <div className="step-bar">
      <div className="step-pos">
        <Link to="/">目次</Link>
        <span aria-hidden="true">›</span>
        <span>第{part.id}部 {part.title}</span>
        <span className="pos-badge">
          {cat.index} / 9
        </span>
      </div>
      <PartMap part={part} progress={progress} current={id} />
      <div className="step-overall">
        全体 <strong>{doneCount(progress)}</strong> / {TOTAL_STEPS}
      </div>
    </div>
  );

  if (data === undefined) return <div className="page">{head}<p className="note">読み込み中…</p></div>;
  if (data === null) {
    return (
      <div className="page">
        {head}
        <h1 className="step-title">
          <span className="sno">ステップ {Number(id)}</span>
          {cat.title}
        </h1>
        {cat.question && (
          <p className="step-question">
            <span className="q-label">問い</span>
            {cat.question}
          </p>
        )}
        <p className="note">このステップは準備中です。第1部での試用を経て、1部ずつ追加します。</p>
        {nav}
      </div>
    );
  }

  const { step, body } = data;
  const exercises = step.exercises ?? [];
  const allIds = exercises.map((e) => e.id);
  const passedCount = allIds.filter((e) => sp?.exercises[e]).length;

  return (
    <div className="page step-page">
      {head}
      <div className="step-layout">
        <article className="step-body">
          <h1 className="step-title">
            <span className="sno">ステップ {Number(step.id)}</span>
            {step.title}
          </h1>
          <p className="step-question">
            <span className="q-label">問い</span>
            {step.question || cat.question}
          </p>
          <p className="step-meta">
            目安 {step.minutes} 分
            {step.learn.length > 0 && (
              <>
                {' '}・ 学ぶこと: {step.learn.map((f) => <code key={f}>{f}</code>).reduce<React.ReactNode[]>((a, c, i) => (i ? [...a, '、', c] : [c]), [])}
              </>
            )}
          </p>
          <Markdown source={body} />
        </article>
        <aside className="step-work" aria-label="小課題">
          <div className="work-head">
            <h2>小課題</h2>
            <span className="work-count">
              {passedCount} / {allIds.length} 正解
            </span>
          </div>
          {step.mode === 'browser' && prep.phase !== 'ready' && (
            <p className={`note ${prep.phase === 'error' ? 'note-error' : ''}`} role="status">
              {prep.phase === 'error' ? `準備に失敗しました: ${prep.msg}` : prep.msg}
            </p>
          )}
          {sp?.done && (
            <div className="feedback feedback-pass step-done" role="status">
              <span className="clear-badge" aria-hidden="true">CLEAR!</span>
              <strong>このステップは完了です。</strong>
              {next && availableIds.has(next.id) && <Link to={`/step/${next.id}`}>次のステップへ進む →</Link>}
            </div>
          )}
          {step.mode === 'local' ? (
            <LocalStep step={step} done={Boolean(sp?.done)} savedCode={progress.localCodes[id]} />
          ) : (
            exercises.map((ex) => (
              <Exercise
                key={`${id}-${ex.id}`}
                step={step}
                ex={ex}
                passed={Boolean(sp?.exercises[ex.id])}
                savedCode={sp?.code[ex.id]}
                onResult={(ok) => recordResult(id, ex.id, ok, allIds)}
              />
            ))
          )}
        </aside>
      </div>
      {nav}
    </div>
  );
}
