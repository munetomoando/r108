# cpi_monthly の元データを e-Stat API から取得して data-raw/raw/cpi_monthly/ に保存する（通信する）。
#   実行: Rscript data-raw/download_cpi_monthly.R   （プロジェクトのルートで。ESTAT_APP_ID が必要）
#   保存したファイルから CSV を作るのは data-raw/fetch_cpi_monthly.R（こちらは通信しない）。
#   取得するもの（詳細は data-raw/raw/cpi_monthly/SOURCES.md）
#     1. getStatsData（JSON） 0004052037 「消費者物価指数（2025年基準）」 全国、指数、総合(0001)・生鮮食品を除く総合(0161)
#     2. 照合用: 同じ条件で 0003427113 「消費者物価指数（2020年基準）」
# アプリケーションID は画面に出さず、保存前に "YOUR_APP_ID" に置き換えて、残っていないことを確かめる。
source("data-raw/estat_helpers.R")

raw_dir <- "data-raw/raw/cpi_monthly"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

save_masked <- function(txt, file) {
  id <- estat_app_id()
  txt <- gsub(id, "YOUR_APP_ID", txt, fixed = TRUE)
  if (grepl(id, txt, fixed = TRUE)) stop("アプリケーションIDが残っています", call. = FALSE)
  writeLines(txt, file.path(raw_dir, file), useBytes = TRUE)
  message("保存: ", file.path(raw_dir, file))
}

get_cpi <- function(stats_data_id, file) {
  txt <- estat_get_stats_data_raw(stats_data_id, cdTab = "1", cdArea = "00000", cdCat01 = "0001,0161")
  st <- jsonlite::fromJSON(txt)$GET_STATS_DATA$RESULT
  if (!identical(as.character(st$STATUS), "0")) stop("e-Stat API エラー: ", st$ERROR_MSG, call. = FALSE)
  save_masked(txt, file)
}

get_cpi("0004052037", "estat_0004052037_cpi2025_all_core.json")  # 主資料（2025年基準）
get_cpi("0003427113", "estat_0003427113_cpi2020_all_core.json")  # 照合用（2020年基準）
