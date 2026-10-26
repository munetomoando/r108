import { useState } from 'react';
import Markdown from './Markdown';

const labels = ['ヒント1（方針）', 'ヒント2（使う関数）', 'ヒント3（ほぼ答え）'];

export default function Hints({ hints }: { hints: string[] }) {
  const [shown, setShown] = useState(0);
  if (hints.length === 0) return null;
  return (
    <div className="hints">
      {hints.slice(0, shown).map((h, i) => (
        <div key={i} className="hint">
          <span className="hint-label">{labels[i] ?? `ヒント${i + 1}`}</span>
          <Markdown source={h} inline />
        </div>
      ))}
      {shown < hints.length && (
        <button type="button" className="btn btn-quiet" onClick={() => setShown(shown + 1)}>
          {labels[shown] ?? 'ヒント'}を見る
        </button>
      )}
    </div>
  );
}
