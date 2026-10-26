# r108 — Rデータ分析108ステップ
- 仕様は docs/design.md（この設計書をMarkdownで書き出したもの）に従う
- 教材は content/steps/<3桁番号>/step.yaml と body.md。スキーマは schema/step.schema.json。書き方は docs/content-guide.md
- 新しいステップを作ったら必ず `Rscript tests/r/run_solutions.R <番号>` を通す
- 合成データの生成式は変えない。変えるときは設計書を先に更新する
- 1プルリクエスト＝1部（9ステップ）
- 画面のデザイン（色・書体・部品）は DESIGN.md に従う。安藤ゼミのサイトと同じトークンを使う
