# lfs_monthly.csv を作る（全国・月次、2000年1月〜保存済みの元データの最新月）。
#   出力: public/data/lfs_monthly.csv（列: date, unemp_rate_sa, unemp_rate_nsa, employed_10k）
#   実行: Rscript data-raw/fetch_lfs_monthly.R   （プロジェクトのルートで。通信はしない）
#   元データ: data-raw/raw/lfs_monthly/（data-raw/download_lfs_monthly.R で e-Stat から取得。詳細は SOURCES.md）
#     主資料  lt01-a10_1-a-1.xlsx  総務省統計局「労働力調査 基本集計」長期時系列データ 表1-a-1
#             主要項目（季節調整値及び原数値）。3列ともここから読む
#     照合用  estat_0003005865_unemp_rate_nsa.json（完全失業率 原数値）
#             estat_0003005798_employed_nsa.json（就業者数 原数値）  … e-Stat API getStatsData の応答
#   加工: 「季節調整値」シートの完全失業率（男女計）、「原数値」シートの完全失業率・就業者（男女計）を取り出し、
#         年月を月初の日付にする。率は小数1桁、就業者は万人の整数。値の手入力・補完はしない。
#   2011年3〜8月は東日本大震災の影響で全国の調査結果が無く、元資料（長期時系列）は補完推計値を載せている
#   （e-Stat のデータベースでは「…」）。本データは長期時系列の補完推計値をそのまま使う。
suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
})

raw_dir <- "data-raw/raw/lfs_monthly"
xlsx    <- file.path(raw_dir, "lt01-a10_1-a-1.xlsx")
if (!file.exists(xlsx)) stop("元データがありません。先に data-raw/download_lfs_monthly.R を実行: ", xlsx, call. = FALSE)

# シートを読み、年月と指定列の値を返す
read_sheet <- function(sheet, cols, expect_head) {
  x <- read_excel(xlsx, sheet = sheet, col_names = FALSE, col_types = "text", .name_repair = "minimal")
  # 見出しの確認（列の位置が変わっていないこと）
  hdr <- vapply(seq_len(ncol(x)), function(j) paste(na.omit(unlist(x[5:9, j])), collapse = "/"), "")
  for (nm in names(expect_head)) {
    j <- cols[[nm]]
    # 結合セルのため、項目名は男女計の列（同じ列）に入っている
    if (!all(vapply(expect_head[[nm]], grepl, logical(1), x = hdr[j], fixed = TRUE)))
      stop(sheet, " シートの ", j, " 列目の見出しが想定と違います: ", hdr[j], call. = FALSE)
  }
  mon <- suppressWarnings(as.integer(sub("^[[:space:]]*([0-9]+)月$", "\\1", x[[2]])))
  rows <- which(!is.na(mon))
  # 年は各年の2行目（2月の行）の1列目に西暦で入っている
  yr <- rep(NA_integer_, nrow(x))
  for (i in rows[mon[rows] == 1]) {
    y <- suppressWarnings(as.integer(x[[1]][i + 1]))
    if (is.na(y)) stop(sheet, " シート ", i + 1, " 行目に西暦がありません", call. = FALSE)
    yr[i:(i + 11)] <- y
  }
  out <- data.frame(date = as.Date(sprintf("%04d-%02d-01", yr[rows], mon[rows])))
  for (nm in names(cols)) {
    v <- x[[cols[[nm]]]][rows]
    v <- gsub("[<>（）()[:space:]]", "", v)  # 補完推計値の < > などの記号を除く
    out[[nm]] <- suppressWarnings(as.numeric(v))
  }
  out
}

sa  <- read_sheet("季節調整値", list(unemp_rate_sa = 20L),
                  list(unemp_rate_sa = c("完全失業率", "男女計")))
nsa <- read_sheet("原数値", list(unemp_rate_nsa = 20L, employed_10k = 8L),
                  list(unemp_rate_nsa = c("完全失業率", "男女計"), employed_10k = c("就業者", "男女計")))

lfs_monthly <- sa |>
  inner_join(nsa, by = "date") |>
  filter(date >= as.Date("2000-01-01"), !is.na(unemp_rate_sa) | !is.na(unemp_rate_nsa) | !is.na(employed_10k)) |>
  arrange(date) |>
  mutate(unemp_rate_sa  = round(unemp_rate_sa, 1),
         unemp_rate_nsa = round(unemp_rate_nsa, 1),
         employed_10k   = as.integer(round(employed_10k)))

# ---- 検算 ----
stopifnot(!anyNA(lfs_monthly))
mseq <- seq(as.Date("2000-01-01"), max(lfs_monthly$date), by = "month")
if (!identical(lfs_monthly$date, mseq)) stop("欠けている月があります", call. = FALSE)
stopifnot(all(lfs_monthly$unemp_rate_sa > 1 & lfs_monthly$unemp_rate_sa < 7),
          all(lfs_monthly$employed_10k > 6000 & lfs_monthly$employed_10k < 7000))

# e-Stat データベース（API の応答）と照合する
read_estat_json <- function(file) {
  v <- jsonlite::fromJSON(file.path(raw_dir, file))$GET_STATS_DATA$STATISTICAL_DATA$DATA_INF$VALUE
  tm <- v$`@time`
  data.frame(date = as.Date(sprintf("%s-%s-01", substr(tm, 1, 4), substr(tm, 9, 10))),
             value = suppressWarnings(as.numeric(v$`$`)))
}
db_rate <- read_estat_json("estat_0003005865_unemp_rate_nsa.json")
db_emp  <- read_estat_json("estat_0003005798_employed_nsa.json")
quake <- seq(as.Date("2011-03-01"), as.Date("2011-08-01"), by = "month")
# DB の最新月と長期時系列の最新月が同じ（同じ公表回の資料である）
if (!identical(max(db_rate$date), max(lfs_monthly$date))) stop("DB と長期時系列の最新月が違います", call. = FALSE)
chk <- lfs_monthly |> left_join(db_rate, by = "date")
stopifnot(all(is.na(chk$value) == (chk$date %in% quake)))           # DB は震災の6か月だけ欠ける
stopifnot(all(chk$unemp_rate_nsa == chk$value, na.rm = TRUE))       # 率は全月一致（比率は遡及改定しない）
# 就業者は、長期時系列では 2005年10月〜2021年12月 がベンチマーク人口の切替えに合わせた時系列接続用数値に
# 置き換わっているため DB と違う月がある。それ以外の期間は一致する
chk <- lfs_monthly |> left_join(db_emp, by = "date")
same_period <- chk$date < as.Date("2005-10-01") | chk$date >= as.Date("2022-01-01")
stopifnot(all(chk$employed_10k[same_period] == chk$value[same_period]))

readr::write_csv(lfs_monthly, file.path("public", "data", "lfs_monthly.csv"))
message("lfs_monthly.csv: ", nrow(lfs_monthly), " 行（", min(lfs_monthly$date), "〜", max(lfs_monthly$date), "）")
