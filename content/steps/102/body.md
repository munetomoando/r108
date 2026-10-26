## 問い

そらまめマーケット（架空の会社）の営業部長から「地域ごとの売上の推移を、会議のたびに自分で見たい。毎回グラフを頼むのは悪いから」と言われました。Quarto のレポート（第100ステップ）は、作った時点の図を配るものです。見る人が地域を**選ぶと図が変わる**ようにするには、R で動く Web アプリを作ります。このステップでは Shiny パッケージで、地域を選ぶと月別売上の図と店舗別の表が変わるアプリを作ります。

ここから第105ステップまでは、このアプリのフォルダを使います。第104ステップで Git の履歴を付け、第105ステップで GitHub に送ります。

## Shiny アプリの形

Shiny のアプリは、1つのファイル `app.R` に、次の3つを書きます。

| 部分 | 役割 | このステップで書くもの |
| --- | --- | --- |
| `ui` | 画面に何をどこに置くか | 地域を選ぶ欄（入力）、図と表の置き場所（出力） |
| `server` | 入力を受けて出力を作る関数 | 選んだ地域で絞り込み、図と表を作る |
| `shinyApp(ui, server)` | 2つを組み合わせてアプリにする | 最後の行に書く |

入力と出力は、名前（ID）でつながります。`selectInput("region", ...)` で作った欄の値は、server の中で `input$region` として読めます。`plotOutput("sales_plot")` で作った置き場所には、server で `output$sales_plot <- renderPlot({ ... })` と書いた図が入ります。ui の名前と server の名前が1文字でも違うと、図は表示されません。

## 手順

最初に、コンソールで `install.packages("shiny")` を実行します（readr・dplyr・ggplot2・lubridate は第50ステップで入れた tidyverse に含まれています）。

1. **プロジェクトを作る。** RStudio では「File」→「New Project...」→「New Directory」→「New Project」で、名前を `sora_app` にします。Positron では `sora_app` フォルダを作り、「File」→「Open Folder...」で開きます。
2. **データを置く。** プロジェクトの中に `data` フォルダを作り、このアプリから [sora_stores.csv](data/sora_stores.csv) と [store_sales_daily.csv](data/store_sales_daily.csv) をダウンロードして移します。日次売上は30店舗の2023〜2025年の32,880行です。
3. **app.R を書く。** 「File」→「New File」→「R Script」で新しいファイルを開き、下のコードを書いて、プロジェクトのフォルダの一番上に `app.R` という名前で保存します（ファイル名は必ず `app.R`）。
4. **動かす。** RStudio では、`app.R` を開くとエディタの右上に「Run App」のボタンが出るので、押します。Positron では、エディタの右上の「Run Shiny App」を押すか、コンソールで `shiny::runApp()` を実行します。別の窓かブラウザにアプリが開きます。
5. **地域を変えてみる。** 左の欄で地域を「関東」から「中部」などに変え、図と表が変わることを確かめます。
6. **止める。** アプリが動いている間、コンソールは次の入力を受け付けません。コンソールの右上の赤い停止ボタンを押すか、コンソールで Esc キーを押して止めます。

```r
# app.R：地域を選ぶと、その地域の店舗の売上の図と表が変わるアプリ
library(shiny)
library(readr)
library(dplyr)
library(ggplot2)
library(lubridate)

# データ（アプリの起動時に1回だけ読む）
stores <- read_csv("data/sora_stores.csv", show_col_types = FALSE)
daily <- read_csv("data/store_sales_daily.csv", show_col_types = FALSE) |>
  left_join(select(stores, store_id, store_name, region), by = "store_id")

regions <- c("北海道・東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄")

ui <- fluidPage(
  titlePanel("そらまめマーケット 地域別の売上（架空のデータ）"),
  sidebarLayout(
    sidebarPanel(
      selectInput("region", "地域", choices = regions, selected = "関東")
    ),
    mainPanel(
      plotOutput("sales_plot"),
      tableOutput("store_table")
    )
  )
)

server <- function(input, output, session) {
  selected <- reactive({
    filter(daily, region == input$region)
  })

  output$sales_plot <- renderPlot({
    selected() |>
      mutate(month = floor_date(date, "month")) |>
      group_by(month) |>
      summarise(sales = sum(sales) / 1e6) |>
      ggplot(aes(x = month, y = sales)) +
      geom_line() +
      labs(title = paste0(input$region, "の店舗の月別売上"), x = NULL, y = "売上（百万円）")
  })

  output$store_table <- renderTable({
    selected() |>
      filter(year(date) == 2025) |>
      group_by(store_name) |>
      summarise(sales_2025 = round(sum(sales) / 1e4))
  }, digits = 0)
}

shinyApp(ui, server)
```

`fluidPage()` は画面の幅に合わせて伸び縮みするページ、`sidebarLayout()` は左に入力、右に出力を並べる配置です。`selectInput()` の引数は、ID・画面に出す見出し・選択肢の順です。関東を選ぶと、表には大宮店・柏店・船橋店・藤沢店の4店舗が出て、柏店の2025年の売上が最も多いことが分かります。日次売上のデータは50店舗のうち30店舗分なので、関東でも4店舗だけです。

## reactive で計算を1回にまとめる

図と表は、どちらも「選んだ地域の行だけ」を使います。`reactive()` は、入力に応じて変わる値を作る関数です。`selected <- reactive({ ... })` と書くと、`input$region` が変わったときだけ絞り込みをやり直し、図と表はその結果を `selected()` として（かっこを付けて）使います。同じ絞り込みを `renderPlot` と `renderTable` の両方に書くより、計算が1回で済み、直すところも1か所になります。

Shiny は、どの出力がどの入力を使っているかを自分で調べ、入力が変わったときに、それを使う出力だけを作り直します。この仕組みを**リアクティブ**（反応する）といいます。`input$region` を使っていない出力は、地域を変えても変わりません。

## つまずきやすいところ

- **データのパス。** Run App は `app.R` のあるフォルダを作業フォルダにして動きます。データは `"data/sora_stores.csv"` のように、`app.R` から見た場所で書きます。
- **library() の書き忘れ。** コンソールで `library(lubridate)` を実行してあると、Run App では動いても、新しい R では `floor_date` が見つからずに止まります。使うパッケージはすべて `app.R` の先頭に書きます。
- **エラーの場所。** 図の代わりに赤い文字が出たら、コンソールにエラーの詳しい内容が出ています。

## 自分のPCで確認する

右の欄から `check_102.R` をダウンロードして `app.R` と同じフォルダに置き、コンソールで `source("check_102.R", encoding = "UTF-8")` を実行します。確認スクリプトはアプリを起動せず、`app.R` を読み込んで画面の入力と出力を調べ、server を動かして、地域を変えると図か表が変わるかを確かめます。

## 卒論・実務での使いどころ

上司や取引先が条件を変えながら何度も見る数字（地域別・商品別の売上、在庫）は、図を毎回作って送るより、Shiny のアプリにして自分で選んでもらうほうが、頼む側も作る側も手間が減ります。
