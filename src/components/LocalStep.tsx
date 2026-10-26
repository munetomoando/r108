import { useState } from 'react';
import type { Step } from '../content/types';
import { sha256Hex } from '../runtime/grader';
import { completeLocal } from '../store/progress';
import Markdown from './Markdown';

/** ローカル実行ステップ: 確認スクリプトを配り、表示された修了コードを照合する */
export default function LocalStep({ step, done, savedCode }: { step: Step; done: boolean; savedCode?: string }) {
  const [code, setCode] = useState(savedCode ?? '');
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const local = step.local;
  if (!local) return <p className="note">このステップの確認スクリプトは準備中です。</p>;
  const url = `${import.meta.env.BASE_URL}local/${local.script}`;

  const submit = async () => {
    const h = await sha256Hex(code);
    if (h === local.code_sha256) {
      completeLocal(step.id, code.trim().toUpperCase());
      setMsg({ ok: true, text: '修了コードを確認しました。このステップは完了です。' });
    } else {
      setMsg({ ok: false, text: 'コードが一致しません。確認スクリプトが表示したコードを、そのまま貼り付けてください。' });
    }
  };

  return (
    <section className="exercise local" aria-labelledby="local-head">
      <h3 id="local-head">自分のPCで確認する</h3>
      <ol className="local-steps">
        <li>
          確認スクリプト <a href={url} download>{local.script}</a> をダウンロードします。
        </li>
        <li>RStudio か Positron で、作業中のプロジェクトを開いた状態で実行します。</li>
        <li>合格すると「R108-…」で始まる修了コードが表示されます。下に貼り付けてください。</li>
      </ol>
      {local.instructions && <Markdown source={local.instructions} />}
      <div className="local-form">
        <label htmlFor="local-code">修了コード</label>
        <input
          id="local-code"
          value={code}
          placeholder={`R108-${step.id}-XXXX`}
          onChange={(e) => setCode(e.target.value)}
          disabled={done}
        />
        <button type="button" className="btn btn-primary" onClick={submit} disabled={done || !code.trim()}>
          照合する
        </button>
      </div>
      {(msg || done) && (
        <div className={`feedback ${msg && !msg.ok ? 'feedback-fail' : 'feedback-pass'}`} role="status">
          {msg?.text ?? '修了コードを確認済みです。'}
        </div>
      )}
    </section>
  );
}
