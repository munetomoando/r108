# 賃金調査風の架空の個票（3,000人）を作る。
#   出力: public/data/wage_survey.csv
#   実行: Rscript data-raw/synth_wage_survey.R
#
# 生成式（docs/design.md 主要な生成式。変えるときは設計書を先に更新する）
#   log_wage = a + 0.07*educ_years + 0.035*exper − 0.0006*exper^2 + 0.01*tenure − 0.12*female
#              + 企業規模の上乗せ（〜29人 0、30〜299人 0.05、300〜999人 0.10、1000人以上 0.18）
#              + 0.15*regular + ε
#   ε ~ N(0, (0.25 + 0.02*(educ_years − 12))^2)   … 学歴とともに分散が大きい（不均一分散）
#   切片 a は時給の中央値が1,900円になるよう調整する
#   educ_years は 12・14・16・18年を 35・20・40・5% で割り当てる
#   industry は賃金に影響しない（生成式に入っていない）
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

n <- 3000
female <- rbinom(n, 1, 0.5)
educ_years <- sample(c(12, 14, 16, 18), n, replace = TRUE, prob = c(0.35, 0.20, 0.40, 0.05))
age <- sample(22:64, n, replace = TRUE)
too_young <- age < educ_years + 6
age[too_young] <- educ_years[too_young] + 6 + sample(0:5, sum(too_young), replace = TRUE)
exper <- age - educ_years - 6                       # 潜在的な経験年数
tenure <- floor(exper * rbeta(n, 1.5, 1.5))         # 勤続年数（経験年数以下）
firm_levels <- c("〜29人", "30〜299人", "300〜999人", "1000人以上")
firm_size <- sample(firm_levels, n, replace = TRUE, prob = c(0.25, 0.35, 0.15, 0.25))
firm_eff <- c(0, 0.05, 0.10, 0.18)[match(firm_size, firm_levels)]
regular <- rbinom(n, 1, ifelse(female == 1, 0.55, 0.80))
industry <- sample(c("製造業", "卸売業・小売業", "医療・福祉", "情報通信業",
                     "建設業", "宿泊・飲食サービス業", "その他のサービス業"),
                   n, replace = TRUE, prob = c(0.20, 0.17, 0.15, 0.10, 0.08, 0.08, 0.22))

eps <- rnorm(n, 0, 0.25 + 0.02 * (educ_years - 12))
xb <- 0.07 * educ_years + 0.035 * exper - 0.0006 * exper^2 + 0.01 * tenure -
  0.12 * female + firm_eff + 0.15 * regular
a <- log(1900) - median(xb + eps)                   # 中央値が1,900円になる切片
hourly_wage <- round(exp(a + xb + eps))
wage_survey <- tibble(
  id = seq_len(n), female, age, educ_years, exper, tenure, firm_size, regular, industry,
  hourly_wage, log_wage = round(log(hourly_wage), 4)
)

write_csv(wage_survey, "public/data/wage_survey.csv")
cat("wage_survey:", nrow(wage_survey), "行（切片 a =", round(a, 4),
    "、時給の中央値", median(hourly_wage), "円）\n")
