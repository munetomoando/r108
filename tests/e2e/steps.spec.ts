import { test, expect, type Page } from '@playwright/test';
import { readFileSync, readdirSync } from 'node:fs';
import YAML from 'yaml';

type Ex = { id: string; solution?: string; choices?: string[]; answer?: number; free?: boolean; tests?: { fail?: string[] } };
const loadStep = (id: string) =>
  YAML.parse(readFileSync(new URL(`../../content/steps/${id}/step.yaml`, import.meta.url), 'utf8')) as {
    mode?: 'browser' | 'local';
    exercises: Ex[];
  };

async function typeCode(page: Page, exId: string, code: string) {
  const ed = page.getByRole('textbox', { name: `小課題 ${exId} のコード` });
  await ed.click();
  await page.keyboard.press('ControlOrMeta+a');
  await page.keyboard.press('Delete');
  await page.keyboard.insertText(code);
}

const section = (page: Page, exId: string) => page.locator('section.exercise', { has: page.locator(`#ex-${exId}`) });

test('目次に108ステップが並び、第1部が開ける', async ({ page }) => {
  await page.goto('./');
  await expect(page.getByRole('heading', { name: 'Rデータ分析 108ステップ', level: 1 })).toBeVisible();
  await expect(page.locator('.step-list li')).toHaveCount(108);
  await page.getByRole('link', { name: 'ステップ1から始める' }).click();
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Rを電卓として使う');
});

test('ステップ1: 正解・不正解・エラーを判定する', async ({ page }) => {
  const step = loadStep('001');
  const a = step.exercises.find((e) => e.id === 'a')!;
  await page.goto('./#/step/001');
  const sec = section(page, 'a');
  // 不正解
  await typeCode(page, 'a', a.tests!.fail![0]);
  await sec.getByRole('button', { name: /実行して判定/ }).click();
  await expect(sec.locator('.feedback-fail')).toBeVisible();
  // エラー（日本語の説明が出る）
  await typeCode(page, 'a', 'price_tax <- pricee * 1.1');
  await sec.getByRole('button', { name: /実行して判定/ }).click();
  await expect(sec.locator('.feedback-error')).toContainText('オブジェクト pricee が見つかりません');
  // 正解（Ctrl/Cmd+Enter でも実行できる）
  await typeCode(page, 'a', a.solution!);
  await page.keyboard.press('ControlOrMeta+Enter');
  await expect(sec.locator('.feedback-pass')).toBeVisible();
  await expect(sec.getByText('✓ 正解済み')).toBeVisible();
});

test('ステップ3: パッケージとデータを読み込み、全小課題に正解すると完了する', async ({ page }) => {
  const step = loadStep('003');
  await page.goto('./#/step/003');
  for (const ex of step.exercises) {
    const sec = section(page, ex.id);
    if (ex.choices) {
      await sec.locator('.choice-item').nth(ex.answer!).click();
      await sec.getByRole('button', { name: '答え合わせ' }).click();
    } else {
      await typeCode(page, ex.id, ex.solution!);
      await sec.getByRole('button', { name: /実行して判定/ }).click();
    }
    await expect(sec.locator('.feedback-pass').first()).toBeVisible();
  }
  await expect(page.getByText('このステップは完了です。')).toBeVisible();
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem('r108.v1') ?? '{}'));
  expect(saved.steps['003'].done).toBe(true);
  // 再読み込みしても完了が残る
  await page.reload();
  await expect(page.getByText('このステップは完了です。')).toBeVisible();
});

test('ステップ9: 前の小課題を飛ばしても準備して判定し、記述式も判定する', async ({ page }) => {
  const step = loadStep('009');
  const code = step.exercises.filter((e) => e.solution && !e.free);
  const last = code.at(-1)!;
  await page.goto('./#/step/009');
  const sec = section(page, last.id);
  await typeCode(page, last.id, last.solution!);
  await sec.getByRole('button', { name: /実行して判定/ }).click();
  await expect(sec.locator('.feedback-pass')).toBeVisible();
  const free = step.exercises.find((e) => e.free);
  if (free) {
    const fs = section(page, free.id);
    await fs.getByRole('textbox').fill('短い');
    await fs.getByRole('button', { name: '回答を確認' }).click();
    await expect(fs.locator('.feedback-fail')).toBeVisible();
    await fs.getByRole('textbox').fill(free.solution!);
    await fs.getByRole('button', { name: '回答を確認' }).click();
    await expect(fs.locator('.feedback-pass')).toBeVisible();
  }
});

test('自由に試す: 1 + 1 と ggplot の図が表示され、起動秒数が出る', async ({ page }) => {
  await page.goto('./#/playground');
  await page.getByRole('button', { name: /^実行/ }).click();
  await expect(page.locator('.console')).toContainText('[1] 2');
  await expect(page.locator('canvas.plot')).toHaveCount(1);
  await expect(page.getByText(/R の起動にかかった時間/)).toBeVisible();
});

// 実装済みの全ステップの全小課題を、ブラウザの webR で正解コードを入れて確かめる（通常の R との差を検出する）
// E2E_STEPS=010,012 のように指定すると一部だけ確かめる
// ローカル実行ステップ（mode: local）は小課題がないので除き、下の修了コードのテストで確かめる
const allIds = readdirSync(new URL('../../content/steps/', import.meta.url))
  .filter((d) => /^\d{3}$/.test(d) && loadStep(d).mode !== 'local')
  .sort();
const ids = process.env.E2E_STEPS ? process.env.E2E_STEPS.split(',') : allIds;
for (const id of ids) {
  test(`ステップ${Number(id)}: 全小課題が解答例で正解になる（webR）`, async ({ page }) => {
    const step = loadStep(id);
    await page.goto(`./#/step/${id}`);
    for (const ex of step.exercises) {
      const sec = section(page, ex.id);
      if (ex.choices) {
        await sec.locator('.choice-item').nth(ex.answer!).click();
        await sec.getByRole('button', { name: '答え合わせ' }).click();
      } else if (ex.free) {
        await sec.getByRole('textbox').fill(ex.solution!);
        await sec.getByRole('button', { name: '回答を確認' }).click();
      } else {
        await typeCode(page, ex.id, ex.solution!);
        await sec.getByRole('button', { name: /実行して判定/ }).click();
      }
      await expect(sec.locator('.feedback-pass').first(), `小課題 ${ex.id}`).toBeVisible();
    }
    await expect(page.getByText('このステップは完了です。')).toBeVisible();
  });
}

test('ローカル実行ステップ: 修了コードを照合して完了にする', async ({ page }) => {
  await page.goto('./#/step/050');
  await expect(page.getByRole('link', { name: 'check_050.R' })).toBeVisible();
  const input = page.getByLabel('修了コード');
  const btn = page.getByRole('button', { name: '照合する' });
  await input.fill('R108-050-0000');
  await btn.click();
  await expect(page.locator('.feedback-fail')).toContainText('一致しません');
  // 小文字・前後の空白は許す
  await input.fill(' r108-050-7f3a ');
  await btn.click();
  await expect(page.locator('.local-form ~ .feedback-pass')).toContainText('完了です');
});
