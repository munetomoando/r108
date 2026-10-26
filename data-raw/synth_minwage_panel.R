# 47県×2012〜2024年の架空パネル（最低賃金の「特別引上げ」という架空の政策）。
#   出力: public/data/minwage_panel.csv
#   実行: Rscript data-raw/synth_minwage_panel.R
#
# 生成式（docs/design.md 主要な生成式）
#   youth_emp_rate = 県効果 + 年効果（2020年に全国一律 −2pt）
#                    + 処置効果（経過0年 −0.5、1年 −0.8、2年以降 −1.0） + ε,  ε ~ N(0, 0.6^2)
#   処置: 12県で2019年から。年効果は全県共通なので処置前は平行トレンドが成り立つ
#   adult_emp_rate = 県効果 + 年効果 + ε（処置効果なし＝プラセボ）
#   post は 2019年以降で 1（全県共通）。処置効果は treated × post
#   min_wage（円/時）は県ごとの水準に毎年の引上げを加え、処置県は2019年以降さらに上乗せ
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

years <- 2012:2024
pref_code <- 1:47
# 処置県（架空）: 最低賃金の低い地方の12県
treated_prefs <- c(2, 3, 5, 6, 31, 32, 39, 41, 42, 44, 45, 46)

# 誤差（県×年、ε ~ N(0, 0.6^2)）。行は県、列は年
eps_youth <- matrix(rnorm(47 * length(years), 0, 0.6), nrow = 47)
eps_adult <- matrix(rnorm(47 * length(years), 0, 0.6), nrow = 47)

# 県効果（水準）
youth_pref <- rnorm(47, 42, 3)
adult_pref <- rnorm(47, 74, 2.5)
mw_base <- round(rnorm(47, 700, 40) - 30 * (pref_code %in% treated_prefs))  # 2012年の最低賃金
# 年効果: 緩やかな上昇 + 2020年に全国一律の落ち込み
youth_year <- 0.25 * (years - 2012) + ifelse(years == 2020, -2, 0)
adult_year <- 0.15 * (years - 2012) + ifelse(years == 2020, -1, 0)

panel <- expand.grid(year = years, pref_code = pref_code) |>
  as_tibble() |>
  select(pref_code, year) |>
  mutate(treated = as.integer(pref_code %in% treated_prefs),
         post = as.integer(year >= 2019),
         rel_year = year - 2019,
         effect = case_when(treated == 0 | rel_year < 0 ~ 0,
                            rel_year == 0 ~ -0.5,
                            rel_year == 1 ~ -0.8,
                            TRUE ~ -1.0),
         youth_emp_rate = youth_pref[pref_code] + youth_year[year - 2011] + effect +
           eps_youth[cbind(pref_code, year - 2011)],
         adult_emp_rate = adult_pref[pref_code] + adult_year[year - 2011] +
           eps_adult[cbind(pref_code, year - 2011)],
         min_wage = mw_base[pref_code] + 22 * (year - 2012) +
           ifelse(treated == 1 & year >= 2019, 40 + 10 * (year - 2019), 0) +
           round(rnorm(n(), 0, 3)),
         youth_emp_rate = round(youth_emp_rate, 1),
         adult_emp_rate = round(adult_emp_rate, 1)) |>
  select(pref_code, year, treated, post, min_wage, youth_emp_rate, adult_emp_rate)

write_csv(panel, "public/data/minwage_panel.csv")
cat("minwage_panel:", nrow(panel), "行（処置県:", paste(treated_prefs, collapse = ", "), "）\n")
