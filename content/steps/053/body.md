## 問い

卒論の締め切り直前に「表1の数字はどうやって出したの？」と指導教員に聞かれたとき、同じ結果をもう一度作れるでしょうか。半年後の自分や、別の PC を使う人が、同じデータから同じ数字を作れる状態を**再現可能**（reproducible）といいます。このステップでは、第51・52ステップのプロジェクトとは別に、最低賃金の分析を再現可能な形に組み直します。

## 再現できなくなる4つの原因

卒論の分析が再現できなくなる原因は、たいてい次の4つです。

| 原因 | よくある例 | このステップの対策 |
| --- | --- | --- |
| ファイルの場所 | `setwd("C:/Users/taro/...")` が他の PC で動かない | here パッケージ |
| 実行の順番 | コンソールで試した行が、スクリプトに残っていない | 番号付きのスクリプトに分ける |
| パッケージの版 | 1年後に dplyr が更新され、同じコードが動かない | renv パッケージ |
| 乱数 | ブートストラップの結果が実行のたびに変わる | `set.seed()` |

## 手順

最初に、R のコンソールで `install.packages(c("renv", "here"))` を実行しておきます（readr・dplyr・ggplot2 は第50ステップで入れました）。

1. **新しいプロジェクトを作る。** RStudio では「File」→「New Project...」→「New Directory」→「New Project」で、名前を `minwage` にします。Positron では `minwage` フォルダを作って「File」→「Open Folder...」で開き、ステップ50と同じくコンソールで `writeLines("Version: 1.0", "minwage.Rproj")` を一度だけ実行します。`here()` はこの `.Rproj` を目印にプロジェクトの場所を見つけます。
2. **フォルダを作る。** プロジェクトの中に `data`・`scripts` の2つのフォルダを作ります（RStudio の Files ペインの New Folder、または Windows のエクスプローラー・macOS の Finder で作れます）。`output` は作らなくてかまいません。スクリプトが作ります。
3. **データを置く。** このアプリから [pref_panel.csv](data/pref_panel.csv) をダウンロードし、`data` フォルダに移します。ダウンロードしたファイルは、Windows ではエクスプローラーの「ダウンロード」、macOS では Finder のサイドバーの「ダウンロード」にあります。このファイルは**手で直しません**。直したいことは、すべてスクリプトに書きます。
4. **スクリプトを書く。** `scripts` フォルダに、下の3本を作ります（「File」→「New File」→「R Script」で作り、名前を付けて保存）。
5. **番号順に実行して確かめる。** R を再起動してから（RStudio は「Session」→「Restart R」、Positron はコンソールの上にある再起動のボタン）、コンソールで1本ずつ実行します。
   ```r
   source(here::here("scripts", "01_clean.R"))
   source(here::here("scripts", "02_analysis.R"))
   source(here::here("scripts", "03_figure.R"))
   ```
   `output` フォルダに `panel_clean.csv`・`result.csv`・`fig_scatter.png` ができれば成功です。
6. **renv を始める。** コンソールで `renv::init()` を実行します。スクリプトを読んで使っているパッケージを探し、プロジェクト専用の置き場（`renv/library`）に入れて、`renv.lock` を書き出します。足りないパッケージをインターネットから入れることがあるので、ネットにつながった状態で実行します。R の再起動を求められたら従います。
7. **パッケージを足したら記録する。** あとでスクリプトに `library(fixest)` などを足したときは、`renv::status()` で記録漏れを確かめ、`renv::snapshot()` で `renv.lock` を書き直します。
8. **確認スクリプトを実行する。** 下の「自分のPCで確認する」の手順に進みます。

## スクリプトを分け、here() で場所を書く

1本目は、元データを読んで分析用のデータを作り、ファイルに保存します。

```r
# 01_clean.R：元データを読み、分析用のデータを作る
library(readr)
library(dplyr)
library(here)

panel <- read_csv(here("data", "pref_panel.csv"), show_col_types = FALSE)
panel_clean <- panel |>
  mutate(log_avg_wage = log(avg_wage), log_min_wage = log(min_wage))

dir.create(here("output"), showWarnings = FALSE)
write_csv(panel_clean, here("output", "panel_clean.csv"))
```

`here("data", "pref_panel.csv")` は、プロジェクトのフォルダ（`.Rproj` のあるフォルダ）を起点にしたパスを作ります。Windows でも macOS でも、誰の PC でも同じ1行で動きます。`setwd()` や `C:/Users/...` のような絶対パスは使いません。

2本目以降は、前のスクリプトが保存したファイルを読むところから始めます。こうしておくと、どのスクリプトも「前の番号の出力」だけに頼るので、上から順に実行すれば必ず同じ状態になります。3本目の `03_figure.R` では、`output/panel_clean.csv` を読んで2025年の散布図を描き、`ggsave(here("output", "fig_scatter.png"), ...)` で保存します（第27ステップと同じ形です）。

## set.seed() で乱数を固定する

2本目では、2025年の47都道府県で、平均時給の対数を最低賃金の対数で回帰します。標準誤差は**ブートストラップ**で求めます。47県から重複を許して47県を選び直し（`slice_sample(prop = 1, replace = TRUE)`）、傾きを1000回計算して、そのばらつき（標準偏差）を標準誤差とみなす方法です。

```r
# 02_analysis.R（抜粋）
p2025 <- filter(panel_clean, year == 2025)
m <- lm(log_avg_wage ~ log_min_wage, data = p2025)

set.seed(2026)
slopes <- replicate(1000, {
  p_boot <- slice_sample(p2025, prop = 1, replace = TRUE)
  coef(lm(log_avg_wage ~ log_min_wage, data = p_boot))[["log_min_wage"]]
})
result <- tibble(estimate = coef(m)[["log_min_wage"]], se_boot = sd(slopes),
                 ci_low = quantile(slopes, 0.025), ci_high = quantile(slopes, 0.975))
write_csv(result, here("output", "result.csv"))
```

傾きは約1.60で、最低賃金が1%高い県ほど平均時給はおよそ1.6%高い、という関係です。ブートストラップの標準誤差は約0.149、95%区間は約1.35〜1.94になります（頑健な標準誤差 HC1 の約0.153と近い値です）。`set.seed(2026)` を消すと、実行のたびに標準誤差は小数第3位、区間の端は小数第2位あたりで変わります。第30ステップで学んだとおり、乱数を使う直前に必ず種を書きます。

## renv が記録するもの

`renv::init()` のあと、プロジェクトには `renv.lock`、`renv` フォルダ、`.Rprofile` ができます。`renv.lock` は、R の版と、使っているパッケージの名前・版・入手元を書いた文字のファイルです。別の PC でこのプロジェクトを開き `renv::restore()` を実行すると、記録と同じ版のパッケージが入ります。卒論を提出するときや指導教員に分析を渡すときは、`renv/library` を除いたフォルダ一式（`renv.lock` を含む）を渡します。

## 卒論・実務での使いどころ

卒論のフォルダを「元データ → 01_clean.R → 02_analysis.R → output」の一方通行にし、`renv.lock` を添えておけば、締め切り直前のデータ差し替えも、提出後の問い合わせも、スクリプトを番号順に実行し直すだけで対応できます。
