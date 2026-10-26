# M4 パッケージ検証の結果

2026年10月23日に確認しました。webR 0.6.0（npm）を、本番と同じ PostMessage 方式で動かしています。ブラウザは Playwright の Chromium です。

## 確かめ方

- 検証ページ `#/pkgcheck`（目次には出さない）で「検証を始める」を押すと、`src/content/pkgcheck.ts` の一覧を上から順に試します。
- `#/pkgcheck?only=ranger,duckdb` のように指定すると、一部だけ試せます。
- 1つのパッケージにつき、次の2点を確かめます。
  - 公式リポジトリ（repo.r-wasm.org）から入るか。入らないときは r-universe も試します。
  - 教材で使う関数を、小さなデータで実行できるか。
- 最後に、日本語の見出し・軸・凡例・注記・出所を入れた ggplot の図を描きます。文字化けしないかは目で確かめます。

## 結果

34個中32個が動きました。すべて公式リポジトリから入り、r-universe は要りませんでした。

| パッケージ | 版 | 使うステップ | 結果 |
| --- | --- | --- | --- |
| readr | 2.2.0 | 3〜, 10, 11 | 動く |
| dplyr | 1.2.1 | 4〜 | 動く |
| tidyr | 1.3.2 | 13 | 動く |
| ggplot2 | 4.0.3 | 19〜27 ほか | 動く |
| lubridate | 1.9.5 | 15, 73〜 | 動く |
| stringr | 1.6.0 | 12 | 動く |
| forcats | 1.0.1 | 22 | 動く |
| readxl | 1.5.0.1 | 10 | 動く |
| janitor | 2.2.1 | 11, 12 | 動く |
| stringi | 1.8.9 | 12 | 動く |
| jsonlite | 2.0.0 | 17 | 動く |
| gapminder | 1.0.1 | 19 | 動く |
| viridisLite | 0.4.3 | 25 | 動く |
| broom | 1.0.13 | 37〜 | 動く |
| fixest | 0.14.2 | 43, 44, 65〜72 | 動く |
| modelsummary | 2.6.0 | 44, 49 | 動く |
| wooldridge | 1.4.7 | 45 | 動く |
| causaldata | 0.1.4 | 47〜49, 62, 68, 69, 71 | 動く |
| MatchIt | 4.8.1 | 60, 63 | 動く |
| rsample | 1.3.2 | 92〜99 | 動く |
| recipes | 1.4.0 | 93〜 | 動く |
| parsnip | 1.6.1 | 93〜 | 動く |
| workflows | 1.3.0 | 93〜 | 動く |
| yardstick | 1.4.0 | 94〜99 | 動く |
| tune | 2.1.0 | 94, 99 | 動く |
| tidymodels | 1.5.0 | 93〜99 | 動く |
| rpart | 4.1.27 | 97 | 動く |
| ranger | 0.18.0 | 98, 99（予定） | NG: User interrupt or internal error. |
| randomForest | 4.7.1.2 | 98, 99（ranger の代替） | 動く |
| DBI | 1.3.0 | 103 | 動く |
| duckdb | 1.5.6 | 103 | 動く |
| dbplyr | 2.6.0 | 103 | 動く |
| testthat | 3.3.2 | 106 | 動く |
| RSQLite | — | 103（duckdb の代替候補） | NG: インストールできない |

## 動かなかったものと対応

| パッケージ | 症状 | 対応 |
| --- | --- | --- |
| ranger | 入るが、`ranger::ranger()` が `num.threads = 1` でも「User interrupt or internal error.」で止まる | 第98・99ステップのエンジンを **randomForest** にする（`rand_forest() |> set_engine("randomForest")`）。重要度は `randomForest::importance()` で取る |
| RSQLite | 公式リポジトリに無い | 第103ステップは **duckdb** だけを使う（dbplyr の `show_query()` も duckdb で動く） |

## 気づいたこと

- **パッケージの読み込み時間**：何も保存されていないブラウザで、tune が約12秒、modelsummary が約8秒、duckdb が約5〜6秒、tidymodels 一式が約6秒かかりました。依存するパッケージを先に入れていれば、どれも1〜2秒です。第11部の最初のステップでは「初回はパッケージの読み込みに数十秒かかる」と書きます。
- **入らないパッケージを入れようとすると、後の読み込みが壊れることがある**：RSQLite を試した直後に、別のパッケージの読み込みで `cachem.so` を開けないというエラーが出ました。教材の `packages:` には、この一覧で「動く」としたものだけを書きます。
- **日本語の図**：見出し・軸・凡例・注記・出所が、端末の日本語フォントで正しく表示されました（macOS の Chromium で確認。Windows での表示は学生の試用で確かめます）。
