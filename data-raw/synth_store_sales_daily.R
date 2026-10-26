# そらまめマーケットの30店舗×2023〜2025年の日次売上を作る（第11部）。
#   店舗は sora_stores.csv（第1部）の50店舗から30店舗を選ぶ。store_id と所在地は sora_stores と同じ
#   出力: public/data/store_sales_daily.csv
#   実行: Rscript data-raw/synth_store_sales_daily.R（synth_sora_stores.R の後）
#
# 仕込んだ「答え」（対数で加法的に効く）
#   log(sales) = 店舗の水準 + 曜日効果 + 月効果 + 店舗ごとの年の伸び（sora_stores の前年比）
#                + log(1.01)*temp + log(1.15)*holiday + log(0.90)*rain + ε,  ε ~ N(0, 0.08^2)
#   すなわち 気温1℃で +1%、祝日 +15%、雨 −10%
#   holiday は国民の祝日・振替休日（土日そのものは曜日効果で表す）
#   気温は県ごとの平年値＋季節変動＋日々の揺れ。雨の確率は6・9月に高い
#   店舗の水準は、2025年の合計が sora_stores の sales（今年の売上）と一致するように合わせる
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})
set.seed(108)

sora <- read_csv("public/data/sora_stores.csv", show_col_types = FALSE)
pref_codes <- c("北海道" = 1, "宮城県" = 4, "福島県" = 7, "埼玉県" = 11, "千葉県" = 12, "東京都" = 13,
                "神奈川県" = 14, "新潟県" = 15, "石川県" = 17, "長野県" = 20, "静岡県" = 22,
                "愛知県" = 23, "京都府" = 26, "大阪府" = 27, "兵庫県" = 28, "岡山県" = 33,
                "広島県" = 34, "山口県" = 35, "香川県" = 37, "愛媛県" = 38, "福岡県" = 40,
                "熊本県" = 43, "鹿児島県" = 46, "沖縄県" = 47)
stopifnot(all(sora$pref %in% names(pref_codes)))

holidays <- as.Date(c(
  # 2023年
  "2023-01-01", "2023-01-02", "2023-01-09", "2023-02-11", "2023-02-23", "2023-03-21",
  "2023-04-29", "2023-05-03", "2023-05-04", "2023-05-05", "2023-07-17", "2023-08-11",
  "2023-09-18", "2023-09-23", "2023-10-09", "2023-11-03", "2023-11-23",
  # 2024年
  "2024-01-01", "2024-01-08", "2024-02-11", "2024-02-12", "2024-02-23", "2024-03-20",
  "2024-04-29", "2024-05-03", "2024-05-04", "2024-05-05", "2024-05-06", "2024-07-15",
  "2024-08-11", "2024-08-12", "2024-09-16", "2024-09-22", "2024-09-23", "2024-10-14",
  "2024-11-03", "2024-11-04", "2024-11-23",
  # 2025年
  "2025-01-01", "2025-01-13", "2025-02-11", "2025-02-23", "2025-02-24", "2025-03-20",
  "2025-04-29", "2025-05-03", "2025-05-04", "2025-05-05", "2025-05-06", "2025-07-21",
  "2025-08-11", "2025-09-15", "2025-09-23", "2025-10-13", "2025-11-03", "2025-11-23",
  "2025-11-24"))

n_store <- 30
stores <- sora |>
  slice(sort(sample(nrow(sora), n_store))) |>
  transmute(store_id, pref_code = unname(pref_codes[pref]),
            growth = log(sales / sales_last), target_2025 = sales * 10000) |>
  mutate(temp_mean = 8.5 + 0.17 * (pref_code - 1) + ifelse(pref_code == 47, 6, 0))

dates <- seq(as.Date("2023-01-01"), as.Date("2025-12-31"), by = "day")
dow_eff <- log(c(1.15, 0.90, 0.90, 0.92, 0.95, 1.05, 1.20))       # 日〜土
month_eff <- log(c(0.95, 0.90, 1.00, 1.00, 1.02, 0.97, 1.00, 1.05, 0.97, 1.00, 1.02, 1.15))
rain_p <- c(0.25, 0.25, 0.30, 0.30, 0.30, 0.50, 0.35, 0.30, 0.45, 0.30, 0.25, 0.20)

sales <- lapply(seq_len(n_store), function(s) {
  doy <- yday(dates)
  # 日々の気温の揺れは自己相関あり（AR(1)）
  shock <- as.numeric(stats::filter(rnorm(length(dates), 0, 1.6), 0.6, method = "recursive"))
  temp <- round(stores$temp_mean[s] - 10 * cos(2 * pi * (doy - 20) / 365) + shock, 1)
  rain <- rbinom(length(dates), 1, rain_p[month(dates)])
  holiday <- as.integer(dates %in% holidays)
  log_sales <- dow_eff[wday(dates)] + month_eff[month(dates)] +
    stores$growth[s] * (year(dates) - 2025) +
    log(1.01) * temp + log(1.15) * holiday + log(0.90) * rain + rnorm(length(dates), 0, 0.08)
  # 店舗の水準: 2025年の合計を sora_stores の今年の売上にそろえる
  y <- exp(log_sales)
  y <- y * stores$target_2025[s] / sum(y[year(dates) == 2025])
  tibble(date = dates, store_id = stores$store_id[s], pref_code = stores$pref_code[s],
         temp, rain, holiday, sales = round(y))
})
store_sales <- bind_rows(sales) |> arrange(date, store_id)

write_csv(store_sales, "public/data/store_sales_daily.csv")
cat("store_sales_daily:", nrow(store_sales), "行\n")
