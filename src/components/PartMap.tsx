import { Link } from 'react-router-dom';
import type { Part } from '../content/types';
import { availableIds } from '../content/loader';
import type { Progress } from '../store/progress';

/** 1つの部の9ステップを、完了状況つきで並べる */
export default function PartMap({ part, progress, current }: { part: Part; progress: Progress; current?: string }) {
  return (
    <ol className="part-map" aria-label={`第${part.id}部のステップ`}>
      {part.steps.map((s, i) => {
        const done = progress.steps[s.id]?.done;
        const ready = availableIds.has(s.id);
        const cls = ['pm-step', done && 'is-done', !ready && 'is-pending', s.id === current && 'is-current', s.capstone && 'is-capstone']
          .filter(Boolean)
          .join(' ');
        const label = `${Number(s.id)}. ${s.title}${done ? '（完了）' : ready ? '' : '（準備中）'}`;
        return (
          <li key={s.id} className={cls}>
            {ready ? (
              <Link to={`/step/${s.id}`} title={label} aria-label={label} aria-current={s.id === current ? 'step' : undefined}>
                {i + 1}
              </Link>
            ) : (
              <span title={label} aria-label={label}>
                {i + 1}
              </span>
            )}
          </li>
        );
      })}
    </ol>
  );
}
