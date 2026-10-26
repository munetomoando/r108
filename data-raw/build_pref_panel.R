# pref_panel.csv を作る（47都道府県×2019〜2025年、329行）。第18ステップ b の正解と同じ表。
#   出力: public/data/pref_panel.csv
#         （列: pref_code, pref, region, year, min_wage, scheduled_wage, hours, avg_wage, kaitz, population）
#   実行: Rscript data-raw/build_pref_panel.R（どのディレクトリからでもよい。通信しない）
#   入力: public/data/wage_census_pref.csv, min_wage_pref.csv, pref_basic.csv
#         （先に fetch_wage_census_pref.R, fetch_min_wage_pref.R, fetch_pref_basic.R を実行しておく）
#
# 列の定義
#   year           賃金構造基本統計調査の調査年（その年の6月分の賃金）
#   min_wage       year 年6月に効いていた地域別最低賃金＝ fiscal_year = year − 1 の額（円/時）。
#                  最低賃金は毎年10月前後に改定されるため、year 年度の額は year 年6月にはまだ効いていない
#   scheduled_wage 所定内給与額（一般労働者、男女計、千円/月）
#   hours          所定内実労働時間数（一般労働者、男女計、時間/月）
#   avg_wage       平均時給 = scheduled_wage × 1000 ÷ hours（円/時。丸めない）
#   kaitz          カイツ指標 = min_wage ÷ avg_wage（丸めない）
#   population     2020年国勢調査の人口（全年に同じ値を付ける）
#   pref, region   pref_basic の県名と8地方区分
#
# 最後に content/steps/018/step.yaml の setup と小課題 a・b の正解コードを実行し、
# 結果がこのスクリプトの表と一致することを確かめる（一致しなければ止まる）。
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
root <- if (length(file_arg)) normalizePath(file.path(dirname(sub("^--file=", "", file_arg)), "..")) else getwd()
dd <- function(f) file.path(root, "public", "data", f)

wage <- read_csv(dd("wage_census_pref.csv"), show_col_types = FALSE, progress = FALSE)
mw <- read_csv(dd("min_wage_pref.csv"), show_col_types = FALSE, progress = FALSE)
pref_basic <- read_csv(dd("pref_basic.csv"), show_col_types = FALSE, progress = FALSE)

# ---- 整形 ----
wage2 <- wage |>
  filter(sex == "男女計") |>
  mutate(avg_wage = scheduled_wage * 1000 / hours) |>
  select(pref_code, year, scheduled_wage, hours, avg_wage)
# year 年6月に効いている最低賃金は前の年度（fiscal_year = year − 1）の額
mw2 <- mw |>
  mutate(year = fiscal_year + 1) |>
  select(pref_code, year, min_wage, effective_date)

# 時期の対応の検算: 前年度の額は year 年6月1日より前に発効しており、
# 改定のあった当年度の額は6月1日より後に発効している（＝6月にはまだ効いていない）
chk <- wage2 |>
  distinct(pref_code, year) |>
  inner_join(mw2, by = c("pref_code", "year")) |>
  left_join(mw |> select(pref_code, year = fiscal_year, eff_same = effective_date,
                         mw_same = min_wage),
            by = c("pref_code", "year"))
june1 <- as.Date(paste0(chk$year, "-06-01"))
stopifnot(nrow(chk) == nrow(wage2), all(chk$effective_date < june1))
stopifnot(all(chk$eff_same > june1 | chk$eff_same == chk$effective_date))

prefs <- select(pref_basic, pref_code, pref, region, population)

# ---- 結合 ----
pref_panel <- wage2 |>
  left_join(select(mw2, -effective_date), by = c("pref_code", "year")) |>
  left_join(prefs, by = "pref_code") |>
  mutate(kaitz = min_wage / avg_wage) |>
  select(pref_code, pref, region, year, min_wage, scheduled_wage, hours,
         avg_wage, kaitz, population) |>
  arrange(pref_code, year)

# ---- 検算 ----
stopifnot(nrow(pref_panel) == 47 * 7, !anyNA(pref_panel))
stopifnot(identical(sort(unique(pref_panel$year)), as.numeric(2019:2025)))
stopifnot(nrow(distinct(pref_panel, pref_code, year)) == nrow(pref_panel))
stopifnot(all(pref_panel$kaitz > 0.35 & pref_panel$kaitz < 0.65))
stopifnot(sum(pref_panel$population[pref_panel$year == 2020]) == 126146099)

# ---- 第18ステップの正解と一致するか ----
step <- yaml::read_yaml(file.path(root, "content", "steps", "018", "step.yaml"))
ex <- step$exercises
env <- new.env(parent = globalenv())
old_wd <- setwd(file.path(root, "public"))   # アプリと同じく data/xxx.csv で読む
invisible(suppressMessages(eval(parse(text = step$setup), env)))
for (id in c("a", "b")) eval(parse(text = ex[[which(vapply(ex, `[[`, "", "id") == id)]]$solution), env)
setwd(old_wd)
stopifnot(isTRUE(all.equal(as.data.frame(env$pref_panel), as.data.frame(pref_panel),
                           check.attributes = FALSE, tolerance = 0)))
stopifnot(identical(names(env$pref_panel), names(pref_panel)))

write_csv(pref_panel, dd("pref_panel.csv"))
cat("public/data/pref_panel.csv を書き出しました（", nrow(pref_panel), "行、kaitz ",
    sprintf("%.3f〜%.3f", min(pref_panel$kaitz), max(pref_panel$kaitz)),
    "、第18ステップ b の正解と一致）\n", sep = "")
