import { beforeEach, describe, expect, it } from 'vitest';
import {
  _resetForTest, doneCount, exportJson, getProgress, importJson, normalize, nowIso, recordResult, saveCode,
} from '../../src/store/progress';

describe('進捗の保存', () => {
  beforeEach(() => _resetForTest());

  it('全問正解でステップが完了する', () => {
    recordResult('001', 'a', true, ['a', 'b']);
    expect(getProgress().steps['001'].done).toBe(false);
    recordResult('001', 'b', true, ['a', 'b']);
    expect(getProgress().steps['001'].done).toBe(true);
    expect(getProgress().steps['001'].doneAt).toMatch(/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$/);
    expect(doneCount()).toBe(1);
  });

  it('一度正解した小課題は、後で間違えても正解のまま', () => {
    recordResult('002', 'a', true, ['a']);
    recordResult('002', 'a', false, ['a']);
    expect(getProgress().steps['002'].exercises.a).toBe(true);
  });

  it('書き出した JSON を読み込める（設計書の形）', () => {
    saveCode('003', 'a', 'x <- 1');
    recordResult('003', 'a', true, ['a']);
    const json = exportJson();
    _resetForTest();
    importJson(json);
    expect(getProgress().steps['003']).toMatchObject({ done: true, exercises: { a: true }, code: { a: 'x <- 1' } });
    expect(JSON.parse(json)).toHaveProperty('version', 1);
  });

  it('合わせて読み込むと、両方の完了が残る', () => {
    recordResult('001', 'a', true, ['a']);
    const other = { version: 1, steps: { '002': { done: true, exercises: { a: true }, code: {} } }, localCodes: { '050': 'R108-050-7F3A' } };
    importJson(JSON.stringify(other));
    expect(doneCount()).toBe(2);
    expect(getProgress().localCodes['050']).toBe('R108-050-7F3A');
  });

  it('版の違う JSON は拒否する', () => {
    expect(() => normalize({ version: 2, steps: {} })).toThrow();
  });

  it('日本時間のオフセット付き時刻', () => {
    expect(nowIso(new Date('2026-11-02T01:15:00Z'))).toMatch(/T\d\d:15:00[+-]\d\d:\d\d$/);
  });
});
