// content/ の YAML を JSON Schema で検証し、parts.yaml との整合を確かめる。
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import Ajv from 'ajv';
import YAML from 'yaml';

const root = new URL('..', import.meta.url).pathname;
const schema = JSON.parse(readFileSync(join(root, 'schema/step.schema.json'), 'utf8'));
const validate = new Ajv({ allErrors: true }).compile(schema);
const parts = YAML.parse(readFileSync(join(root, 'content/parts.yaml'), 'utf8')).parts;
const catalog = new Map(parts.flatMap((p) => p.steps.map((s) => [s.id, { ...s, part: p.id }])));

let errors = 0;
const fail = (where, msg) => { errors++; console.error(`✗ ${where}: ${msg}`); };
const stepsDir = join(root, 'content/steps');
const ids = readdirSync(stepsDir).filter((d) => /^\d{3}$/.test(d)).sort();
for (const id of ids) {
  const file = join(stepsDir, id, 'step.yaml');
  if (!existsSync(file)) { fail(id, 'step.yaml がありません'); continue; }
  const step = YAML.parse(readFileSync(file, 'utf8'));
  if (!validate(step)) {
    for (const e of validate.errors) fail(`${id}/step.yaml${e.instancePath}`, e.message);
  }
  if (step.id !== id) fail(id, `id が ${step.id} になっています`);
  const cat = catalog.get(id);
  if (!cat) fail(id, 'parts.yaml にありません');
  else if (cat.part !== step.part) fail(id, `part が parts.yaml (${cat.part}) と違います`);
  if (step.mode === 'browser' && !existsSync(join(stepsDir, id, 'body.md'))) fail(id, 'body.md がありません');
  const exIds = (step.exercises ?? []).map((e) => e.id);
  if (new Set(exIds).size !== exIds.length) fail(id, '小課題の id が重複しています');
  for (const d of step.data ?? []) {
    if (!existsSync(join(root, 'public/data', d))) fail(id, `public/data/${d} がありません`);
  }
}
console.log(errors ? `\n${errors} 件のエラー` : `✓ ${ids.length} ステップを検証しました`);
process.exit(errors ? 1 : 0);
