# gdp_quarterly の元資料

取得日: 2026-10-23（すべて）

資料: 内閣府経済社会総合研究所「国民経済計算（GDP統計）」四半期別GDP速報
**2026年4-6月期・2次速報値（2026年9月8日公表）**。基準: **2020年（令和2年）基準、2020暦年連鎖価格**。
データ期間: 1994年1-3月期〜2026年4-6月期。取得日時点で公表済みの最新の速報（2026年7-9月期1次速報は未公表）。

入口: https://www.esri.cao.go.jp/jp/sna/sokuhou/sokuhou_top.html → 「統計表一覧（最新の結果を掲載しています）」
統計表一覧: https://www.esri.cao.go.jp/jp/sna/data/data_list/sokuhou/files/2026/qe262_2/gdemenuja.html

| 保存ファイル | 内容 | URL | 用途 |
| --- | --- | --- | --- |
| `gaku-jk2622.csv` | 実額・四半期・実質季節調整系列（2020暦年連鎖価格、10億円、年率表示）。Shift-JIS | https://www.esri.cao.go.jp/jp/sna/data/data_list/sokuhou/files/2026/qe262_2/tables/gaku-jk2622.csv | **主資料**。real_gdp |
| `ritu-jk2622.csv` | 増加率・実質季節調整系列（前期比、%）。Shift-JIS | https://www.esri.cao.go.jp/jp/sna/data/data_list/sokuhou/files/2026/qe262_2/tables/ritu-jk2622.csv | **主資料**。growth_qoq |
| `nritu-jk2622.csv` | 実質季節調整系列（前期比・年率換算、%）。Shift-JIS | https://www.esri.cao.go.jp/jp/sna/data/data_list/sokuhou/files/2026/qe262_2/tables/nritu-jk2622.csv | 照合用（本データには使わない） |
| `qepoint2622.pdf` | 「2026年4-6月期GDP速報（2次速報値）ポイント解説」 | https://www.esri.cao.go.jp/jp/sna/data/data_list/sokuhou/files/2026/qe262_2/pdf/qepoint2622.pdf | 照合用。最新期の実質成長率 0.4%（年率1.4%） |
| `gdemenuja_qe262_2.html` | 統計表一覧のページ（速報の回・公表日・データ期間の記録） | 上の統計表一覧のURL | 記録 |

## 加工の内容（`data-raw/fetch_gdp_quarterly.R`）

1. CSV は CP932。上に7行の見出し（日本語・英語の項目名）、下に注記がある。1列目が期の表示
   （「1994/ 1- 3.」「4- 6.」…。年は年が変わる行にだけ付く）の行だけを取り出す
2. 期を四半期の初日の日付（1994-01-01, 1994-04-01, …）に直す
3. 2列目「国内総生産(支出側)」だけを使う。real_gdp = 実額（10億円）÷ 1000（兆円）。元の小数1桁はそのまま残す
4. growth_qoq は ritu-jk の公表前期比（%、小数1桁）をそのまま使う。1994年1-3月期は元資料でも空欄なので NA。
   公表値に「-0.0」（0未満の小さな減少）がある期は "-0.0" のまま書き出す
5. 検算: 130期が欠けなく並ぶ、実額から計算した前期比と公表前期比の差が丸めの範囲（±0.05）に収まる

## 照合（2026-10-23、作成者が実施）

- 2026年4-6月期: 前期比 0.4%（ポイント解説・ritu-jk と一致）。実額から計算した年率換算 1.4%（ポイント解説・nritu-jk と一致）
- 2020年4-6月期: 前期比 -7.2%（ritu-jk）、年率換算 -25.8%（nritu-jk。実額からの計算とも一致）

## 注意

季節調整は毎回かけ直されるため、季節調整系列は速報のたびに1994年1-3月期まで遡って改定される。
別の回の速報の値とは過去の期も一致しない。
