import { useEffect, useRef } from 'react';
import { EditorView, keymap, lineNumbers, highlightActiveLine, placeholder } from '@codemirror/view';
import { EditorState } from '@codemirror/state';
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
import { StreamLanguage, syntaxHighlighting, HighlightStyle, bracketMatching, indentUnit } from '@codemirror/language';
import { tags as t } from '@lezer/highlight';
import { r } from '@codemirror/legacy-modes/mode/r';

type Props = {
  value: string;
  onChange: (v: string) => void;
  onRun?: () => void;
  ariaLabel: string;
  minLines?: number;
};

// 色は styles.css のトークンを使い、ライトとダークの両方で読めるようにする
const highlight = HighlightStyle.define([
  { tag: t.comment, color: 'var(--hl-comment)', fontStyle: 'italic' },
  { tag: [t.keyword, t.controlKeyword, t.operatorKeyword], color: 'var(--hl-keyword)', fontWeight: '700' },
  { tag: [t.string, t.special(t.string)], color: 'var(--hl-string)' },
  { tag: [t.number, t.bool, t.null, t.atom], color: 'var(--hl-number)' },
  { tag: [t.operator], color: 'var(--hl-operator)' },
]);

const theme = EditorView.theme({
  '&': { fontSize: '14px', border: '2px solid var(--line)', borderRadius: '10px', background: 'var(--code-bg)', overflow: 'hidden' },
  '&.cm-focused': { outline: '3px solid var(--accent)', outlineOffset: '2px' },
  '.cm-content': { fontFamily: 'var(--mono)', caretColor: 'var(--ink)' },
  '.cm-gutters': { background: 'transparent', border: 'none', color: 'var(--muted)' },
  '.cm-activeLine': { background: 'var(--code-active)' },
});

export default function CodeEditor({ value, onChange, onRun, ariaLabel, minLines = 4 }: Props) {
  const host = useRef<HTMLDivElement>(null);
  const view = useRef<EditorView | null>(null);
  const runRef = useRef(onRun);
  const changeRef = useRef(onChange);
  runRef.current = onRun;
  changeRef.current = onChange;

  useEffect(() => {
    if (!host.current) return;
    const runKey = {
      key: 'Mod-Enter',
      preventDefault: true,
      run: () => {
        runRef.current?.();
        return true;
      },
    };
    view.current = new EditorView({
      parent: host.current,
      state: EditorState.create({
        doc: value,
        extensions: [
          keymap.of([runKey, indentWithTab, ...defaultKeymap, ...historyKeymap]),
          history(),
          lineNumbers(),
          highlightActiveLine(),
          bracketMatching(),
          indentUnit.of('  '),
          StreamLanguage.define(r),
          syntaxHighlighting(highlight),
          placeholder('ここにRのコードを書きます'),
          theme,
          EditorView.contentAttributes.of({ 'aria-label': ariaLabel }),
          EditorView.updateListener.of((u) => {
            if (u.docChanged) changeRef.current(u.state.doc.toString());
          }),
          EditorView.theme({ '.cm-content': { minHeight: `${minLines * 1.45}em` } }),
        ],
      }),
    });
    return () => view.current?.destroy();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 外から値が変わったとき（初期コードに戻す等）だけ反映する
  useEffect(() => {
    const v = view.current;
    if (v && v.state.doc.toString() !== value) {
      v.dispatch({ changes: { from: 0, to: v.state.doc.length, insert: value } });
    }
  }, [value]);

  return <div ref={host} className="editor" />;
}
