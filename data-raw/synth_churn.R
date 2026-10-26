# 顧客単位の解約データを ec_* から作る。
#   入力: public/data/ec_customers.csv, ec_orders.csv（先に data-raw/synth_ec.R を実行）
#   出力: public/data/churn.csv
#   実行: Rscript data-raw/synth_churn.R
#
# 定義
#   - 特徴量は 2024年1月1日〜2025年9月30日 の注文から作る（基準日 2025-09-30）
#     recency  : 基準日から最後の注文日までの日数
#     frequency: 注文件数（order_id の数）
#     monetary : 購入金額の合計（qty × unit_price、円）
#   - churned: 2025年10〜12月に注文が1件もなければ 1（解約）。解約率は約25%
# 乱数は使わないが、他のスクリプトとそろえて set.seed(108) を置く。
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

out_dir <- "public/data"
customers <- read_csv(file.path(out_dir, "ec_customers.csv"), show_col_types = FALSE)
orders <- read_csv(file.path(out_dir, "ec_orders.csv"),
                   col_types = cols(product_id = col_character(), order_date = col_date()))

as_of <- as.Date("2025-09-30")
feat <- orders |>
  filter(order_date <= as_of) |>
  group_by(customer_id) |>
  summarise(recency = as.integer(as_of - max(order_date)),
            frequency = n_distinct(order_id),
            monetary = sum(qty * unit_price), .groups = "drop")
active_q4 <- orders |>
  filter(order_date >= as.Date("2025-10-01"), order_date <= as.Date("2025-12-31")) |>
  distinct(customer_id)

churn <- customers |>
  inner_join(feat, by = "customer_id") |>
  mutate(churned = as.integer(!customer_id %in% active_q4$customer_id)) |>
  select(customer_id, recency, frequency, monetary, age, channel, rank, churned)
stopifnot(nrow(churn) == nrow(customers), !anyNA(churn))

write_csv(churn, file.path(out_dir, "churn.csv"))
cat("churn:", nrow(churn), "行（解約率", round(mean(churn$churned) * 100, 1), "%）\n")
