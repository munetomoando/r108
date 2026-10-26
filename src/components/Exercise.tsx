import { useState } from 'react';
import type { Exercise as Ex, Step } from '../content/types';
import { isChoice, typeLabel } from '../content/types';
import { checkFreeText, runAndCheck, tryRun } from '../runtime/grader';
import type { Attempt } from '../runtime/grader';
import { restartR } from '../runtime/webr';
import { saveCode } from '../store/progress';
import CodeEditor from './CodeEditor';
import OutputPane from './OutputPane';
import Hints from './Hints';
import Choice from './Choice';
import Markdown from './Markdown';

type Props = {
  step: Step;
  ex: Ex;
  passed: boolean;
  savedCode?: string;
  onResult: (ok: boolean) => void;
};

function Feedback({ attempt }: { attempt: Attempt }) {
  const v = attempt.verdict;
  if (v.kind === 'pass') {
    return (
      <div className="feedback feedback-pass" role="status">
        <strong>正解です！</strong>
      </div>
    );
  }
  if (v.kind === 'fail') {
    return (
      <div className="feedback feedback-fail" role="status">
        <strong>まだ違います。</strong>
        {v.message}
      </div>
    );
  }
  return (
    <div className="feedback feedback-error" role="alert">
      <strong>エラーが出ました。</strong>
      {v.ja ?? 'メッセージを手がかりにコードを見直しましょう。'}
      <div className="raw-error">
        <span>R のメッセージ:</span> <code>{v.message}</code>
        {v.call && (
          <>
            {' '}
            <span>（{v.call} のところ）</span>
          </>
        )}
      </div>
    </div>
  );
}

function CodeExercise({ step, ex, passed, savedCode, onResult }: Props) {
  const initial = ex.starter ?? '';
  const [code, setCode] = useState(savedCode ?? initial);
  const [busy, setBusy] = useState(false);
  const [attempt, setAttempt] = useState<Attempt | null>(null);
  const [checked, setChecked] = useState(false);
  const [tries, setTries] = useState(0);
  const [showSolution, setShowSolution] = useState(false);
  const [open, setOpen] = useState(() => typeof window === 'undefined' || window.innerWidth >= 600);

  const change = (v: string) => {
    setCode(v);
    saveCode(step.id, ex.id, v);
  };

  const exec = async (judge: boolean) => {
    if (busy) return;
    setBusy(true);
    try {
      const a = judge ? await runAndCheck(step, ex, code) : await tryRun(step, ex, code);
      setAttempt(a);
      setChecked(judge);
      if (judge) {
        setTries((t) => t + 1);
        onResult(a.verdict.kind === 'pass');
      }
    } catch (e) {
      setAttempt({
        verdict: { kind: 'error', message: String((e as Error)?.message ?? e), ja: 'R の実行環境で問題が起きました。「R を再起動」を試してください。' },
      });
    } finally {
      setBusy(false);
    }
  };

  if (!open) {
    return (
      <button type="button" className="btn" onClick={() => setOpen(true)}>
        コードを書く（PCでの利用をおすすめします）
      </button>
    );
  }

  return (
    <div className="code-exercise">
      <CodeEditor value={code} onChange={change} onRun={() => exec(true)} ariaLabel={`小課題 ${ex.id} のコード`} />
      <div className="actions">
        <button type="button" className="btn btn-primary" onClick={() => exec(true)} disabled={busy}>
          {busy ? '実行中…' : '実行して判定'}
          <kbd>Ctrl/⌘+Enter</kbd>
        </button>
        <button type="button" className="btn" onClick={() => exec(false)} disabled={busy}>
          試しに実行
        </button>
        <button
          type="button"
          className="btn btn-quiet"
          onClick={() => change(initial)}
          disabled={busy || code === initial}
        >
          初期コードに戻す
        </button>
        {busy && (
          <button type="button" className="btn btn-quiet" onClick={() => restartR()} title="止まらないときに使います">
            R を再起動
          </button>
        )}
      </div>
      {attempt?.prepared && attempt.prepared.length > 0 && (
        <p className="note">
          準備として、小課題 {attempt.prepared.join('・')} の解答例を先に実行しました。
        </p>
      )}
      {attempt && (checked || attempt.verdict.kind === 'error') && <Feedback attempt={attempt} />}
      <OutputPane run={attempt?.run} />
      <Hints hints={ex.hints ?? []} />
      {(passed || tries >= 3) && ex.solution && (
        <div className="solution">
          <button type="button" className="btn btn-quiet" onClick={() => setShowSolution(!showSolution)}>
            {showSolution ? '解答例を隠す' : '解答例を見る'}
          </button>
          {showSolution && <pre className="code-block solution-code">{ex.solution}</pre>}
        </div>
      )}
    </div>
  );
}

function FreeText({ step, ex, passed, savedCode, onResult }: Props) {
  const [text, setText] = useState(savedCode ?? '');
  const [busy, setBusy] = useState(false);
  const [attempt, setAttempt] = useState<Attempt | null>(null);
  const [showModel, setShowModel] = useState(false);
  const submit = async () => {
    setBusy(true);
    try {
      const a = await checkFreeText(step, ex, text);
      setAttempt(a);
      onResult(a.verdict.kind === 'pass');
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="free-text">
      <textarea
        value={text}
        rows={5}
        aria-label={`小課題 ${ex.id} の回答`}
        placeholder="ここに文章で書きます"
        onChange={(e) => {
          setText(e.target.value);
          saveCode(step.id, ex.id, e.target.value);
        }}
      />
      <div className="actions">
        <button type="button" className="btn btn-primary" onClick={submit} disabled={busy || !text.trim()}>
          {busy ? '確認中…' : '回答を確認'}
        </button>
      </div>
      {attempt && <Feedback attempt={attempt} />}
      <Hints hints={ex.hints ?? []} />
      {passed && ex.solution && (
        <div className="solution">
          <button type="button" className="btn btn-quiet" onClick={() => setShowModel(!showModel)}>
            {showModel ? '模範解答を隠す' : '模範解答を見る'}
          </button>
          {showModel && <Markdown source={ex.solution} />}
        </div>
      )}
    </div>
  );
}

export default function Exercise(props: Props) {
  const { ex, passed } = props;
  return (
    <section className={`exercise ${passed ? 'is-passed' : ''}`} aria-labelledby={`ex-${ex.id}`}>
      <header className="exercise-head">
        <h3 id={`ex-${ex.id}`}>
          小課題 {ex.id}
          <span className="tag">{ex.review ? '復習' : typeLabel[ex.type]}</span>
        </h3>
        {passed && <span className="done-mark">✓ 正解済み</span>}
      </header>
      <Markdown source={ex.prompt} />
      {isChoice(ex) ? (
        <Choice ex={ex} passed={passed} onResult={props.onResult} />
      ) : ex.free ? (
        <FreeText {...props} />
      ) : (
        <CodeExercise {...props} />
      )}
    </section>
  );
}
