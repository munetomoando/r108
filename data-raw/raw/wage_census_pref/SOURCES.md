# wage_census_pref の元ファイル

- 統計: 厚生労働省「賃金構造基本統計調査」（政府統計コード 00450091）。e-Stat「ファイル」から Excel をダウンロード（e-Stat API は使っていない）
- 取得日: 2026-10-23（すべてのファイル）
- ダウンロードURLの形: `https://www.e-stat.go.jp/stat-search/file-download?statInfId=<統計表番号>&fileKind=<種類>`（fileKind=4 は xlsx、0 は xls、2 は PDF）
- 作成スクリプト: `data-raw/fetch_wage_census_pref.R`（このフォルダのファイルだけを読み、通信しない）
- 対象: 一般労働者、企業規模計（10人以上）、産業計、学歴計、年齢計。各年6月分の所定内給与額（千円）と所定内実労働時間数（時間）

## 年ごとの元ファイル

| 年 | ファイル | e-Stat の掲載場所・表 | 統計表番号（statInfId） | e-Stat 上の公開（更新）日 |
| --- | --- | --- | --- | --- |
| 2019 | `2019_recomputed_table1/table1_2019_recomputed_<番号>.xlsx`（24ファイル） | 【参考掲載】令和２年調査と同じ推計方法を用いた過去分の集計（平成18年～令和元年）＞一般労働者＞都道府県別＞年次。表番号1「（令和２年と同じ推計方法による集計）都道府県、年齢階級別きまって支給する現金給与額、所定内給与額及び年間賞与その他特別給与額」（北海道・青森県 〜 沖縄県） | 000032110601 〜 000032110624（fileKind=4） | 2021-08-10 |
| 2019（全国値の検算用） | `national_2019_recomputed_table1.xlsx` | 同じ【参考掲載】＞一般労働者＞産業大分類＞年次。表番号1「（令和２年と同じ推計方法による集計）年齢階級別きまって支給する現金給与額、所定内給与額及び年間賞与その他特別給与額（産業計・産業別）」 | 000032110590（fileKind=4） | 2021-08-10 |
| 2019（旧推計。CSVには使わない） | `sanko1_2019_old_method.xls` | 令和元年賃金構造基本統計調査＞一般労働者＞都道府県別。表番号 sanko1「（参考表）都道府県別きまって支給する現金給与額、所定内給与額及び年間賞与その他特別給与額（47都道府県一覧）」 | 000031919912（fileKind=0） | 2020-09-15 |
| 2020 | `sanko1_2020.xls` | 令和２年賃金構造基本統計調査＞一般労働者＞都道府県別。表番号 sanko1（同上の47都道府県一覧） | 000032088463（fileKind=0） | 2021-05-21 |
| 2021 | `sanko1_2021.xlsx` | 令和３年調査＞一般労働者＞都道府県別。表番号 sanko1 | 000032183057（fileKind=4） | 2022-03-25 |
| 2022 | `sanko1_2022.xlsx` | 令和４年調査＞一般労働者＞都道府県別。表番号 sanko1 | 000040029286（fileKind=4） | 2023-03-17 |
| 2023 | `sanko1_2023.xlsx` | 令和５年調査＞一般労働者＞都道府県別。表番号 sanko1 | 000040163846（fileKind=4） | 2024-03-27 |
| 2024 | `sanko1_2024.xlsx` | 令和６年調査＞一般労働者＞都道府県別。表番号 sanko1 | 000040247959（fileKind=4） | 2025-03-17 |
| 2025 | `sanko1_2025.xlsx` | 令和７年調査＞一般労働者＞都道府県別。表番号 sanko1 | 000040421202（fileKind=4） | 2026-03-24 |
| （説明資料） | `estimation_method_2020.pdf` | 【参考掲載】＞推計方法の説明。表番号1「令和２年の推計方法による集計について」 | 000032106209（fileKind=2） | 2021-07-13 |

一覧ページ（ファイルの探し方）

- 統計のトップ: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429
- 2025年 都道府県別: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=0&tclass1=000001229845&tclass2=000001229849&tclass3=000001229860&tclass4val=0
- 2024年 都道府県別: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=0&tclass1=000001224440&tclass2=000001225782&tclass3=000001225794&tclass4val=0
- 2023年 都道府県別: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=0&tclass1=000001213360&tclass2=000001215880&tclass3=000001215890&tclass4val=0
- 2022年 都道府県別: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=0&tclass1=000001202310&tclass2=000001202312&tclass3=000001202331&tclass4val=0
- 2021年 都道府県別: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=0&tclass1=000001164106&tclass2=000001164107&tclass3=000001164117&tclass4val=0
- 2020年 都道府県別: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=0&tclass1=000001152186&tclass2=000001152187&tclass3=000001152197&tclass4val=0
- 2019年 都道府県別（旧推計）: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=0&tclass1=000001138086&tclass2=000001138089&tclass3=000001138097&tclass4val=0
- 【参考掲載】一般労働者 都道府県別 2019年: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=7&tclass1=000001155791&tclass2=000001156749&tclass3=000001156755&tclass4val=0&year=20190&month=0
- 【参考掲載】一般労働者 産業大分類 2019年: https://www.e-stat.go.jp/stat-search/files?page=1&layout=datalist&toukei=00450091&tstat=000001011429&cycle=7&tclass1=000001155791&tclass2=000001156749&tclass3=000001156750&tclass4val=0&year=20190&month=0

## 加工の内容

- 2020〜2025年: 参考表1のシート「男女計」から男女計、「男女別」から男・女の各都道府県の行を取り、
  所定内実労働時間数（時間）と所定内給与額（千円）の列をそのまま使う（全国の行は検算にだけ使う）
- 2019年: 【参考掲載】都道府県別第1表の各県「NN-01<県名>産業計」シートで、企業規模計（10人以上）の列の
  「男女計」「男」「女」（年齢計）の行から所定内実労働時間数と所定内給与額を取る
- 都道府県名（「青　森」「京都」など）は空白を除いて JIS X 0401 の順の名前と照合し、pref_code（1〜47）にする
- 数値の丸め・換算はしない（所定内給与額は0.1千円単位、所定内実労働時間数は1時間単位で公表どおり）
- 参考表1は第1表の「産業計・企業規模計（10人以上）・年齢計」を47都道府県分まとめた表。
  2024年の東京（第1表 statInfId=000040247930 の「(東京)産業計」シート）で、男女計・男・女の値が一致することを確かめた（このファイルは保存していない）

## 推計方法の変更（2020年調査から）と2019年の扱い

- 令和２年（2020年）調査から調査項目と推計方法が見直された。`estimation_method_2020.pdf` によると、
  事業所復元倍率を「抽出率の逆数」から「母集団に対する有効回答事業所数の割合の逆数」に、
  労働者復元倍率を「規定の抽出率の逆数」から「雇用形態別に実際に抽出された労働者数の割合の逆数」に変えた。
  主な変更点は厚生労働省「利用上の注意」（https://www.mhlw.go.jp/toukei/itiran/roudou/chingin/kouzou/z2020/chuui.html）の5以降
- 厚生労働省は、平成18年〜令和元年について令和２年と同じ推計方法で集計し直した値を「参考系列」として掲載している
  （過去の公表値を訂正するものではない、と明記）
- **このデータの2019年は参考系列（令和２年と同じ推計方法）の値**で、2020〜2025年は各年の公表値。
  したがって2019〜2025年は同じ推計方法でそろっている
- 2019年の旧推計方法による公表値（`sanko1_2019_old_method.xls`、全国の男女計 307.7千円）は CSV に入れていない。
  新推計の全国値は 306.0千円で、県別の差（新−旧、男女計）は −9.8〜+1.0千円、平均 −3.0千円

## ファイルの MD5（取得時）

```
58b428f74a1c55775325a4ffa6b8bc49  2019_recomputed_table1/table1_2019_recomputed_000032110601.xlsx
50bd99fc7cebb20dbd7b408834bdf65f  2019_recomputed_table1/table1_2019_recomputed_000032110602.xlsx
84dc9ccc835e8c07743dfb1df1f273c2  2019_recomputed_table1/table1_2019_recomputed_000032110603.xlsx
5cddcbd98e00f509cf72aefb4961c22e  2019_recomputed_table1/table1_2019_recomputed_000032110604.xlsx
bb50bdc45d809e4bc6514e4444b38d5a  2019_recomputed_table1/table1_2019_recomputed_000032110605.xlsx
3d0f9072250519f62ff7235b299db7c3  2019_recomputed_table1/table1_2019_recomputed_000032110606.xlsx
011560d760f7204234a93b7900da662b  2019_recomputed_table1/table1_2019_recomputed_000032110607.xlsx
564c20163ca722406f75ca409689b371  2019_recomputed_table1/table1_2019_recomputed_000032110608.xlsx
e16e5f71c36a2d379fc96695d4bc53f9  2019_recomputed_table1/table1_2019_recomputed_000032110609.xlsx
7d862fc595513e2bec8831b5e9001c70  2019_recomputed_table1/table1_2019_recomputed_000032110610.xlsx
3a96882d693b71910cd39ac6293ffd9f  2019_recomputed_table1/table1_2019_recomputed_000032110611.xlsx
c3cbd28bcfd6440f5f1d355ad7d8206f  2019_recomputed_table1/table1_2019_recomputed_000032110612.xlsx
63f64f059ec5af09849055b604e92ee4  2019_recomputed_table1/table1_2019_recomputed_000032110613.xlsx
3594f8152b67da861b60df3c3588fd23  2019_recomputed_table1/table1_2019_recomputed_000032110614.xlsx
dc89f962969ccf378b96f6145bde367b  2019_recomputed_table1/table1_2019_recomputed_000032110615.xlsx
f758a94f8aa8fb74072afda00b9f9cbb  2019_recomputed_table1/table1_2019_recomputed_000032110616.xlsx
0d1b9683230318e5adeaaa4ad9fbccb0  2019_recomputed_table1/table1_2019_recomputed_000032110617.xlsx
611a6757c37a3164a2ed04a01ba281e6  2019_recomputed_table1/table1_2019_recomputed_000032110618.xlsx
23a4751848fb8b78d533dacea88ff73a  2019_recomputed_table1/table1_2019_recomputed_000032110619.xlsx
703e80e3542197b696735421ffbdeefe  2019_recomputed_table1/table1_2019_recomputed_000032110620.xlsx
c4ae7c2c0532443cac7f82a848a1f0c0  2019_recomputed_table1/table1_2019_recomputed_000032110621.xlsx
c80c45edad6b73631f62b31fb6887523  2019_recomputed_table1/table1_2019_recomputed_000032110622.xlsx
9d1db6bcf080c9d026f4c77e1dad6763  2019_recomputed_table1/table1_2019_recomputed_000032110623.xlsx
2a44158dbfe397d50335d556b41545e6  2019_recomputed_table1/table1_2019_recomputed_000032110624.xlsx
725271d8e2d1dcb045613e4a0d79fda0  estimation_method_2020.pdf
d7f8525e78f0b6079624b8181a6f1c7a  national_2019_recomputed_table1.xlsx
799840b0def71f5f759cca9650d1d928  sanko1_2019_old_method.xls
be9042a820d6b35032355fb004d4655c  sanko1_2020.xls
b2a2c990f229deadb026cf577a17067a  sanko1_2021.xlsx
d34c72c1dab20c19dbf1bf92156806ef  sanko1_2022.xlsx
ff75919139066962d9991783c091fadc  sanko1_2023.xlsx
6548b6d7cd0d73f6ddbd38f6acfd3d36  sanko1_2024.xlsx
e51eeb1cd8c147f075be93cbb66a7b34  sanko1_2025.xlsx
```
