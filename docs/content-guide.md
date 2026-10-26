# 教材の書き方（step.yaml と body.md）

設計書 `docs/design.md` の「教材を書くときの規則」を具体化したもの。迷ったら設計書を優先する。

## ファイル

- `content/steps/<3桁>/step.yaml` … メタ情報・小課題・正解・判定。スキーマは `schema/step.schema.json`
- `content/steps/<3桁>/body.md` … 解説本文（Markdown）。数式は `$...$`（KaTeX、第4部以降）
- データは `public/data/<名前>.csv`。setup では `read_csv("data/<名前>.csv", show_col_types = FALSE)` で読む

## アプリでの実行のされ方（判定を書く前に必ず理解する）

1. ステップを開くと、学生用の環境と正解用の環境を作り、両方で `setup` を実行する
2. 正解用の環境で全小課題の `solution` を a から順に実行する。代入した結果は `.sol$名前` で参照できる。
   各 solution の「最後に表示される値」は `.sol_value`、作った ggplot は `.sol_plot` で参照できる
3. 学生用の環境は小課題 a→b→c… で共有される（a で作った変数を b で使える）。
   学生が a を飛ばして b を実行した場合、アプリは a の正解コードを先に流して準備する
4. 学生のコードを1式ずつ実行し、見える値は表示する。最後に表示された値は `.value`、作った図は `.plot`
5. `check` を学生の環境の子環境で実行する。`r108_fail()` が投げられなければ正解

## 判定関数（r108check）

| 関数 | 使いどころ |
| --- | --- |
| `expect_object("x", class = "data.frame")` | 代入を求める課題の最初に置く |
| `expect_value(x, .sol$x)` / `expect_value(.value, .sol_value)` | 数値・文字。代入でなく表示させる課題は `.value` を使う |
| `expect_df_equal(df, .sol$df, ignore_row_order = TRUE)` | データフレーム。並び順を問う課題では `ignore_row_order = FALSE`（既定） |
| `expect_cols(df, c("a","b"))` / `expect_nrow(df, n)` | 列名・行数だけ確かめたいとき |
| `expect_uses("sum")` / `expect_not_uses("for")` | 指定した関数を使わせたいとき（構文解析で判定。`"|>"`、`"=="` も可） |
| `expect_ggplot(geom = "point", x = "gdpPercap", colour = "continent")` | 図 |
| `expect_model(m, like = .sol$m)` / `expect_coef(m, "x", coef(.sol$m)[["x"]])` | 回帰 |
| `expect_text("高齢化")` / `expect_min_chars(40)` | 記述式（`free: true`）の回答文 |
| `check_that(条件, "日本語メッセージ")` | 上で書けない条件 |

**正解の値を check に直接書かない**（`expect_value(x, 12.3)` は不可。`.sol$x` か `.sol_value` と比べる）。
例外は「長さ」「列名」など構造の確認だけ。

## 小課題の型

- `write`［書］… 白紙または最小限の starter から書く
- `fill`［穴］… starter に `___` を置く。starter のままでは不正解になること（テストで確認される）
- `fix`［直］… starter に誤りのあるコードを置く。starter のままでは不正解かエラーになること
- `predict`［予］… `choices`（文字列の配列）、`answer`（0始まり）、`explain` を書く。R は実行しない
- `interpret`［解］… 選択式なら predict と同じ形。記述式なら `free: true` と `solution`（模範解答の文）、
  `check`（`expect_text`・`expect_min_chars`）、`hints` を書く
- 最後の小課題は前ステップの復習。`review: true` を付ける（型は上のいずれか）

コードの小課題（write/fill/fix と記述式）には `hints` をちょうど3つ書く。1つ目は方針、2つ目は使う関数や引数、3つ目はほぼ答え。
不正解の例を `tests: { fail: ["..."] }` に1つ以上書くと、判定が甘くないかをテストで確かめられる（強く推奨）。

## 文体・分量

- 本文は 1,500〜2,500字。です・ます調、1文は短く。
- 構成: 冒頭に `## 問い`（このステップの問いを1〜2文）→ 解説の節（2〜4個、```r のコード例つき）→ 末尾に `## 卒論・実務での使いどころ`（1文）
- YAML では `n`・`y`・`no`・`on` などが論理値に読まれることがある。`learn: ["n"]` のように引用符で囲む
- 新しく覚える関数は5個まで。`learn:` に列挙する。`learn` の累積（前のステップまで＋このステップ）と基本の演算子以外の関数は使わない。
  どうしても使う補助的な関数（`round` など既出でないもの）は `allow:` に書く
- R は tidyverse 流儀、パイプはネイティブの `|>`。`%>%` は使わない
- 経済学部2年生向け。プログラミング未経験を前提に、専門用語は初出で説明する
- 本文中のコード例はステップのデータで実際に動くものにする（数値は「〜になります」と断定せず、実行して確かめさせる）

## テスト

```sh
Rscript tests/r/run_solutions.R 3     # ステップ3だけ
Rscript tests/r/run_solutions.R       # 全部
npm run validate                      # スキーマ検証
```

失敗 0 件になるまで直す。「警告」（learn にない関数）は原則なくす。

## データについての注意（第2部以降を書く人へ）

- `ec_products.csv` の product_id（例 `"00012"`）は、readr 2.x の `read_csv()` では文字列のまま読まれ、先頭の0は消えない。
  第10ステップ c（先頭の0が消える）は `ec_products.xlsx`（product_id を数値で保存）を `read_excel()` で読む形で作る
- `ec_orders` には顧客マスタにない顧客の注文が25件ある（第14ステップ c の anti_join 用）
- 各データの列の意味は `public/data/codebook/<名前>.yaml`、生成方法は `data-raw/README.md`
- 「そらまめマーケット」は食品スーパー50店舗（`sora_stores`）とネット通販（`ec_*`）を営む架空の会社。第2部以降でこの会社のデータを使うときは、第1部と同じ会社・同じ設定（学生は経営企画部の新入社員）として書く。事例の選び方は設計書「第2部以降の事例の選び方」に従う
- `messy_survey` は来店客アンケート（年代・性別・来店回数・購入金額・回答日）。`store_sales_daily` の店舗は `sora_stores` の30店舗で、2025年の店舗別合計が `sora_stores` の sales（万円）と一致する
- 公的統計（`pref_basic`、`pref_labor_wide`、`wage_census_pref`、`min_wage_pref`、`kakei_raw_sjis`）は公式の元資料から作った本物の値。本文には出所（調査名と年）を明記し、定義（例：就業率の分母から労働力状態「不詳」を除く、賃金は6月分）を1文で添える
- 賃金構造基本統計調査は各年6月分、最低賃金は年度（10月前後に改定）。Y年の賃金と比べる最低賃金は fiscal_year = Y − 1 の額
- `kakei_raw_sjis.csv` は CP932。locale を付けずに読むと webR でも「invalid multibyte string」で止まる（アプリはこのエラーを文字コードの問題として説明する）

## 図の判定の注意（第3部以降を書く人へ）

- `expect_ggplot(geom = "histogram")` は、geom が bar・stat が bin の層を histogram として見分ける
- ggplot2 4.0 では `.plot$layers` に名前が付く。`lapply(.plot$layers, ...)` の結果を `identical()` で比べるときは `unname()` を付ける
- 図のデータは `expect_df_equal(.plot$data, .sol_plot$data)`、軸の変換は `.plot$scales$get_scales("x")$get_transformation()$name` で比べられる（ggplot2 3.5 以降）
- 学生用と正解用の環境は同じ R の中で動き、`tempdir()` も共有する。ファイルを書き出す小課題では、setup で `tempfile()` を使って環境ごとに別の名前にするか、`expect_uses("write_csv")` のように書き出したこと自体も確かめる
- webR では `ggsave()` で PNG と PDF を保存できる（SVG は svglite が要るので使わない）
- 公的統計の時系列（`lfs_monthly`・`cpi_monthly`・`gdp_quarterly`・`iip_monthly`）の季節調整値は、公表のたびに過去にさかのぼって改定される。当時の報道の値と0.1ポイントほど違う月がある。`gdp_quarterly` の real_gdp は年率表示の水準（「四半期の額」ではない）。`cpi_monthly` は2025年基準（2025年平均＝100）。`iip_monthly` は2020年基準（2020年平均＝100）で2018年1月から（旧基準とはつながない）
