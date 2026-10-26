# 01_clean.R：元データを読み、分析用のデータを作る
# 入力：data/pref_panel.csv（アプリからダウンロードしたまま。手で直さない）
# 出力：output/panel_clean.csv
library(readr)
library(dplyr)
library(here)

panel <- read_csv(here("data", "pref_panel.csv"), show_col_types = FALSE)

panel_clean <- panel |>
  mutate(log_avg_wage = log(avg_wage),
         log_min_wage = log(min_wage))

dir.create(here("output"), showWarnings = FALSE)
write_csv(panel_clean, here("output", "panel_clean.csv"))
