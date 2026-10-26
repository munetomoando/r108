import { useState } from 'react';
import type { Exercise } from '../content/types';
import { checkChoice } from '../runtime/grader';
import Markdown from './Markdown';

type Props = { ex: Exercise; passed: boolean; onResult: (ok: boolean) => void };

export default function Choice({ ex, passed, onResult }: Props) {
  const [selected, setSelected] = useState<number | null>(passed ? (ex.answer ?? null) : null);
  const [result, setResult] = useState<'pass' | 'fail' | null>(passed ? 'pass' : null);
  const name = `choice-${ex.id}`;

  const submit = () => {
    if (selected === null) return;
    const v = checkChoice(ex, selected);
    setResult(v.kind === 'pass' ? 'pass' : 'fail');
    onResult(v.kind === 'pass');
  };

  return (
    <div className="choice">
      <fieldset>
        <legend className="sr-only">選択肢</legend>
        {(ex.choices ?? []).map((c, i) => (
          <label key={i} className={`choice-item ${selected === i ? 'is-selected' : ''}`}>
            <input
              type="radio"
              name={name}
              checked={selected === i}
              onChange={() => {
                setSelected(i);
                if (result === 'fail') setResult(null);
              }}
            />
            <Markdown source={c} inline />
          </label>
        ))}
      </fieldset>
      <div className="actions">
        <button type="button" className="btn btn-primary" onClick={submit} disabled={selected === null}>
          答え合わせ
        </button>
      </div>
      {result === 'pass' && (
        <div className="feedback feedback-pass" role="status">
          <strong>正解です！</strong>
          {ex.explain && <Markdown source={ex.explain} />}
        </div>
      )}
      {result === 'fail' && (
        <div className="feedback feedback-fail" role="status">
          <strong>違います。</strong>もう一度考えてみましょう。
        </div>
      )}
    </div>
  );
}
