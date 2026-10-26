import { describe, expect, it } from 'vitest';
import { parseStatus, translateError } from '../../src/runtime/errors';

describe('R のエラーの日本語化', () => {
  it('object not found', () => {
    expect(translateError("object 'x' not found")).toContain('オブジェクト x が見つかりません');
  });
  it('could not find function', () => {
    expect(translateError('could not find function "fliter"')).toContain('関数 fliter()');
  });
  it('%>% は |> への書き換えを促す', () => {
    expect(translateError('could not find function "%>%"')).toContain('|>');
  });
  it('= と == の取り違え', () => {
    expect(translateError("<text>:1:24: unexpected '='")).toContain('==');
  });
  it('データの文字コードの誤りは locale を促す（全角記号の注意と区別する）', () => {
    expect(translateError('invalid multibyte string, element 1')).toContain('CP932');
    expect(translateError('<text>:1:5: unexpected input')).toContain('全角');
  });
  it('知らないエラーは null', () => {
    expect(translateError('something odd')).toBeNull();
  });
  it('状態文字列を分解する', () => {
    expect(parseStatus('ok')).toEqual({ kind: 'ok' });
    const s = parseStatus("error\tobject 'y' not found\tmean(y)");
    expect(s).toMatchObject({ kind: 'error', message: "object 'y' not found", call: 'mean(y)' });
  });
});
