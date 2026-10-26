# 架空の企業「そらまめマーケット」のネット通販（オンラインストア）のデータを作る（顧客・商品・注文明細）。
# 店舗は食品中心だが、ネット通販では日用品・家電・本なども扱う設定。
#   出力: public/data/ec_customers.csv, ec_products.csv, ec_products.xlsx, ec_orders.csv
#   実行: Rscript data-raw/synth_ec.R（プロジェクトのルートで）
#
# 仕込んだ「答え」（docs/design.md サンプルデータ仕様 (B)）
#   - 年齢・流入経路で購買頻度が違う（30〜40代・紹介経由ほど多く買う）
#   - 季節性: 注文件数は12月 +30%、8月 −10%
#   - クーポン（20%引き）は注文単位で無作為に付与（約20%の注文）。
#     数量の平均がクーポンありで 0.8^(−1.5) ≒ 1.40 倍になる（価格弾力性 −1.5）
#   - 2025年6月から10県で広告キャンペーン（注文件数 +8%）
#   - 顧客マスタにない顧客ID（退会済み）の注文を少数含める（第14ステップ anti_join 用）
#   - 商品IDは先頭が0の5桁（"00012" など）。CSVでは文字列として書き、read_csv は文字列のまま読む
#     （read.csv では数値になり0が消える）。Excel版は「Excelで開いて保存し直した」想定で
#     商品IDを数値として保存してあるため、read_excel では 12 のような数値になり0が消える（第10ステップ c）
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(lubridate)
})
set.seed(108)

out_dir <- "public/data"
pref_basic <- read_csv(file.path(out_dir, "pref_basic.csv"), show_col_types = FALSE)

# ---- 商品マスタ ---------------------------------------------------------------
cats <- tibble::tribble(
  ~category,      ~n,  ~price_med, ~price_sd, ~popularity, ~m0,
  "食品",         40,   900,       0.5,       1.6,         0.8,
  "飲料",         25,   700,       0.4,       1.4,         1.0,
  "日用品",       30,   800,       0.5,       1.2,         0.6,
  "美容・健康",   25,  2500,       0.6,       0.9,         0.4,
  "キッチン用品", 20,  2000,       0.6,       0.7,         0.2,
  "家電",         15,  9000,       0.7,       0.4,         0.05,
  "衣料品",       25,  3500,       0.5,       0.8,         0.3,
  "本・文具",     20,  1200,       0.5,       0.8,         0.2
)
products <- cats[rep(seq_len(nrow(cats)), cats$n), ]
n_prod <- nrow(products)
raw_price <- products$price_med * exp(rnorm(n_prod, 0, products$price_sd))
products$list_price <- pmax(180, round(raw_price / 100) * 100 - 20)
products$unit_cost <- round(products$list_price * runif(n_prod, 0.45, 0.70))
products$weight <- products$popularity * rgamma(n_prod, shape = 2, rate = 2)
products$product_id <- sprintf("%05d", sort(sample(1:999, n_prod)))[sample(n_prod)]
products <- products |> arrange(product_id)

ec_products <- products |> select(product_id, category, list_price, unit_cost)

# ---- 顧客マスタ ---------------------------------------------------------------
n_cust <- 5000
# 3割は2024年より前からの既存顧客、7割は2024年1月〜2025年6月の新規
is_old <- runif(n_cust) < 0.30
signup <- ifelse(is_old,
                 as.Date("2022-01-01") + sample(0:729, n_cust, replace = TRUE),
                 as.Date("2024-01-01") + sample(0:546, n_cust, replace = TRUE))
signup <- as.Date(signup, origin = "1970-01-01")

age <- pmin(79, pmax(18, round(rnorm(n_cust, 42, 13))))
gender <- sample(c("女性", "男性", "無回答"), n_cust, replace = TRUE, prob = c(0.55, 0.42, 0.03))
pref_code <- sample(pref_basic$pref_code, n_cust, replace = TRUE, prob = pref_basic$population)
channel <- sample(c("検索", "SNS", "広告", "紹介"), n_cust, replace = TRUE,
                  prob = c(0.40, 0.25, 0.25, 0.10))

age_eff <- case_when(age < 30 ~ -0.15, age < 50 ~ 0.20, age < 65 ~ 0.10, TRUE ~ -0.10)
ch_eff <- c(検索 = 0, SNS = -0.10, 広告 = -0.20, 紹介 = 0.25)[channel]
lambda0 <- 0.55                                   # 月あたり注文件数の基準
lambda <- lambda0 * exp(age_eff + ch_eff) * rgamma(n_cust, shape = 5, rate = 5)
haz_mult <- c(検索 = 1.0, SNS = 1.2, 広告 = 1.5, 紹介 = 0.7)[channel] * ifelse(age < 30, 1.3, 1)
hazard <- pmin(0.5, 0.004 * haz_mult)              # 月ごとの離脱確率

# 会員ランク（購買の多さと相関するが完全には一致しない）
value_score <- log(lambda) - log(hazard) + rnorm(n_cust, 0, 0.5)
q <- quantile(value_score, c(0.50, 0.85))
rank <- case_when(value_score >= q[2] ~ "ゴールド", value_score >= q[1] ~ "シルバー", TRUE ~ "ブロンズ")

cust <- tibble(signup_date = signup, age, gender, pref_code, channel, rank,
               lambda, hazard) |>
  arrange(signup_date) |>
  mutate(customer_id = sprintf("C%05d", row_number()))

ec_customers <- cust |> select(customer_id, signup_date, age, gender, pref_code, channel, rank)

# ---- 注文（月ごとの件数を発生させる） -------------------------------------------
months <- seq(as.Date("2024-01-01"), as.Date("2025-12-01"), by = "month")
season <- ifelse(month(months) == 12, 1.30, ifelse(month(months) == 8, 0.90, 1.00))
campaign_prefs <- c(4, 8, 9, 10, 22, 26, 28, 34, 40, 43)   # 宮城 茨城 栃木 群馬 静岡 京都 兵庫 広島 福岡 熊本
campaign_start <- as.Date("2025-06-01")

start_month <- pmax(floor_date(cust$signup_date, "month"), as.Date("2024-01-01"))
start_idx <- match(start_month, months)
# 離脱月（この月以降は注文しない）
dropout_idx <- start_idx + rgeom(n_cust, cust$hazard) + 1

wday_w <- c(1.30, 1.00, 0.95, 0.95, 1.00, 1.05, 1.25)  # 日曜〜土曜

order_list <- vector("list", n_cust)
for (i in seq_len(n_cust)) {
  rows <- list()
  if (cust$signup_date[i] >= as.Date("2024-01-01")) {
    rows[[1]] <- cust$signup_date[i]                  # 新規顧客は登録日に初回注文
  }
  if (start_idx[i] <= length(months)) {
    for (m in start_idx[i]:min(length(months), dropout_idx[i] - 1)) {
      first_day <- months[m]
      last_day <- ceiling_date(first_day, "month") - 1
      if (m == start_idx[i] && cust$signup_date[i] > first_day) first_day <- cust$signup_date[i] + 1
      if (first_day > last_day) next
      days <- seq(first_day, last_day, by = "day")
      frac <- length(days) / days_in_month(months[m])
      camp <- if (cust$pref_code[i] %in% campaign_prefs && months[m] >= campaign_start) 1.08 else 1
      n <- rpois(1, cust$lambda[i] * season[m] * camp * frac)
      if (n > 0) {
        w <- wday_w[wday(days)]
        rows[[length(rows) + 1]] <- days[sample.int(length(days), n, replace = TRUE, prob = w)]
      }
    }
  }
  d <- if (length(rows)) do.call(c, rows) else as.Date(character())
  # 2024年1月〜2025年9月に1件も注文がない顧客には1件足す（顧客分析の分母をそろえるため）
  if (!any(d <= as.Date("2025-09-30"))) {
    lo <- max(cust$signup_date[i], as.Date("2024-01-01"))
    d <- c(d, lo + sample.int(as.integer(as.Date("2025-09-30") - lo) + 1, 1) - 1)
  }
  order_list[[i]] <- tibble(customer_id = cust$customer_id[i], order_date = d)
}
orders <- bind_rows(order_list)

# 顧客マスタにない顧客（退会済み）の注文を25件
ghost <- tibble(customer_id = sprintf("C%05d", sample(5001:5400, 25)),
                order_date = as.Date("2024-01-01") + sample(0:730, 25, replace = TRUE))
orders <- bind_rows(orders, ghost) |>
  arrange(order_date, customer_id) |>
  mutate(order_id = sprintf("O%06d", row_number()),
         coupon = as.integer(runif(n()) < 0.20))

# ---- 注文明細（1注文1〜5商品、平均1.1商品） ----------------------------------------------------
n_lines <- pmin(5, 1 + rpois(nrow(orders), 0.12))
lines <- orders[rep(seq_len(nrow(orders)), n_lines), ]
pid_idx <- unlist(lapply(n_lines, function(k) sample.int(n_prod, k, prob = products$weight)))
lines$product_id <- products$product_id[pid_idx]
m0 <- products$m0[pid_idx]
lp <- products$list_price[pid_idx]
# 数量 = 1 + Poisson(m)。平均数量はクーポンありで (0.8)^(-1.5) 倍
mult <- 0.8^(-1.5)
m <- ifelse(lines$coupon == 1, (1 + m0) * mult - 1, m0)
lines$qty <- 1L + rpois(nrow(lines), m)
lines$unit_price <- ifelse(lines$coupon == 1, round(lp * 0.8), lp)

ec_orders <- lines |>
  select(order_id, customer_id, order_date, product_id, qty, unit_price, coupon)

# ---- 書き出し -------------------------------------------------------------------
write_csv(ec_customers, file.path(out_dir, "ec_customers.csv"))
write_csv(ec_products, file.path(out_dir, "ec_products.csv"))
write_csv(ec_orders, file.path(out_dir, "ec_orders.csv"))

# Excel版: 1枚目に説明、2枚目に商品一覧（第10ステップでシート指定を練習する）
note <- data.frame(項目 = c("データ名", "内容", "シート「商品一覧」", "作成"),
                   説明 = c("そらまめマーケット 商品マスタ（架空）",
                            "商品200点・8カテゴリ。価格は税込・円",
                            "product_id（数値）, category, list_price, unit_cost",
                            "data-raw/synth_ec.R（合成データ）"))
xlsx_path <- file.path(out_dir, "ec_products.xlsx")
xlsx_products <- ec_products |> mutate(product_id = as.integer(product_id))
writexl::write_xlsx(list(説明 = note, 商品一覧 = as.data.frame(xlsx_products)), xlsx_path)
source("data-raw/normalize_xlsx.R")
normalize_xlsx(xlsx_path)

cat("ec_customers:", nrow(ec_customers), "行 / ec_products:", nrow(ec_products),
    "行 / ec_orders:", nrow(ec_orders), "行（注文", n_distinct(ec_orders$order_id), "件）\n")
