import { useEffect, useRef } from 'react';
import type { RunResult } from '../runtime/webr';

function Plot({ image, index }: { image: ImageBitmap; index: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const c = ref.current;
    if (!c) return;
    c.width = image.width;
    c.height = image.height;
    c.getContext('2d')?.drawImage(image, 0, 0);
  }, [image]);
  return <canvas ref={ref} className="plot" role="img" aria-label={`図 ${index + 1}`} />;
}

export default function OutputPane({ run }: { run?: RunResult }) {
  if (!run) return null;
  const lines = run.lines.filter((l) => l.text.trim() !== '' && l.type !== 'error');
  if (lines.length === 0 && run.images.length === 0) {
    return (
      <div className="output output-empty" aria-live="polite">
        （表示される出力はありません）
      </div>
    );
  }
  return (
    <div className="output" aria-live="polite">
      {lines.length > 0 && (
        <pre className="console">
          {lines.map((l, i) => (
            <span key={i} className={`line line-${l.type}`}>
              {l.type === 'warning' ? `警告: ${l.text}` : l.text}
              {'\n'}
            </span>
          ))}
        </pre>
      )}
      {run.images.map((im, i) => (
        <Plot key={i} image={im} index={i} />
      ))}
    </div>
  );
}
