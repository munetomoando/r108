import { useEffect, useState } from 'react';
import { subscribeRuntime, restartR } from '../runtime/webr';
import type { RuntimeState } from '../runtime/webr';

export default function RuntimeStatus() {
  const [s, setS] = useState<RuntimeState | null>(null);
  useEffect(() => subscribeRuntime(setS), []);
  if (!s) return null;
  return (
    <div className={`runtime runtime-${s.phase}`} role="status" aria-live="polite">
      <span className="runtime-dot" aria-hidden="true" />
      <span className="runtime-msg">{s.message}</span>
      {s.phase === 'failed' && (
        <button type="button" className="btn btn-quiet" onClick={() => restartR()}>
          再試行
        </button>
      )}
    </div>
  );
}
