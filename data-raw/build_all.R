# public/data のデータをすべて作り直し、チェックサムを書き出す。
#   Rscript data-raw/build_all.R
# どのディレクトリから実行してもよい（プロジェクトのルートに移動してから実行する）。
# 公的統計（fetch_*.R）は data-raw/raw/ に保存した公式ファイルから作る（通信しない）。
# 元ファイルの取得先と取得日は data-raw/raw/<名前>/SOURCES.md にある。
args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
root <- if (length(file_arg)) normalizePath(file.path(dirname(sub("^--file=", "", file_arg)), "..")) else getwd()
setwd(root)

scripts <- c(
  "data-raw/fetch_pref_basic.R",        # pref_basic.csv（国勢調査2020＋国土地理院 面積調）
  "data-raw/make_jp_tile.R",            # jp_tile.csv（タイル地図の位置。pref_basic.csv と照合するので後に置く）
  "data-raw/fetch_pref_labor_wide.R",   # pref_labor_wide.csv（国勢調査 時系列）
  "data-raw/fetch_wage_census_pref.R",  # wage_census_pref.csv（賃金構造基本統計調査 都道府県別）
  "data-raw/fetch_min_wage_pref.R",     # min_wage_pref.csv（厚生労働省 地域別最低賃金改定状況）
  "data-raw/fetch_kakei_raw_sjis.R",    # kakei_raw_sjis.csv（家計調査 2025年 第4-1表）
  "data-raw/fetch_lfs_monthly.R",       # lfs_monthly.csv（労働力調査 長期時系列 表1-a-1）
  "data-raw/fetch_cpi_monthly.R",       # cpi_monthly.csv（消費者物価指数 2025年基準）
  "data-raw/fetch_gdp_quarterly.R",     # gdp_quarterly.csv（内閣府 四半期別GDP速報 2026年4-6月期2次速報）
  "data-raw/fetch_iip_monthly.R",       # iip_monthly.csv（鉱工業指数 2020年基準 生産 鉱工業総合）
  "data-raw/build_pref_panel.R",        # pref_panel.csv（上の3本から。第18ステップの正解と同じ表）
  "data-raw/synth_sora_stores.R",       # 第1部の店舗データ
  "data-raw/synth_messy_survey.R",
  "data-raw/synth_ec.R",                # ec_customers / ec_products(.xlsx) / ec_orders
  "data-raw/synth_churn.R",             # ec_* から作るので synth_ec.R の後
  "data-raw/synth_ab_test.R",           # ab_test / ab_test_srm
  "data-raw/synth_wage_survey.R",
  "data-raw/synth_training.R",          # training_rct / training_obs
  "data-raw/synth_minwage_panel.R",
  "data-raw/synth_scholarship_rdd.R",
  "data-raw/synth_store_sales_daily.R"   # sora_stores.csv の店舗を使うので synth_sora_stores.R の後
)

for (s in scripts) {
  cat("==>", s, "\n")
  # 各スクリプトは独立した Rscript プロセスで実行する（乱数・パッケージの状態を持ち越さない）
  status <- system2(file.path(R.home("bin"), "Rscript"), shQuote(s))
  if (status != 0) stop(s, " が失敗しました（終了コード ", status, "）")
}

files <- sort(list.files("public/data", pattern = "\\.(csv|xlsx|json)$"), method = "radix")
md5 <- tools::md5sum(file.path("public/data", files))
writeLines(paste(unname(md5), files, sep = "  "), "public/data/checksums.txt")
cat("\npublic/data/checksums.txt に", length(files), "ファイルのMD5を書き出しました\n")
