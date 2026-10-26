# 給付型奨学金の回帰不連続デザイン用データ（学生5,000人）。単位は万円。
#   出力: public/data/scholarship_rdd.csv
#   実行: Rscript data-raw/synth_scholarship_rdd.R
#
# 生成式（docs/design.md 主要な生成式）
#   gpa ~ N(2.8, 0.5^2) を0〜4に切り詰め（範囲外は0または4にする）。小数2桁に丸める
#   scholarship = 1（gpa ≥ 3.0）
#   earn30 = 400 + 60*(gpa − 3) + 25*scholarship + ε,  ε ~ N(0, 80^2)
#   female は年収に影響しない
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

n <- 5000
gpa <- round(pmin(4, pmax(0, rnorm(n, 2.8, 0.5))), 2)
scholarship <- as.integer(gpa >= 3.0)
female <- rbinom(n, 1, 0.5)
earn30 <- round(400 + 60 * (gpa - 3) + 25 * scholarship + rnorm(n, 0, 80), 1)
rdd <- tibble(id = seq_len(n), gpa, scholarship, female, earn30)

write_csv(rdd, "public/data/scholarship_rdd.csv")
cat("scholarship_rdd:", nrow(rdd), "行（受給率", round(mean(scholarship), 3), "）\n")
