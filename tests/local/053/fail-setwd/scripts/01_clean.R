# 01_clean.R：元データを読み、分析用のデータを作る（悪い例：setwd と絶対パス）
library(readr)
library(dplyr)

setwd("C:/Users/student/Documents/minwage")
panel <- read_csv("data/pref_panel.csv", show_col_types = FALSE)

panel_clean <- panel |>
  mutate(log_avg_wage = log(avg_wage),
         log_min_wage = log(min_wage))

dir.create("output", showWarnings = FALSE)
write_csv(panel_clean, "output/panel_clean.csv")
