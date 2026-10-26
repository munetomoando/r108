# 職業訓練のデータを作る（RCT 1,000人と観察データ 4,000人）。単位は万円。
#   出力: public/data/training_rct.csv, training_obs.csv
#   実行: Rscript data-raw/synth_training.R
#
# 生成式（docs/design.md 主要な生成式）
#   earn_post = 150 + 0.8*prior_earn + 5*educ_years − 0.5*(age − 35)^2 / 10 + 30*treat + ε,
#   ε ~ N(0, 60^2)。真の効果は +30万円/年
#   RCT: treat は 500人ずつ無作為に割り当てる
#   観察データ: 参加確率 logit(p) = −1 − 0.01*(prior_earn − 250) − 0.02*(age − 35)
#   （前年収入の低い人ほど参加するので、単純比較は負の値になる）
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

make_people <- function(n) {
  age <- sample(20:59, n, replace = TRUE)
  female <- rbinom(n, 1, 0.45)
  educ_years <- sample(c(12, 14, 16), n, replace = TRUE, prob = c(0.45, 0.25, 0.30))
  # 前年の年収（万円）: 学歴・年齢・性別で違い、右に裾が長い
  mu <- log(230) + 0.06 * (educ_years - 12) + 0.012 * (age - 35) - 0.20 * female
  prior_earn <- round(pmax(0, exp(mu + rnorm(n, 0, 0.45))), 1)
  tibble(age, female, educ_years, prior_earn)
}

outcome <- function(df) {
  eps <- rnorm(nrow(df), 0, 60)
  df$earn_post <- round(150 + 0.8 * df$prior_earn + 5 * df$educ_years -
                          0.5 * (df$age - 35)^2 / 10 + 30 * df$treat + eps, 1)
  df
}

rct <- make_people(1000)
rct$treat <- sample(rep(0:1, each = 500))
rct <- outcome(rct) |>
  mutate(id = row_number()) |>
  select(id, treat, age, female, educ_years, prior_earn, earn_post)

obs <- make_people(4000)
p <- plogis(-1 - 0.01 * (obs$prior_earn - 250) - 0.02 * (obs$age - 35))
obs$treat <- rbinom(nrow(obs), 1, p)
obs <- outcome(obs) |>
  mutate(id = row_number()) |>
  select(id, treat, age, female, educ_years, prior_earn, earn_post)

write_csv(rct, "public/data/training_rct.csv")
write_csv(obs, "public/data/training_obs.csv")
cat("training_rct:", nrow(rct), "行 / training_obs:", nrow(obs), "行（参加率",
    round(mean(obs$treat), 3), "）\n")
