# lfs_monthly の元データを e-Stat から取得して data-raw/raw/lfs_monthly/ に保存する（通信する）。
#   実行: Rscript data-raw/download_lfs_monthly.R   （プロジェクトのルートで。ESTAT_APP_ID が必要）
#   保存したファイルから CSV を作るのは data-raw/fetch_lfs_monthly.R（こちらは通信しない）。
#   取得するもの（詳細は data-raw/raw/lfs_monthly/SOURCES.md）
#     1. getStatsData（JSON） 0003005865 「労働力人口比率，就業率及び完全失業率（2000年1月～）」の完全失業率（男女計、原数値）
#     2. getStatsData（JSON） 0003005798 「就業状態別15歳以上人口（2000年1月～）」の就業者数（男女計、原数値）
#     3. 長期時系列データ 表1-a-1「主要項目（季節調整値及び原数値）」の Excel（e-Stat のファイル。
#        データベースには完全失業率の季節調整値の月次表が無いため。getDataCatalog API で最新の版を探して取る）
# アプリケーションID は画面に出さず、保存前に "YOUR_APP_ID" に置き換えて、残っていないことを確かめる。
source("data-raw/estat_helpers.R")

raw_dir <- "data-raw/raw/lfs_monthly"
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

# 応答から ID を消してから保存する
save_masked <- function(txt, file) {
  id <- estat_app_id()
  txt <- gsub(id, "YOUR_APP_ID", txt, fixed = TRUE)
  if (grepl(id, txt, fixed = TRUE)) stop("アプリケーションIDが残っています", call. = FALSE)
  writeLines(txt, file.path(raw_dir, file), useBytes = TRUE)
  message("保存: ", file.path(raw_dir, file))
}

check_status <- function(txt) {
  st <- jsonlite::fromJSON(txt)$GET_STATS_DATA$RESULT
  if (!identical(as.character(st$STATUS), "0")) stop("e-Stat API エラー: ", st$ERROR_MSG, call. = FALSE)
}

# 1. 完全失業率（原数値）: cat02=08 完全失業者（の率）, cat03=0 総数
txt <- estat_get_stats_data_raw("0003005865", cdCat02 = "08", cdCat03 = "0")
check_status(txt)
save_masked(txt, "estat_0003005865_unemp_rate_nsa.json")

# 2. 就業者数（原数値、万人）: cat02=02 就業者, cat03=0 総数
txt <- estat_get_stats_data_raw("0003005798", cdCat02 = "02", cdCat03 = "0")
check_status(txt)
save_masked(txt, "estat_0003005798_employed_nsa.json")

# 3. 長期時系列データ 表1-a-1 の Excel。データカタログ API で最新月の版を探す
cat_txt <- estat_fetch_text("json/getDataCatalog",
                            list(statsCode = "00200531", searchWord = "月別結果 主要項目"))
cat_js <- jsonlite::fromJSON(cat_txt, simplifyVector = FALSE)$GET_DATA_CATALOG$DATA_CATALOG_LIST_INF$DATA_CATALOG_INF
if (!is.null(cat_js$`@id`)) cat_js <- list(cat_js)
cand <- do.call(rbind, lapply(cat_js, function(d) {
  res <- d$RESOURCES$RESOURCE
  if (!is.null(res$`@id`)) res <- list(res)
  do.call(rbind, lapply(res, function(x) data.frame(
    dataset = d$DATASET$TITLE$NAME %||% "", name = x$TITLE$NAME %||% "",
    url = x$URL %||% "", updated = x$LAST_MODIFIED_DATE %||% "", stringsAsFactors = FALSE)))
}))
cand <- cand[grepl("長期時系列データ_基本集計_[0-9]{4}年[0-9]+月$", cand$dataset) &
             grepl("1-a-1_主要項目", cand$name), ]
if (nrow(cand) == 0) stop("表1-a-1 が見つかりません", call. = FALSE)
cand <- cand[order(cand$updated, decreasing = TRUE), ][1, ]
message("表1-a-1: ", cand$dataset, "（更新 ", cand$updated, "）")
xlsx_url <- sub("file-download\\?&", "file-download?", cand$url)
tmp <- tempfile()
utils::download.file(xlsx_url, tmp, mode = "wb", quiet = TRUE)
# 拡張子は中身で決める（xlsx は ZIP = "PK"）
sig <- readBin(tmp, "raw", 2)
ext <- if (identical(sig, charToRaw("PK"))) "xlsx" else "xls"
file.copy(tmp, file.path(raw_dir, paste0("lt01-a10_1-a-1.", ext)), overwrite = TRUE)
writeLines(c(paste0("dataset: ", cand$dataset), paste0("resource: ", cand$name),
             paste0("url: ", xlsx_url), paste0("last_modified: ", cand$updated),
             paste0("downloaded: ", format(Sys.Date()))),
           file.path(raw_dir, "lt01-a10_1-a-1.meta.txt"))
message("保存: ", file.path(raw_dir, paste0("lt01-a10_1-a-1.", ext)))
