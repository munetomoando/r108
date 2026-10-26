# iip_monthly の照合用データを e-Stat API から取得して data-raw/raw/iip_monthly/ に保存する（通信する）。
#   主資料は経済産業省サイトの Excel（b2020_gsm1j.xlsx・b2020_gom1j.xlsx）で、サイトが自動取得に 403 を返すためブラウザで手で取得する（SOURCES.md）。
#   実行: Rscript data-raw/download_iip_monthly.R   （プロジェクトのルートで。ESTAT_APP_ID が必要）
#   保存したファイルから CSV を作るのは data-raw/fetch_iip_monthly.R（こちらは通信しない）。
#   取得するもの（詳細は data-raw/raw/iip_monthly/SOURCES.md）
#     経済産業省「鉱工業生産・出荷・在庫指数 2020年基準時系列データ（2018年１月～）」の
#     1. 0004052177 業種別季節調整済指数【月次】 付加価値額生産（2020＝100.0）
#     2. 0004052181 業種別原指数【月次】 付加価値額生産（2020＝100.0）
#     どちらも業種 0001000（鉱工業）だけを取る。
# アプリケーションID は画面に出さず、保存前に "YOUR_APP_ID" に置き換えて、残っていないことを確かめる。
source("data-raw/estat_helpers.R")

raw_dir <- "data-raw/raw/iip_monthly"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

save_masked <- function(txt, file) {
  id <- estat_app_id()
  txt <- gsub(id, "YOUR_APP_ID", txt, fixed = TRUE)
  if (grepl(id, txt, fixed = TRUE)) stop("アプリケーションIDが残っています", call. = FALSE)
  writeLines(txt, file.path(raw_dir, file), useBytes = TRUE)
  message("保存: ", file.path(raw_dir, file))
}

get_iip <- function(stats_data_id, file) {
  txt <- estat_get_stats_data_raw(stats_data_id, cdCat01 = "0001000")
  st <- jsonlite::fromJSON(txt)$GET_STATS_DATA$RESULT
  if (!identical(as.character(st$STATUS), "0")) stop("e-Stat API エラー: ", st$ERROR_MSG, call. = FALSE)
  save_masked(txt, file)
}

get_iip("0004052177", "estat_0004052177_iip2020_production_sa.json")   # 季節調整済指数
get_iip("0004052181", "estat_0004052181_iip2020_production_nsa.json")  # 原指数
