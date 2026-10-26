# gdp_quarterly.csv を作る（1994年1–3月期〜2026年4–6月期、実質・季節調整系列）。
#   出力: public/data/gdp_quarterly.csv（列: quarter（四半期の初日）, real_gdp（兆円）, growth_qoq（%））
#   実行: Rscript data-raw/fetch_gdp_quarterly.R   （プロジェクトのルートで。通信はしない）
#   出所: 内閣府経済社会総合研究所「国民経済計算（GDP統計）」四半期別GDP速報
#         2026年4-6月期・2次速報（2026年9月8日公表）、2020暦年連鎖価格
#         実質季節調整系列     gaku-jk2622.csv
#         実質季節調整系列(前期比) ritu-jk2622.csv
#         （2026-10-23 取得。詳細は data-raw/raw/gdp_quarterly/SOURCES.md）
#   加工: どちらも Shift-JIS（CP932）で、上に7行の見出し、下に注記がある。
#         1列目の期の表示（「1994/ 1- 3.」「4- 6.」…。年は年が変わる行にだけ付く）を
#         四半期の初日の日付に直し、2列目「国内総生産(支出側)」だけを取り出す。
#         real_gdp = 実額（10億円）÷ 1000（兆円）。元の小数1桁（1億円単位）をそのまま残す
#         書き出しは real_gdp を小数4桁、growth_qoq を小数1桁の文字列にする（浮動小数点の誤差で
#         582.16010000000006 のように書き出されるのを防ぐため。値は元資料の桁のまま）。
#         growth_qoq は内閣府が公表した前期比（%、小数1桁）をそのまま使う。最初の期は NA。
#   値は元資料から機械的に読むだけで、手入力・補完はしない。
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
})

raw_dir   <- "data-raw/raw/gdp_quarterly"
gaku_csv  <- file.path(raw_dir, "gaku-jk2622.csv")  # 実額（10億円、年率表示）
ritu_csv  <- file.path(raw_dir, "ritu-jk2622.csv")  # 前期比（%）
first_q   <- as.Date("1994-01-01")
last_q    <- as.Date("2026-04-01")                  # 2026年4-6月期（2次速報）

# 内閣府の表を読み、期（Date）と国内総生産(支出側) の列（文字列）を返す
read_qe <- function(path) {
  if (!file.exists(path)) stop("元資料がありません: ", path, call. = FALSE)
  x <- read_csv(path, col_names = FALSE, col_types = cols(.default = col_character()),
                locale = locale(encoding = "CP932"), na = character(), trim_ws = TRUE,
                progress = FALSE)
  stopifnot(identical(x[[2]][3], "国内総生産(支出側)"))  # 3行目の見出しで列を確認
  lab <- x[[1]]
  is_q <- grepl("^([0-9]{4}/ *)?[0-9]+- *[0-9]+\\.$", lab)
  # 期の行は連続していること（見出しと注記の間）
  rng <- range(which(is_q))
  stopifnot(all(is_q[rng[1]:rng[2]]))
  lab <- lab[rng[1]:rng[2]]
  val <- x[[2]][rng[1]:rng[2]]
  yr  <- suppressWarnings(as.integer(sub("^([0-9]{4})/.*$", "\\1", lab)))
  yr[!grepl("/", lab)] <- NA
  stopifnot(!is.na(yr[1]))
  for (i in seq_along(yr)) if (is.na(yr[i])) yr[i] <- yr[i - 1]
  start_month <- as.integer(sub("^([0-9]{4}/ *)?([0-9]+)-.*$", "\\2", lab))
  stopifnot(all(start_month %in% c(1L, 4L, 7L, 10L)))
  tibble(quarter = as.Date(sprintf("%d-%02d-01", yr, start_month)), value = val)
}

to_num <- function(s) {
  s <- gsub(",", "", s)
  out <- ifelse(s == "", NA_real_, suppressWarnings(as.numeric(s)))
  bad <- s != "" & is.na(out)
  if (any(bad)) stop("数値として読めないセルがあります: ", paste(s[bad], collapse = ", "), call. = FALSE)
  out
}

gaku <- read_qe(gaku_csv) |> mutate(real_gdp = to_num(value) / 1000) |> select(-value)
ritu <- read_qe(ritu_csv) |> mutate(growth_qoq = to_num(value)) |> select(-value)

stopifnot(identical(gaku$quarter, ritu$quarter))
gdp_quarterly <- left_join(gaku, ritu, by = "quarter")

# ---- 検算 ----
expected_q <- seq(first_q, last_q, by = "quarter")
stopifnot(identical(gdp_quarterly$quarter, expected_q))           # 欠けた期・重複が無い
stopifnot(!anyNA(gdp_quarterly$real_gdp))
stopifnot(is.na(gdp_quarterly$growth_qoq[1]), !anyNA(gdp_quarterly$growth_qoq[-1]))
# 公表の前期比と、実額から計算した前期比が丸めの範囲で一致する
calc <- 100 * (gdp_quarterly$real_gdp / dplyr::lag(gdp_quarterly$real_gdp) - 1)
stopifnot(max(abs(calc[-1] - gdp_quarterly$growth_qoq[-1])) <= 0.05 + 1e-6)

out <- gdp_quarterly |>
  mutate(real_gdp   = sprintf("%.4f", real_gdp),
         growth_qoq = ifelse(is.na(growth_qoq), NA_character_, sprintf("%.1f", growth_qoq)))
write_csv(out, "public/data/gdp_quarterly.csv", na = "NA")
cat("public/data/gdp_quarterly.csv:", nrow(gdp_quarterly), "行（",
    format(first_q), "〜", format(last_q), "）\n")
