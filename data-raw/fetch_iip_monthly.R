# iip_monthly.csv を作る（鉱工業生産指数・鉱工業総合、月次、2020年基準、2018年1月〜保存済みの元データの最新月）。
#   出力: public/data/iip_monthly.csv（列: date, iip_sa（季節調整済指数）, iip_nsa（原指数））
#   実行: Rscript data-raw/fetch_iip_monthly.R   （プロジェクトのルートで。通信はしない）
#   元データ: data-raw/raw/iip_monthly/（詳細は SOURCES.md）
#     主資料  b2020_gsm1j.xlsx  経済産業省「鉱工業指数」2020年基準 季節調整済指数【月次】付加価値額生産（ブラウザで手で取得）
#             b2020_gom1j.xlsx  同 原指数【月次】付加価値額生産
#     照合用  estat_0004052177_iip2020_production_sa.json・estat_0004052181_iip2020_production_nsa.json
#             （data-raw/download_iip_monthly.R で e-Stat API から取得。2026年3月まで）
#   加工: シート「生産」の品目番号 1000000000（鉱工業）の行から月次の値を取り出し、月初の日付を作って横に並べる。
#         値の手入力・補完、旧基準（2015年基準）との接続はしない。e-Stat と重なる月は値が同じことを確かめる。
#   2020年基準の系列は2018年1月から始まるため、2013〜2017年は含まない（理由は SOURCES.md）。
suppressPackageStartupMessages({
  library(dplyr)
  library(readxl)
})

raw_dir <- "data-raw/raw/iip_monthly"
read_meti <- function(file, name) {
  path <- file.path(raw_dir, file)
  if (!file.exists(path)) stop("元データがありません（経済産業省のサイトから手で取得。SOURCES.md を参照）: ", path, call. = FALSE)
  x <- read_excel(path, sheet = "生産", col_names = FALSE, col_types = "text", .name_repair = "minimal")
  stopifnot(x[[1]][3] == "品目番号")
  ym <- sub("^P", "", unlist(x[3, -(1:3)], use.names = FALSE))   # 年月の行（速報値は先頭に P）
  row <- which(x[[1]] == "1000000000")
  stopifnot(length(row) == 1, x[[2]][row] == "鉱工業")
  v <- unlist(x[row, -(1:3)], use.names = FALSE)
  keep <- grepl("^[0-9]{6}$", ym)                                   # 月次の列だけ
  out <- tibble(date = as.Date(paste0(substr(ym[keep], 1, 4), "-", substr(ym[keep], 5, 6), "-01")),
                value = as.numeric(v[keep]))
  names(out)[2] <- name
  out
}

read_estat <- function(file, name) {
  sd <- jsonlite::fromJSON(file.path(raw_dir, file))$GET_STATS_DATA$STATISTICAL_DATA
  co <- sd$CLASS_INF$CLASS_OBJ
  tm <- co$CLASS[[which(co$`@id` == "time")]]               # 時間コード → 名前（"201801" など）
  v <- sd$DATA_INF$VALUE
  stopifnot(all(v$`@cat01` == "0001000"))                    # 鉱工業だけ
  ym <- tm$`@name`[match(v$`@time`, tm$`@code`)]
  out <- tibble(ym = ym, value = suppressWarnings(as.numeric(v$`$`))) |>
    filter(grepl("^[0-9]{6}$", ym)) |>                       # 月次だけ（ウエイトの行を除く）
    mutate(date = as.Date(paste0(substr(ym, 1, 4), "-", substr(ym, 5, 6), "-01"))) |>
    select(date, value)
  names(out)[2] <- name
  out
}

sa  <- read_meti("b2020_gsm1j.xlsx", "iip_sa")
nsa <- read_meti("b2020_gom1j.xlsx", "iip_nsa")
iip_monthly <- full_join(sa, nsa, by = "date") |> arrange(date)

# ---- 検算 ----
stopifnot(!anyNA(iip_monthly), nrow(sa) == nrow(nsa))
mseq <- seq(as.Date("2018-01-01"), max(iip_monthly$date), by = "month")
if (!identical(iip_monthly$date, mseq)) stop("欠けている月があります", call. = FALSE)
# 原指数の2020年平均がほぼ100（2020年基準であること。月次の値は小数1桁に丸めてあるので ±0.1）
a20 <- mean(iip_monthly$iip_nsa[format(iip_monthly$date, "%Y") == "2020"])
stopifnot(abs(a20 - 100) <= 0.1)
# 季節調整済指数と原指数の年平均はほぼ同じ（季節調整は年間の水準を変えない。差 1 以内）
yr <- iip_monthly |> mutate(y = format(date, "%Y")) |> group_by(y) |> filter(n() == 12) |>
  summarise(d = mean(iip_sa) - mean(iip_nsa))
stopifnot(all(abs(yr$d) <= 1))
# e-Stat の表と重なる月は値が一致する
es <- full_join(read_estat("estat_0004052177_iip2020_production_sa.json",  "iip_sa"),
                read_estat("estat_0004052181_iip2020_production_nsa.json", "iip_nsa"), by = "date")
chk <- inner_join(iip_monthly, es, by = "date", suffix = c("", "_estat"))
stopifnot(nrow(chk) == nrow(es), all(chk$iip_sa == chk$iip_sa_estat), all(chk$iip_nsa == chk$iip_nsa_estat))

readr::write_csv(iip_monthly, file.path("public", "data", "iip_monthly.csv"))
message("iip_monthly.csv: ", nrow(iip_monthly), " 行（", min(iip_monthly$date), "〜", max(iip_monthly$date),
        "。e-Stat と ", nrow(chk), " か月一致）")
