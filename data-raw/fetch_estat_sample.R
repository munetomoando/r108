# estat_sample.json を作る（e-Stat API getStatsData の応答をそのまま保存）。
#   出力: public/data/estat_sample.json
#   実行: Rscript data-raw/fetch_estat_sample.R（ESTAT_APP_ID が必要。通信するので build_all.R には入れない）
#   出所: 総務省統計局「社会・人口統計体系 都道府県データ 基礎データ F 労働」（統計表ID 0000010206）。
#         完全失業率の元の値は国勢調査による
#   第17ステップで jsonlite::fromJSON とコード表の結合を練習する。応答は小さく保つ（432件）
source("data-raw/estat_helpers.R")

stats_data_id <- "0000010206"
estat_require_id(stats_data_id, "estat_sample")

# 完全失業率（総数・男・女）× 2010・2015・2020年度 × 全国と47都道府県
txt <- estat_get_stats_data_raw(
  stats_data_id,
  cdCat01 = "#F01301,#F0130101,#F0130102",
  cdTime = "2010100000,2015100000,2020100000",
  lang = "J"
)
res <- jsonlite::fromJSON(txt)
st <- res$GET_STATS_DATA$RESULT
if (!identical(as.character(st$STATUS), "0")) stop("e-Stat API がエラーを返しました: ", st$ERROR_MSG)
n <- nrow(res$GET_STATS_DATA$STATISTICAL_DATA$DATA_INF$VALUE)
if (n != 432) stop("件数が想定（432件）と違います: ", n)

# アプリケーションIDは応答の PARAMETER 部に含まれるので、保存前に必ず消す
txt <- gsub(estat_app_id(), "YOUR_APP_ID", txt, fixed = TRUE)
stopifnot(!grepl(estat_app_id(), txt, fixed = TRUE))
# 取得日時（DATE）は毎回変わるので、保存した日の値のまま残す（再取得すると checksums が変わる）
out <- estat_out("estat_sample.json")
con <- file(out, open = "w", encoding = "UTF-8")
writeLines(txt, con)
close(con)
cat(out, "を書き出しました（", n, "件）\n")
