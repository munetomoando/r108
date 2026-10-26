// R のエラーメッセージを、初学者向けの日本語の説明に置き換える。
// 上から順に照合し、最初に当たったものを使う。当たらなければ原文だけを示す。

type Rule = { re: RegExp; ja: (m: RegExpMatchArray) => string };

const rules: Rule[] = [
  {
    re: /could not find function "%>%"/,
    ja: () => 'この教材ではパイプは |> を使います。%>% を |> に書き換えましょう。',
  },
  {
    re: /object '([^']+)' not found/,
    ja: (m) => `オブジェクト ${m[1]} が見つかりません。綴り（大文字・小文字も）と、前の行や前の小課題を実行したかを確認しましょう。`,
  },
  {
    re: /could not find function "([^"]+)"/,
    ja: (m) =>
      `関数 ${m[1]}() が見つかりません。関数名の綴りを確認しましょう。パッケージの関数なら library() で読み込む必要があります。`,
  },
  {
    re: /there is no package called [‘'"]([^’'"]+)[’'"]/,
    ja: (m) => `パッケージ ${m[1]} がありません。このステップでは使えないか、名前の綴りが違います。`,
  },
  {
    re: /unexpected '='/,
    ja: () => '予期しない「=」があります。条件で「等しい」を表すときは == （イコール2つ）を使います。',
  },
  {
    re: /unexpected (symbol|numeric constant|string constant)/,
    ja: () =>
      'コードの書き方（文法）が正しくありません。カンマ（,）や演算子が抜けていないか、全角文字が混ざっていないかを確認しましょう。',
  },
  {
    re: /unexpected end of input|INCOMPLETE_STRING|unexpected INCOMPLETE/,
    ja: () => 'コードが途中で終わっています。かっこ ( ) や引用符 " " が閉じているかを確認しましょう。',
  },
  {
    re: /unexpected '\)'/,
    ja: () => '閉じかっこ ) が多すぎます。かっこの数が対応しているかを確認しましょう。',
  },
  {
    // 実行時の「invalid multibyte string」は、コードではなく読み込んだデータの文字コードが原因のことが多い（第11ステップ）
    re: /invalid multibyte string|invalid input .* in 'utf8towcs'/,
    ja: () =>
      '文字として読めないデータがあります。コードの書き間違いではなく、ファイルの文字コードが原因のことが多いです。Shift-JIS のファイルなら read_csv() に locale = locale(encoding = "CP932") を付けて読み直しましょう。',
  },
  {
    re: /unexpected input|invalid multibyte|unexpected invalid token/,
    ja: () => '使えない文字が含まれています。全角のスペース・かっこ・記号が混ざっていないかを確認しましょう。',
  },
  {
    re: /unexpected '(.+?)'/,
    ja: (m) => `予期しない「${m[1]}」があります。その前後の書き方（かっこ・カンマ）を確認しましょう。`,
  },
  {
    re: /non-numeric argument to binary operator/,
    ja: () => '数値でないもの（文字など）で計算しようとしています。計算に使っている値の型を class() で確かめましょう。',
  },
  {
    re: /argument "([^"]+)" is missing, with no default/,
    ja: (m) => `関数に必要な引数 ${m[1]} が渡されていません。`,
  },
  {
    re: /unused argument/,
    ja: () => 'その関数が受け付けない引数を渡しています。引数の名前の綴りや、かっこの位置を確認しましょう。',
  },
  {
    re: /Column `([^`]+)` doesn't exist/,
    ja: (m) => `列 ${m[1]} がデータにありません。names() で列名を確かめましょう。`,
  },
  {
    re: /`([^`]+)` not found/,
    ja: (m) => `列またはオブジェクト ${m[1]} が見つかりません。列名の綴りを names() で確かめましょう。`,
  },
  {
    re: /Did you mean `([^`]+)`\?|Did you use `=` instead of `==`\?/,
    ja: () => 'filter() の条件に「=」を使っていませんか。等しいかどうかは == で比べます。',
  },
  {
    re: /cannot open the connection|does not exist in current working directory|'([^']+)' does not exist/,
    ja: () => 'ファイルが見つかりません。ファイル名とフォルダ（data/ など）の綴りを確認しましょう。',
  },
  {
    re: /subscript out of bounds/,
    ja: () => '存在しない位置（番号）を取り出そうとしています。長さや行数を確かめましょう。',
  },
  {
    re: /arguments imply differing number of rows/,
    ja: () => '長さの違うベクトルを1つの表にしようとしています。それぞれの長さを length() で確かめましょう。',
  },
  {
    re: /must be size (\d+) or 1, not (\d+)/,
    ja: (m) => `長さが合いません（${m[1]} か 1 であるべきところが ${m[2]} になっています）。集計の前後で行数が変わっていないかを確認しましょう。`,
  },
  {
    re: /invalid 'type' \(character\) of argument/,
    ja: () => '文字のデータを合計・平均しようとしています。数値の列を使っているか確認しましょう。',
  },
];

export function translateError(message: string): string | null {
  for (const r of rules) {
    const m = message.match(r.re);
    if (m) return r.ja(m);
  }
  return null;
}

export type ParsedStatus =
  | { kind: 'ok' }
  | { kind: 'error' | 'parse'; message: string; call: string; ja: string | null };

export function parseStatus(status: string): ParsedStatus {
  if (status === 'ok') return { kind: 'ok' };
  const [kind, message = '', call = ''] = status.split('\t');
  return {
    kind: kind === 'parse' ? 'parse' : 'error',
    message,
    call,
    ja: translateError(message),
  };
}
