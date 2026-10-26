// r/r108check/R/*.R を1つにまとめ、webR が起動時に読む public/r/r108check.R を作る。
// あわせて local-src/ からローカル実行ステップの確認スクリプト public/local/check_0XX.R を作る。
import { readdirSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const dir = join(root, 'r/r108check/R');
const files = readdirSync(dir).filter((f) => f.endsWith('.R')).sort();
const body = files.map((f) => `# ---- ${f} ----\n${readFileSync(join(dir, f), 'utf8')}`).join('\n');
mkdirSync(join(root, 'public/r'), { recursive: true });
writeFileSync(join(root, 'public/r/r108check.R'), `# 自動生成（scripts/build-r.mjs）。編集は r/r108check/R/ で行う。\n${body}`);
console.log(`public/r/r108check.R ← ${files.join(', ')}`);

// ローカル実行ステップの確認スクリプト: local-src/_common.R ＋ local-src/check_0XX.R → public/local/check_0XX.R
// 全体を local({ ... }) で包み、学生のグローバル環境に関数や変数を残さない。
const localDir = join(root, 'local-src');
const common = readFileSync(join(localDir, '_common.R'), 'utf8');
const checks = readdirSync(localDir).filter((f) => /^check_\d{3}\.R$/.test(f)).sort();
mkdirSync(join(root, 'public/local'), { recursive: true });
for (const f of checks) {
  const step = f.match(/\d{3}/)[0];
  const src = readFileSync(join(localDir, f), 'utf8');
  const out = [
    `# R108 ステップ${Number(step)} 確認スクリプト（${f}）`,
    '# 使い方: このファイルをプロジェクトのフォルダに置き、R のコンソールで',
    `#   source("${f}", encoding = "UTF-8")`,
    '# を実行します。あなたの PC のファイルは書き換えません（レンダリングの出力を除く）。',
    '# 自動生成（scripts/build-r.mjs）。編集は local-src/ で行う。',
    'local({',
    common.trimEnd(),
    '',
    `# ---- ${f} ----`,
    src.trimEnd(),
    '})',
    '',
  ].join('\n');
  writeFileSync(join(root, 'public/local', f), out);
}
console.log(`public/local/ ← ${checks.join(', ') || '(なし)'}`);
