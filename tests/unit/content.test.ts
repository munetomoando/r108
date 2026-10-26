import { describe, expect, it } from 'vitest';
import { execFileSync } from 'node:child_process';

describe('教材', () => {
  it('全ステップがスキーマに合う', () => {
    expect(() => execFileSync('node', ['scripts/validate-content.mjs'], { stdio: 'pipe' })).not.toThrow();
  });
});
