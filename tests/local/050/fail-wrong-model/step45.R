# 第45ステップ：教科書の賃金関数を再現し、日本の架空データと比べる
library(readr)
library(dplyr)
library(modelsummary)

wage1 <- wooldridge::wage1
wage <- read_csv("data/wage_survey.csv", show_col_types = FALSE)

m_ex7 <- lm(log(wage) ~ female * educ + exper + I(exper^2) + tenure + I(tenure^2), data = wage1)
m_jp <- lm(log_wage ~ female * educ_years + exper + I(exper^2) + tenure, data = wage)

tab_cmp <- modelsummary(list("米国1976年" = m_ex7, "日本（架空）" = m_jp),
  output = "markdown", fmt = 4, gof_map = c("nobs", "r.squared"),
  coef_rename = c(educ_years = "educ", "female:educ_years" = "female:educ"))
tab_cmp
