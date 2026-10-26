## 問い

ここまでの49ステップは、ブラウザの中で動く R（webR）で学んできました。卒論では、自分のPCに R を入れて、データや原稿をファイルとして手元に置きながら分析します。このステップでは R と RStudio を入れ、第45ステップのコードが自分のPCでも同じように動くことを確かめます。

このステップから第54ステップまでは、ブラウザではなく自分のPCで作業します。最後に確認スクリプトを実行し、表示された修了コードを右の欄に貼り付けると完了です。

## R と RStudio を入れる

R は計算をする本体、RStudio は R を使いやすくする画面（統合開発環境）です。両方を入れます。

1. https://cran.r-project.org/ を開き、R を入れます。
   - Windows：「Download R for Windows」→「base」→「Download R-4.x.x for Windows」の順に進み、ダウンロードしたファイルを実行します。設定は既定のままで構いません。
   - macOS：「Download R for macOS」に進みます。M1 以降の Apple シリコンの Mac は「arm64」、それより古い Intel の Mac は「x86_64」と書かれた .pkg を選びます。どちらか分からなければ、アップルメニューの「この Mac について」でチップ名を確かめます。
2. https://posit.co/download/rstudio-desktop/ から RStudio Desktop（無料）を入れます。R を先に入れておくと、RStudio が自動で見つけます。
3. RStudio を起動し、左下のコンソールに `1 + 1` と入力して `2` が返れば成功です。

RStudio の代わりに、同じ会社が作っている新しいエディタ Positron を使っても構いません。

## プロジェクトを作る

プロジェクトは、1つの分析に使うファイル（データ・スクリプト・原稿）をまとめたフォルダです。プロジェクトを開くと、そのフォルダが作業フォルダになり、`"data/wage_survey.csv"` のような短い書き方でファイルを読めます。

1. RStudio のメニュー「File」→「New Project...」→「New Directory」→「New Project」と進みます。
2. フォルダ名を `r108` にし、置き場所を選んで「Create Project」を押します。フォルダ名や置き場所の途中に日本語や空白を含めないと、後のステップでつまずきにくくなります。
   - Windows：「ドキュメント」の下などに置きます。OneDrive と同期しているフォルダは、ファイルが一時的に開けなくなることがあるので避けます。
   - macOS：ホームフォルダの下などに置きます。
3. 右下の「Files」タブで「New Folder」を押し、`data` という名前のフォルダを作ります。
4. このアプリから [wage_survey.csv](data/wage_survey.csv) をダウンロードし、`data` フォルダに移します。

Positron の場合は、`r108` フォルダを作って「File」→「Open Folder...」で開きます。Positron は `.Rproj` ファイルを作らないので、コンソールで `writeLines("Version: 1.0", "r108.Rproj")` を一度だけ実行して印のファイルを作ってください。

## パッケージを入れる

webR では必要なパッケージをアプリが用意していました。自分のPCでは、パッケージを一度だけインストールし、使うたびに `library()` で読み込みます。コンソールで次を実行します（数分かかります）。

```r
install.packages(c("tidyverse", "modelsummary", "sandwich", "fixest",
                   "wooldridge", "rmarkdown"))
```

インストールはPCごとに一度で済みます。スクリプトの中に `install.packages()` を書いておくと、実行するたびに入れ直すことになるので、書かないようにします。

## 第45ステップのコードを動かす

「File」→「New File」→「R Script」で新しいスクリプトを開き、次のコードを書いて、プロジェクトのフォルダに `step45.R` という名前で保存します。第45ステップの小課題 b と d で書いたコードです。

```r
library(readr)
library(modelsummary)

wage1 <- wooldridge::wage1
wage <- read_csv("data/wage_survey.csv", show_col_types = FALSE)

m_ex7 <- lm(log(wage) ~ female * educ + exper + I(exper^2) + tenure + I(tenure^2),
            data = wage1)
m_jp <- lm(log_wage ~ female * educ_years + exper + I(exper^2) + tenure + I(tenure^2),
           data = wage)
tab_cmp <- modelsummary(list("米国1976年" = m_ex7, "日本（架空）" = m_jp),
  output = "markdown", fmt = 4, gof_map = c("nobs", "r.squared"),
  coef_rename = c(educ_years = "educ", "female:educ_years" = "female:educ"))
tab_cmp
```

スクリプトの右上の「Source」を押すと、全体が上から順に実行されます。コンソールに表が出て、「日本（架空）」の educ の行がブラウザで見た値と同じなら、自分のPCでもブラウザと同じ結果が得られています。

## 確認スクリプトを実行する

右の欄から `check_050.R` をダウンロードしてプロジェクトのフォルダに移し、コンソールで `source("check_050.R", encoding = "UTF-8")` を実行します。`source()` は、ファイルに書かれたコードを上から順に実行する関数です。確認スクリプトは R の版、パッケージ、`.Rproj` ファイル、データ、`step45.R` を順に調べ、すべて ✓ なら修了コードを表示します。✗ の項目には、直し方が → の後に表示されます。

## 卒論・実務での使いどころ

卒論は1つのプロジェクトにデータ・スクリプト・原稿をまとめて置き、パッケージは一度だけ入れて、分析はいつでも Source で最初から実行し直せる形にしておきます。
