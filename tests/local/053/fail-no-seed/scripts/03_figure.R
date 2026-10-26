# 03_figure.R：2025年の散布図を保存する
# 入力：output/panel_clean.csv（01_clean.R が作る）
# 出力：output/fig_scatter.png
library(readr)
library(dplyr)
library(ggplot2)
library(here)

panel_clean <- read_csv(here("output", "panel_clean.csv"), show_col_types = FALSE)
p2025 <- filter(panel_clean, year == 2025)

p <- ggplot(p2025, aes(x = min_wage, y = avg_wage)) +
  geom_point() +
  geom_smooth(method = "lm", formula = y ~ x) +
  labs(x = "最低賃金（円/時、2024年度）", y = "平均時給（円/時、2025年6月）") +
  theme_minimal()
ggsave(here("output", "fig_scatter.png"), plot = p, width = 6, height = 4, dpi = 150)
