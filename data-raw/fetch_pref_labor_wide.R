# pref_labor_wide.csv を作る（47都道府県×国勢調査5回の就業率、横長）。
#   出力: public/data/pref_labor_wide.csv（列: pref, 2000, 2005, 2010, 2015, 2020）
#   実行: Rscript data-raw/fetch_pref_labor_wide.R（プロジェクトのルートで。通信しない）
#   入力: data-raw/raw/pref_labor_wide/ に保存した e-Stat の公表ファイル（出所・取得日は同フォルダの SOURCES.md）
#     ro02.xlsx  国勢調査 時系列データ 第2表「労働力状態（3区分），男女別人口及び労働力率（15歳以上）
#                － 都道府県（昭和25年～令和2年）」
#     ro01.xlsx  同 第1表「… － 全国（昭和25年～令和2年）」（全国値との検算用）
#
# 就業率の定義（5回とも同じ）
#   就業率(%) = 就業者 ÷（15歳以上人口 − 労働力状態「不詳」）× 100、小数1桁（四捨五入）
#   ・労働力状態「不詳」= 15歳以上人口（総数）− 労働力人口 − 非労働力人口
#   ・5回とも原数値（不詳補完をしていない値）を使う。2015・2020年は表に不詳補完値（※の列）も
#     載っているが、2000〜2010年には補完値が無いので使わない
#   ・不詳を分母から除くのは、表の「労働力率」と同じ扱い（表の注2）
suppressMessages(library(readxl))

raw_dir <- file.path("data-raw", "raw", "pref_labor_wide")
years <- c(2000, 2005, 2010, 2015, 2020)

# 表を読み、年（原数値の列だけ）×地域×男女×労働力状態 の縦持ちにする
read_ro <- function(path, has_area) {
  d <- suppressMessages(read_excel(path, col_names = FALSE, col_types = "text"))
  # 見出し: 「1950年」…の西暦の行と、不詳補完値の列に付く「※」の行を探す
  yr_row <- which(apply(d, 1, function(r) sum(grepl("^[0-9]{4}年$", r)) >= 10))[1]
  yr <- suppressWarnings(as.integer(sub("年$", "", unlist(d[yr_row, ]))))
  star <- unlist(d[yr_row + 1, ])
  star[is.na(star)] <- ""
  keep <- which(yr %in% years & star != "※")          # 原数値の列
  stopifnot(length(keep) == length(years), identical(yr[keep], as.integer(years)))
  first_col <- if (has_area) 4 else 3                   # 単位（（人）・（％））の列
  body <- d[(yr_row + 2):nrow(d), ]
  body <- body[!is.na(body[[first_col]]), ]
  out <- data.frame(
    area   = if (has_area) body[[1]] else "00000_全国",
    sex    = body[[first_col - 2]],
    status = body[[first_col - 1]],
    stringsAsFactors = FALSE
  )
  vals <- lapply(keep, function(j) as.numeric(body[[j]]))
  names(vals) <- as.character(years)
  cbind(out, as.data.frame(vals, check.names = FALSE))
}

# 総数（男女計）の4項目から就業率を計算する
emp_rate_table <- function(long) {
  t <- long[long$sex == "総数", ]
  get <- function(s) t[t$status == s, c("area", as.character(years))]
  tot <- get("総数"); lf <- get("労働力人口"); emp <- get("就業者"); nlf <- get("非労働力人口")
  stopifnot(identical(tot$area, lf$area), identical(tot$area, emp$area), identical(tot$area, nlf$area))
  num <- as.matrix(emp[, -1]); den <- as.matrix(lf[, -1]) + as.matrix(nlf[, -1])
  unknown <- as.matrix(tot[, -1]) - den
  stopifnot(all(unknown >= 0), all(as.matrix(lf[, -1]) >= num))
  list(area = tot$area, emp = num, den = den, unknown = unknown, total = as.matrix(tot[, -1]))
}

# 四捨五入（R の round() は偶数丸めになる場合があるので使わない）
round_half_up <- function(x, digits = 1) floor(x * 10^digits + 0.5) / 10^digits

pref_long <- read_ro(file.path(raw_dir, "ro02.xlsx"), has_area = TRUE)
nat_long  <- read_ro(file.path(raw_dir, "ro01.xlsx"), has_area = FALSE)

p <- emp_rate_table(pref_long)
n <- emp_rate_table(nat_long)

pref_code <- as.integer(substr(p$area, 1, 2))
pref_name <- sub("^[0-9]{5}_", "", p$area)
stopifnot(identical(pref_code, 1:47), grepl("[都道府県]$", pref_name))

rate <- round_half_up(p$emp / p$den * 100, 1)
pref_labor_wide <- data.frame(pref = pref_name, rate, check.names = FALSE)
names(pref_labor_wide) <- c("pref", as.character(years))

# ---- 検算 ----
stopifnot(nrow(pref_labor_wide) == 47, !anyNA(pref_labor_wide))
# 47都道府県の合計が全国に一致する（就業者・分母・15歳以上人口）
stopifnot(all(colSums(p$emp) == n$emp), all(colSums(p$den) == n$den), all(colSums(p$total) == n$total))
# 値の範囲
stopifnot(all(rate > 40 & rate < 75))
# 表の「労働力率」（不詳を除いて算出）を、同じ分母で再現できる（2020年は小数5桁で公表）
lfr_pub <- pref_long[pref_long$sex == "総数" & pref_long$status == "労働力率", as.character(years)]
lf_cnt  <- pref_long[pref_long$sex == "総数" & pref_long$status == "労働力人口", as.character(years)]
stopifnot(max(abs(as.matrix(lf_cnt) / p$den * 100 - as.matrix(lfr_pub))) < 1e-4)

nat_rate <- round_half_up(n$emp / n$den * 100, 1)
cat("全国の就業率（同じ定義）:", paste0(years, "年 ", nat_rate, "%", collapse = "、"), "\n")
cat("労働力状態「不詳」の割合（全国）:",
    paste0(years, "年 ", round_half_up(n$unknown / n$total * 100, 1), "%", collapse = "、"), "\n")

write.csv(pref_labor_wide, "public/data/pref_labor_wide.csv", row.names = FALSE, fileEncoding = "UTF-8")
cat("public/data/pref_labor_wide.csv を書き出しました（", nrow(pref_labor_wide), "行）\n")
