# app.R：地域を選ぶと、その地域の店舗の売上の図と表が変わるアプリ
library(shiny)
library(readr)
library(dplyr)
library(ggplot2)
library(lubridate)

# ---- データ（アプリの起動時に1回だけ読む）----
stores <- read_csv("data/sora_stores.csv", show_col_types = FALSE)
daily <- read_csv("data/store_sales_daily.csv", show_col_types = FALSE) |>
  left_join(select(stores, store_id, store_name, region), by = "store_id")

regions <- c("北海道・東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄")

# ---- ui：画面の部品と配置 ----
ui <- fluidPage(
  titlePanel("そらまめマーケット 地域別の売上（架空のデータ）"),
  sidebarLayout(
    sidebarPanel(
      selectInput("region", "地域", choices = regions, selected = "関東")
    ),
    mainPanel(
      plotOutput("plot"),
      tableOutput("store_table")
    )
  )
)

# ---- server：入力を受けて出力を作る ----
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
