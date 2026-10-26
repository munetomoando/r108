# A/Bテストのデータを作る（訪問者20,000人）と、割当比率が崩れた版（SRM）。
#   出力: public/data/ab_test.csv, ab_test_srm.csv
#   実行: Rscript data-raw/synth_ab_test.R
#
# 仕込んだ「答え」
#   - ab_test: A・B 各10,000人。購入率 A 4.0%・B 5.2%（件数を固定して割り当てるので実現値もほぼこの値）
#     デバイス別: スマホ（6割）A 3.5% → B 5.1%（+1.6pt）、PC（4割）A 4.75% → B 5.35%（+0.6pt）
#     購入者1人当たりの売上は群によらず同じ分布（対数正規、平均およそ6,000円）
#   - ab_test_srm: 割当の不具合で、B群に入るはずの訪問者のうち購入しなかったPC利用者の一部（400人）が
#     記録から落ちた版。A 10,200人・B 9,800人（51:49）。B の購入率が見かけ上高くなる
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

out_dir <- "public/data"
rates <- tibble::tribble(
  ~group, ~device, ~p,
  "A",    "スマホ", 0.0350,
  "A",    "PC",     0.0475,
  "B",    "スマホ", 0.0510,
  "B",    "PC",     0.0535
)

make_group <- function(g, n, share_sp = 0.6) {
  n_sp <- round(n * share_sp)
  dev <- c(rep("スマホ", n_sp), rep("PC", n - n_sp))
  conv <- integer(n)
  for (d in c("スマホ", "PC")) {
    idx <- which(dev == d)
    p <- rates$p[rates$group == g & rates$device == d]
    conv[idx[sample.int(length(idx), round(length(idx) * p))]] <- 1L
  }
  tibble(group = g, device = dev, converted = conv)
}

add_revenue <- function(df) {
  df$revenue <- ifelse(df$converted == 1, round(rlnorm(nrow(df), log(5000), 0.6), -1), 0)
  df
}

finish <- function(df) {
  df |>
    slice_sample(prop = 1) |>
    mutate(visitor_id = sprintf("V%05d", row_number())) |>
    select(visitor_id, group, device, converted, revenue)
}

ab <- bind_rows(make_group("A", 10000), make_group("B", 10000)) |> add_revenue() |> finish()

srm_base <- bind_rows(make_group("A", 10200), make_group("B", 10200)) |> add_revenue()
drop_idx <- sample(which(srm_base$group == "B" & srm_base$device == "PC" & srm_base$converted == 0), 400)
ab_srm <- srm_base[-drop_idx, ] |> finish()

write_csv(ab, file.path(out_dir, "ab_test.csv"))
write_csv(ab_srm, file.path(out_dir, "ab_test_srm.csv"))
cat("ab_test:", nrow(ab), "行 / ab_test_srm:", nrow(ab_srm), "行\n")
print(ab |> group_by(group) |> summarise(n = n(), rate = mean(converted)))
