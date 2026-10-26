// docs/design.md のステップ一覧表から content/parts.yaml を作る（初回の雛形づくり用）。
import { readFileSync, writeFileSync } from 'node:fs';

const md = readFileSync(new URL('../docs/design.md', import.meta.url), 'utf8');
const stages = [
  { id: 1, name: '第I段階', title: 'データを扱う', gate: '027' },
  { id: 2, name: '第II段階', title: '統計と回帰', gate: '054' },
  { id: 3, name: '第III段階', title: '因果推論と予測', gate: '081' },
  { id: 4, name: '第IV段階', title: 'ビジネスで使う', gate: '108' },
];
const parts = [];
for (const line of md.split('\n')) {
  const cells = line.split(/(?<!\\)\|/).slice(1, -1).map((c) => c.trim());
  if (cells.length < 5) continue;
  const pm = cells[0].match(/^\*\*第(\d+)部\*\*$/);
  if (pm) {
    parts.push({ id: Number(pm[1]), title: cells[1].replace(/\*\*/g, ''), steps: [] });
    continue;
  }
  if (!/^\d+$/.test(cells[0]) || parts.length === 0) continue;
  let raw = cells[1].replace(/\\_/g, '_').replace(/\\\|/g, '|');
  const local = raw.includes('［L］');
  raw = raw.replace('［L］', '');
  const capstone = raw.includes('**総合演習') || raw.includes('**修了課題');
  raw = raw.replace(/\*\*/g, '');
  const [title, ...q] = raw.split('／');
  parts.at(-1).steps.push({
    id: cells[0].padStart(3, '0'),
    title: title.trim(),
    question: q.join('／').trim(),
    mode: local ? 'local' : 'browser',
    capstone,
    learn: cells[2].replace(/\\_/g, '_').replace(/\\\|/g, '|'),
    data: cells[4].replace(/\\_/g, '_'),
  });
}
const q = (s) => JSON.stringify(s);
let out = '# 12部と4段階のメタ情報。scripts/build-catalog.mjs で設計書から作った雛形を手で直して使う。\n';
out += '# ステップの本体は content/steps/<番号>/ にある。フォルダがないステップは「準備中」と表示する。\n';
out += 'stages:\n';
for (const s of stages) out += `  - { id: ${s.id}, name: ${q(s.name)}, title: ${q(s.title)}, parts: [${[1, 2, 3].map((k) => (s.id - 1) * 3 + k).join(', ')}], gate: ${q(s.gate)} }\n`;
out += 'parts:\n';
for (const p of parts) {
  out += `  - id: ${p.id}\n    title: ${q(p.title)}\n    steps:\n`;
  for (const st of p.steps) {
    out += `      - { id: ${q(st.id)}, title: ${q(st.title)}, question: ${q(st.question)}, mode: ${st.mode}${st.capstone ? ', capstone: true' : ''} }\n`;
  }
}
writeFileSync(new URL('../content/parts.yaml', import.meta.url), out);
const n = parts.reduce((a, p) => a + p.steps.length, 0);
console.log(`parts: ${parts.length}, steps: ${n}, local: ${parts.flatMap((p) => p.steps).filter((s) => s.mode === 'local').map((s) => s.id).join(',')}`);
