import { Link } from 'react-router-dom';
import { allSteps, availableIds, parts, stages, TOTAL_STEPS } from '../content/loader';
import { doneCount, useProgress } from '../store/progress';
import PartMap from '../components/PartMap';

export default function Toc() {
  const progress = useProgress();
  const done = doneCount(progress);
  const next = allSteps.find((s) => availableIds.has(s.id) && !progress.steps[s.id]?.done);

  return (
    <div className="page toc">
      <section className="hero">
        <div className="hero-text">
        <p className="sticker">経済学部2年生のための自習教材</p>
        <h1>
          Rデータ分析 <span className="hl">108ステップ</span>
        </h1>
        <svg className="squiggle" viewBox="0 0 150 16" aria-hidden="true">
          <path d="M2 10 Q 14 2 26 10 T 50 10 T 74 10 T 98 10 T 122 10 T 146 10" fill="none" stroke="currentColor" strokeWidth="4" strokeLinecap="round" />
        </svg>
        <p className="lead">
          R を使ったことがない経済学部2年生が、ブラウザだけで順に学べる自習教材です。
          第54ステップで卒論の実証分析を、第108ステップで業務レベルの分析と報告を、一人でできるようになることを目指します。
        </p>
        <ol className="how" aria-label="1ステップの進め方">
          <li><span className="how-no">1</span>解説を読む</li>
          <li><span className="how-no">2</span>例を動かす</li>
          <li><span className="how-no">3</span>小課題に全問正解でクリア</li>
        </ol>
        <p className="meta">1ステップ約45分。進捗はこのブラウザに保存されます（ログイン不要）。</p>
        <div className="hero-actions">
          {next && (
            <Link className="btn btn-primary btn-lg" to={`/step/${next.id}`}>
              {done === 0 ? 'ステップ1から始める' : `続きから（ステップ${Number(next.id)}）`}
            </Link>
          )}
          <span className="overall">
            完了 <strong>{done}</strong> / {TOTAL_STEPS}
          </span>
        </div>
        </div>
        <div className="hero-deco" aria-hidden="true">
          <span className="blob blob-yellow" />
          <span className="blob blob-coral" />
          <div className="console-card">
            <div className="console-card-bar">
              <i /><i /><i />
            </div>
            <pre>
              <span className="cc-prompt">&gt;</span> stores |&gt;{'\n'}
              <span className="cc-prompt">+</span>   slice_max(sales, n = 1){'\n'}
              <span className="cc-out"># 売上1位は… 金沢店！</span>
            </pre>
          </div>
          <span className="sticker sticker-coral hero-badge">ブラウザだけでOK</span>
        </div>
      </section>

      {stages.map((st) => (
        <section key={st.id} className="stage" aria-labelledby={`stage-${st.id}`}>
          <h2 id={`stage-${st.id}`}>
            <span className={`stage-name sticker stage-sticker-${st.id}`}>{st.name}</span>
            {st.title}
            <span className="stage-range">
              ステップ {Number(st.gate) - 26}–{Number(st.gate)}
            </span>
          </h2>
          <div className="parts">
            {parts
              .filter((p) => st.parts.includes(p.id))
              .map((p) => {
                const ready = p.steps.filter((s) => availableIds.has(s.id)).length;
                const pdone = p.steps.filter((s) => progress.steps[s.id]?.done).length;
                return (
                  <article key={p.id} className={`part-card ${ready === 0 ? 'is-pending' : 'tilt'}`}>
                    <h3>
                      <span className="part-no">第{p.id}部</span> {p.title}
                    </h3>
                    <PartMap part={p} progress={progress} />
                    <p className="part-meta">
                      {ready === 0 ? '準備中' : `完了 ${pdone} / 9`}
                    </p>
                    <ul className="step-list">
                      {p.steps.map((s) => (
                        <li key={s.id} className={progress.steps[s.id]?.done ? 'is-done' : ''}>
                          {availableIds.has(s.id) ? (
                            <Link to={`/step/${s.id}`}>
                              <span className="sno">{Number(s.id)}</span>
                              {s.title}
                            </Link>
                          ) : (
                            <span className="is-pending">
                              <span className="sno">{Number(s.id)}</span>
                              {s.title}
                            </span>
                          )}
                          {s.mode === 'local' && <span className="tag tag-local">PCで実行</span>}
                        </li>
                      ))}
                    </ul>
                  </article>
                );
              })}
          </div>
        </section>
      ))}
    </div>
  );
}
