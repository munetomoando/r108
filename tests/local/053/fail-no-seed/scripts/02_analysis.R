# 02_analysis.R：2025年の47県で回帰し、ブートストラップで標準誤差を求める
# 入力：output/panel_clean.csv（01_clean.R が作る）
# 出力：output/result.csv
library(readr)
library(dplyr)
library(here)

panel_clean <- read_csv(here("output", "panel_clean.csv"), show_col_types = FALSE)
p2025 <- filter(panel_clean, year == 2025)

m <- lm(log_avg_wage ~ log_min_wage, data = p2025)

# 47県から重複を許して47県を選び直し、傾きを1000回計算する
slopes <- replicate(1000, {
  p_boot <- slice_sample(p2025, prop = 1, replace = TRUE)
  coef(lm(log_avg_wage ~ log_min_wage, data = p_boot))[["log_min_wage"]]
})

result <- tibble(
  estimate = coef(m)[["log_min_wage"]],
  se_boot  = sd(slopes),
  ci_low   = quantile(slopes, 0.025),
  ci_high  = quantile(slopes, 0.975)
)
write_csv(result, here("output", "result.csv"))
