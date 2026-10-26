# data-raw — 教材データの生成・取得スクリプト

`public/data/` のデータはすべてこのフォルダのスクリプトから作り直せる。仕様は `docs/design.md` の「サンプルデータ仕様」に従う。合成データの生成式は変えない（変えるときは設計書を先に更新する）。

## 使い方

```sh
# プロジェクトのルートで
Rscript data-raw/build_all.R      # 公的統計（保存した元資料から）と合成データを作り直し、checksums.txt を書く
Rscript tests/r/test_synth.R      # 仕込んだ効果が推定で再現されるか確かめる
```

- 必要なパッケージ: dplyr, readr, lubridate, writexl（生成）、testthat, readxl, yaml, stringi（テスト）、readxl（公的統計の元資料の読込）、jsonlite（e-Stat API）
- `build_all.R` は各スクリプトを別々の `Rscript` プロセスで実行するので、どのスクリプトも単独で同じ結果になる（各スクリプトの先頭で `set.seed(108)`）
- 2回実行して `public/data/checksums.txt`（MD5）が変わらないことを確認済み。乱数の結果は R のバージョン（`sample()` の既定の方式など）に依存するので、R 4.x で実行する
- `ec_products.xlsx` は writexl が作成日時を書き込むため、`normalize_xlsx.R` で作成日時を固定し ZIP を書き直している（`zip` コマンドが必要。無い環境ではxlsxのチェックサムだけが変わる）

## スクリプト一覧

### 合成データ（`synth_*.R`、乱数シード108）

| スクリプト | 出力 | 行数 |
| --- | --- | --- |
| `synth_sora_stores.R` | `sora_stores.csv`（第1部。架空の企業「そらまめマーケット」の50店舗） | 50 |
| `synth_messy_survey.R` | `messy_survey.csv`（そらまめマーケットの来店客アンケート） | 500 |
| `synth_ec.R` | `ec_customers.csv`, `ec_products.csv`, `ec_products.xlsx`, `ec_orders.csv` | 5,000 / 200 / 200 / 61,275 |
| `synth_churn.R` | `churn.csv`（`ec_*` から集計。`synth_ec.R` の後に実行） | 5,000 |
| `synth_ab_test.R` | `ab_test.csv`, `ab_test_srm.csv` | 20,000 / 20,000 |
| `synth_wage_survey.R` | `wage_survey.csv` | 3,000 |
| `synth_training.R` | `training_rct.csv`, `training_obs.csv` | 1,000 / 4,000 |
| `synth_minwage_panel.R` | `minwage_panel.csv` | 611（47県×13年） |
| `synth_scholarship_rdd.R` | `scholarship_rdd.csv` | 5,000 |
| `synth_store_sales_daily.R` | `store_sales_daily.csv`（`sora_stores.csv` の30店舗。`synth_sora_stores.R` の後に実行） | 32,880（30店舗×1,096日） |

仕込んだ「答え」は各スクリプトの冒頭のコメントと `public/data/codebook/<名前>.yaml` の `notes` に書いてある。

### 公的統計（`fetch_*.R`）

公式の Excel・CSV を `data-raw/raw/<名前>/` に保存し、スクリプトはそこから作る（通信しない、e-Stat のアプリケーションIDも要らない）。取得先の URL・取得日・加工の内容は各フォルダの `SOURCES.md` にある。

| スクリプト | 出力 | 元資料 |
| --- | --- | --- |
| `fetch_pref_basic.R` | `pref_basic.csv` | 2020年国勢調査 人口等基本集計 第1-1表・第2-3表、国土地理院 面積調 |
| `fetch_pref_labor_wide.R` | `pref_labor_wide.csv` | 国勢調査 時系列データ 労働力状態 第1表・第2表 |
| `fetch_wage_census_pref.R` | `wage_census_pref.csv` | 賃金構造基本統計調査 都道府県別（2020〜2025年は参考表 sanko1、2019年は新推計の参考系列） |
| `fetch_min_wage_pref.R` | `min_wage_pref.csv` | 厚生労働省「平成14年度から令和8年度までの地域別最低賃金改定状況」（Excel） |
| `fetch_kakei_raw_sjis.R` | `kakei_raw_sjis.csv`（CP932） | 家計調査 2025年 第4-1表（二人以上の世帯・市別） |
| `fetch_lfs_monthly.R` | `lfs_monthly.csv` | 労働力調査 長期時系列 表1-a-1「主要項目（季節調整値及び原数値）」（Excel、2026年8月分の版）。完全失業率は季節調整値と原数値、就業者数は原数値 |
| `fetch_cpi_monthly.R` | `cpi_monthly.csv` | 消費者物価指数 2025年基準 全国 月次（e-Stat 表 0004052037 の API 応答） |
| `fetch_gdp_quarterly.R` | `gdp_quarterly.csv` | 内閣府 四半期別GDP速報 2026年4-6月期2次速報（2026年9月8日公表）、実質季節調整系列（2020暦年連鎖価格）の CSV |
| `fetch_iip_monthly.R` | `iip_monthly.csv` | 鉱工業指数 2020年基準 生産指数・鉱工業総合 月次（経済産業省サイトの Excel b2020_gsm1j.xlsx 季節調整済指数・b2020_gom1j.xlsx 原指数。ブラウザで手で取得。e-Stat 表 0004052177・0004052181 の API 応答と照合）。2020年基準の系列が2018年1月からのため2018年1月〜2026年8月 |
| `make_jp_tile.R` | `jp_tile.csv` | 手で決めたタイル地図の配置（47都道府県の行・列）。`pref_basic.csv` と県名を照合する |
| `fetch_estat_sample.R` | `estat_sample.json` | e-Stat API の応答そのもの（統計表ID 0000010206、2026-10-23取得）。通信してアプリケーションID（環境変数 `ESTAT_APP_ID`）を使うので `build_all.R` には入れない。保存前に ID を `YOUR_APP_ID` に置き換え、残っていないことを確かめる |
| `build_pref_panel.R` | `pref_panel.csv` | 上の pref_basic・wage_census_pref・min_wage_pref を結合（第18ステップの正解と一致することをスクリプト内で確認） |
| `pref_basic_interim.R` | （使わない） | 以前の手入力の暫定版。公表値との差は `raw/pref_basic/SOURCES.md` |

- 通信して元資料を `data-raw/raw/` に保存するのは `download_lfs_monthly.R`・`download_cpi_monthly.R`・`download_iip_monthly.R`（e-Stat API。iip は照合用で、主資料の Excel は手で取得。アプリケーションIDが要る）。`build_all.R` はこれらを呼ばない。新しい月を足すときだけ実行し、続けて `build_all.R` を実行する
- `estat_helpers.R` は API を使う `download_*.R` と `fetch_estat_sample.R` 用
- 元資料の公表ページは改版でファイル番号が変わり、古い版は消える。作り直しには `data-raw/raw/` の保存ファイルを使う

### その他

- `build_all.R` — 全スクリプトの実行とチェックサムの書き出し
- `normalize_xlsx.R` — xlsx の作成日時を固定する関数
- `estat_helpers.R` — e-Stat API を呼ぶ関数
