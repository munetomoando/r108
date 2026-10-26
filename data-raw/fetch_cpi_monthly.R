# cpi_monthly.csv を作る（全国・月次、2000年1月〜保存済みの元データの最新月、2025年基準）。
#   出力: public/data/cpi_monthly.csv（列: date, cpi_all（総合）, cpi_core（生鮮食品を除く総合））
#   実行: Rscript data-raw/fetch_cpi_monthly.R   （プロジェクトのルートで。通信はしない）
#   元データ: data-raw/raw/cpi_monthly/（data-raw/download_cpi_monthly.R で e-Stat API から取得。詳細は SOURCES.md）
#     主資料  estat_0004052037_cpi2025_all_core.json  総務省統計局「消費者物価指数（2025年基準）」0004052037
#     照合用  estat_0003427113_cpi2020_all_core.json  同（2020年基準）0003427113
#   加工: 全国・指数・品目 0001（総合）と 0161（生鮮食品を除く総合）の月次（時間コードの末尾が月）を取り出し、
#         月初の日付にして横に並べる。年平均・年度平均の行は除く。値の手入力・補完はしない。
suppressPackageStartupMessages(library(dplyr))

raw_dir <- "data-raw/raw/cpi_monthly"
read_cpi <- function(file) {
  path <- file.path(raw_dir, file)
  if (!file.exists(path)) stop("元データがありません。先に data-raw/download_cpi_monthly.R を実行: ", path, call. = FALSE)
  v <- jsonlite::fromJSON(path)$GET_STATS_DATA$STATISTICAL_DATA$DATA_INF$VALUE
  stopifnot(all(v$`@tab` == "1"), all(v$`@area` == "00000"))
  tm <- v$`@time`
  v |>
    mutate(time = tm, value = suppressWarnings(as.numeric(`$`))) |>
    select(cat = `@cat01`, time, value)
}
to_monthly <- function(d) {
  d |>
    filter(substr(time, 5, 6) == "00", substr(time, 7, 8) != "00") |>   # 月次だけ（年・年度を除く）
    mutate(date = as.Date(sprintf("%s-%s-01", substr(time, 1, 4), substr(time, 9, 10)))) |>
    filter(date >= as.Date("2000-01-01")) |>
    select(date, cat, value) |>
    tidyr::pivot_wider(names_from = cat, values_from = value) |>
    transmute(date, cpi_all = `0001`, cpi_core = `0161`) |>
    arrange(date)
}

raw25 <- read_cpi("estat_0004052037_cpi2025_all_core.json")
raw20 <- read_cpi("estat_0003427113_cpi2020_all_core.json")
cpi_monthly <- to_monthly(raw25)

# ---- 検算 ----
stopifnot(!anyNA(cpi_monthly))
mseq <- seq(as.Date("2000-01-01"), max(cpi_monthly$date), by = "month")
if (!identical(cpi_monthly$date, mseq)) stop("欠けている月があります", call. = FALSE)
# 2025年の年平均が 100（2025年基準であること）
avg25 <- raw25 |> filter(time == "2025000000")
stopifnot(nrow(avg25) == 2, all(avg25$value == 100))
# 2020年基準の系列と照合: 2025年基準の指数 ≒ 2020年基準の指数 ÷ 2020年基準の2025年平均 × 100（差 0.2 以内。
# 2025年基準の過去の値は旧基準の丸める前の指数をつないで作られ、2025年中はウエイトも新しいため、丸めた旧基準からの換算とは最大 0.16 ずれる）
m20 <- to_monthly(raw20)
a20 <- raw20 |> filter(time == "2025000000")
k_all  <- a20$value[a20$cat == "0001"]; k_core <- a20$value[a20$cat == "0161"]
cmp <- inner_join(cpi_monthly, m20, by = "date", suffix = c("", "_20"))
stopifnot(nrow(cmp) == nrow(cpi_monthly),
          max(abs(cmp$cpi_all  - cmp$cpi_all_20  / k_all  * 100)) <= 0.2,
          max(abs(cmp$cpi_core - cmp$cpi_core_20 / k_core * 100)) <= 0.2)

readr::write_csv(cpi_monthly, file.path("public", "data", "cpi_monthly.csv"))
message("cpi_monthly.csv: ", nrow(cpi_monthly), " 行（", min(cpi_monthly$date), "〜", max(cpi_monthly$date), "）")
