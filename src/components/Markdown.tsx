import { useMemo } from 'react';
import MarkdownIt from 'markdown-it';
import katex from 'katex';
import 'katex/dist/katex.min.css';

// $...$ と $$...$$ を KaTeX で描く小さなプラグイン
type MD = InstanceType<typeof MarkdownIt>;
type StateInline = Parameters<Parameters<MD['inline']['ruler']['after']>[2]>[0];
type Token = ReturnType<MD['parse']>[number];

function mathPlugin(md: MD) {
  md.inline.ruler.after('escape', 'math_inline', (state: StateInline, silent: boolean) => {
    const src = state.src;
    const start = state.pos;
    if (src[start] !== '$') return false;
    const display = src[start + 1] === '$';
    const open = display ? 2 : 1;
    const end = src.indexOf(display ? '$$' : '$', start + open);
    if (end < 0 || end === start + open) return false;
    // Pandoc と同じく、$ の内側の端が空白のもの・閉じ $ の直後が数字のものは数式とみなさない
    if (!display && (/\s/.test(src[start + 1]) || /\s/.test(src[end - 1]) || /\d/.test(src[end + 1] ?? ''))) {
      return false;
    }
    if (!silent) {
      const t = state.push('math', '', 0);
      t.content = src.slice(start + open, end);
      t.meta = { display };
    }
    state.pos = end + open;
    return true;
  });
  md.renderer.rules.math = (tokens: Token[], i: number) => {
    const t = tokens[i];
    return katex.renderToString(t.content, { displayMode: Boolean(t.meta?.display), throwOnError: false });
  };
}

const md = new MarkdownIt({ html: false, linkify: true, typographer: false }).use(mathPlugin);
// コードブロックを横スクロールできる枠で包む
const defaultFence = md.renderer.rules.fence!;
md.renderer.rules.fence = (tokens, idx, options, env, self) => {
  const html = defaultFence(tokens, idx, options, env, self);
  return `<div class="code-block">${html}</div>`;
};
const defaultLink = md.renderer.rules.link_open;
md.renderer.rules.link_open = (tokens, idx, options, env, self) => {
  const href = String(tokens[idx].attrGet('href') ?? '');
  if (/^https?:/.test(href)) {
    tokens[idx].attrSet('target', '_blank');
    tokens[idx].attrSet('rel', 'noopener');
  }
  // アプリが配るファイル（data/ のデータ、local/ の確認スクリプトや雛形）はダウンロードさせる
  if (/^(data|local)\/[^/]+$/.test(href)) tokens[idx].attrSet('download', '');
  return defaultLink ? defaultLink(tokens, idx, options, env, self) : self.renderToken(tokens, idx, options);
};

export default function Markdown({ source, inline = false }: { source: string; inline?: boolean }) {
  const html = useMemo(() => (inline ? md.renderInline(source) : md.render(source)), [source, inline]);
  if (inline) return <span dangerouslySetInnerHTML={{ __html: html }} />;
  return <div className="prose" dangerouslySetInnerHTML={{ __html: html }} />;
}
