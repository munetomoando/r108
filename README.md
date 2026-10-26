# Rデータ分析 108ステップ（r108）

R を使ったことがない経済学部2年生が、ブラウザだけで順に学べる無償の自習アプリです。
4段階 × 3部 × 9ステップ ＝ 108ステップ。R の実行・採点・進捗保存はすべて学生のブラウザ内（[webR](https://docs.r-wasm.org/webr/)）で完結し、サーバーを持ちません。

著者：安藤至大（日本大学経済学部）　ライセンス：本文・データは CC BY 4.0、コードは MIT

## 現在の実装範囲

設計書（`docs/design.md`）の「実装の進め方」のうち、次の段階まで実装しています。

| 段階 | 状態 |
| --- | --- |
| M0 土台（Vite＋React＋TS、webR、エディタ、出力と図、GitHub Pages への自動公開） | 実装済み。「自由に試す」画面で `1 + 1` と ggplot の図、起動秒数を確認できる |
| M1 判定エンジン（`r108check`、スキーマ検証、判定の流れ、エラーの日本語化、進捗保存） | 実装済み |
| M2 データ（合成データの生成・効果の再現テスト・コードブック） | 合成データは実装済み。公的統計は取得スクリプトの雛形のみ（統計表IDが未確認） |
| M3 第1部（ステップ1〜9） | 本文・課題・判定を実装済み。ステップ3〜9は架空の企業「そらまめマーケット」の店舗データ（`sora_stores.csv`）で学ぶ。**教員レビューと学生の試用は未実施** |
| M4 パッケージ検証 | 実装済み。検証ページ `#/pkgcheck`。34個中32個が動く（ranger→randomForest、RSQLite→duckdb に置換）。結果は `docs/m4-packages.md` |
| M5 第2部（ステップ10〜18） | 9ステップすべて実装済み。公的統計（家計調査・国勢調査・賃金構造基本統計調査・最低賃金）は公式の元資料を `data-raw/raw/` に保存して作る。ステップ17は e-Stat API の応答を保存したもの（`data-raw/fetch_estat_sample.R`）。**教員レビューは未実施** |
| M5 第3部（ステップ19〜27） | 9ステップすべて実装済み。新しい公的統計は労働力調査（`lfs_monthly`）・消費者物価指数 2025年基準（`cpi_monthly`）・四半期GDP速報（`gdp_quarterly`）、補助データはタイル地図の配置（`jp_tile`）。**教員レビューは未実施** |
| M5 第4部（ステップ28〜36） | 9ステップすべて実装済み。データは wage_survey とシミュレーション。乱数を使う小課題は解答の先頭で `set.seed()` を指定させる。**教員レビューは未実施** |
| M5 第5部（ステップ37〜45） | 9ステップすべて実装済み。データは wage_survey と wooldridge::wage1（パッケージから読み、複製しない）。頑健な標準誤差は fixest、回帰表は modelsummary（`output = "markdown"`）。**教員レビューは未実施** |
| M6 第6部（ステップ46〜54）とローカル実行の仕組み | 9ステップすべて実装済み。46〜49はブラウザ（データは wooldridge::mroz）、50〜54は学生のPCで行うローカル実行ステップ。確認スクリプトは `local-src/` から `public/local/check_0XX.R` に組み立て、合格時だけ修了コードを表示する。テストは `npm run test:local`（quarto が要る。環境変数 `QUARTO_PATH` で指定可）。**教員レビューと Windows での動作確認は未実施** |
| M7 第7部（ステップ55〜63） | 9ステップすべて実装済み。データは training_rct・training_obs（真の効果 +30万円）、ステップ内で生成するシミュレーション、causaldata の nsw_mixtape・cps_mixtape（パッケージから読む）。マッチングは MatchIt、傾向スコアは glm で手作り。DAG の図は `public/images/058_*.svg`。**教員レビューは未実施** |
| M8 第8部（ステップ64〜72） | 9ステップすべて実装済み。データは minwage_panel・scholarship_rdd（真の効果が既知の合成データ）と causaldata の organ_donations・close_college・gov_transfers（パッケージから読む）。DID・イベントスタディ・操作変数法は fixest、RDD は lm の局所線形回帰。**教員レビューは未実施** |
| M9 第9部（ステップ73〜81） | 9ステップすべて実装済み。データは lfs_monthly・cpi_monthly・iip_monthly（鉱工業指数 2020年基準、2018年1月〜。経済産業省の Excel から作成し e-Stat と照合）。時系列のモデルは基本の R（arima・stl・acf）だけで扱う。**教員レビューは未実施** |
| M10 第10部（ステップ82〜90） | 9ステップすべて実装済み。架空の小売企業「そらまめマーケット」のネット通販（ec_*）と A/Bテスト（ab_test・ab_test_srm）の合成データで、KPI・寄与度・RFM・コホート・A/Bテスト（power.prop.test・prop.test・SRM）・価格弾力性・広告キャンペーンの DID と費用対効果を扱う。**教員レビューは未実施** |
| M11 第11部（ステップ91〜99） | 9ステップすべて実装済み。store_sales_daily と churn の合成データで、予測と因果、訓練・テストと過学習、tidymodels（recipe・workflow・交差検証）、ロジスティック回帰・評価指標・決定木（rpart）・ランダムフォレスト（randomForest。ranger は webR で動かない）を扱う。**教員レビューは未実施** |
| M12 第12部（ステップ100〜108） | 9ステップすべて実装済み。ローカル実行6ステップ（100 Quarto の業務レポート、101 Quarto ダッシュボード、102 Shiny、104 Git、105 GitHub、108 修了課題）は確認スクリプトと修了コード、ブラウザ3ステップ（103 SQL と duckdb、106 生成AIのコードの検証、107 1枚要約）。これで108ステップすべてが実装済み。**教員レビューと学生の試用は未実施** |

## 使い方（開発）

```sh
npm install
npm run dev            # http://localhost:5173/
npm test               # TypeScript の単体テストとスキーマ検証
npm run test:r         # r108check の単体テストと全ステップの正解コード
npm run test:e2e       # Playwright（ブラウザで webR を起動して判定を確かめる）
npm run build          # dist/ に静的サイト（base は /r108/）
Rscript data-raw/build_all.R   # データを再生成（チェックサムを public/data/checksums.txt に書く）
Rscript tests/r/test_synth.R   # 合成データに仕込んだ効果が推定で再現されるか
```

## 構成

```
content/parts.yaml          12部と4段階、108ステップの目次
content/steps/<番号>/       step.yaml（課題・正解・判定）と body.md（解説）
schema/step.schema.json     step.yaml のスキーマ
r/r108check/                判定用 R パッケージ。scripts/build-r.mjs で public/r/r108check.R にまとめ、webR 起動時に読む
src/runtime/webr.ts         webR の起動・パッケージ・データ配置・実行（PostMessage チャンネル）
src/runtime/grader.ts       判定の流れ
src/runtime/errors.ts       R のエラーの日本語化表
src/store/progress.ts       進捗（localStorage キー r108.v1）
public/data/                学生が読むデータとコードブック
data-raw/                   データの生成・取得スクリプト
tests/                      r/（通常の R）、unit/（Vitest）、e2e/（Playwright）
```

教材の書き方は `docs/content-guide.md` を参照してください。

## 公開

`main` に push すると GitHub Actions（`.github/workflows/ci.yml`）が R テスト → ビルド → E2E → GitHub Pages への公開を行います。
リポジトリの Settings → Pages で Source を「GitHub Actions」にしてください。リポジトリ名が `r108` 以外のときは、環境変数 `R108_BASE`（例 `/myrepo/`）でビルドの base を変えます。
