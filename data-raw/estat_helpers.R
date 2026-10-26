# e-Stat API（政府統計の総合窓口）を呼ぶための共通関数。fetch_*.R から source() する。
#
# 事前準備
#   1. e-Stat（https://www.e-stat.go.jp/api/）で利用者登録し、アプリケーションIDを取得する
#   2. アプリケーションIDを環境変数 ESTAT_APP_ID に設定する（~/.Renviron に
#      ESTAT_APP_ID=xxxxxxxx と書く。リポジトリには絶対に入れない）
#   3. 各 fetch_*.R の statsDataId（統計表ID）を特定して書き込む（docs/design.md 未確認事項）
#
# 使うパッケージ: jsonlite（JSONの読込）。通信は base R の url() で行う

estat_base_url <- "https://api.e-stat.go.jp/rest/3.0/app"

# アプリケーションIDを環境変数から読む。無ければ止める
estat_app_id <- function() {
  id <- Sys.getenv("ESTAT_APP_ID")
  if (!nzchar(id)) {
    stop("環境変数 ESTAT_APP_ID が設定されていません。e-Statで取得したアプリケーションIDを ",
         "~/.Renviron に ESTAT_APP_ID=... と書いてから R を再起動してください。", call. = FALSE)
  }
  id
}

# アプリケーションIDと statsDataId がそろっているか確かめ、無ければ止める
estat_require_id <- function(stats_data_id, name) {
  estat_app_id()
  if (length(stats_data_id) != 1 || is.na(stats_data_id) || !nzchar(stats_data_id)) {
    stop(name, " の統計表ID（statsDataId）がまだ特定されていません。",
         "スクリプト内の「TODO: statsDataId を特定する」を埋めてください。", call. = FALSE)
  }
  invisible(stats_data_id)
}

# クエリ文字列を作る
estat_query <- function(params) {
  params <- params[!vapply(params, is.null, logical(1))]
  paste(names(params), vapply(params, function(v) utils::URLencode(as.character(v), reserved = TRUE), ""),
        sep = "=", collapse = "&")
}

# 応答の本文を文字列で受け取る
estat_fetch_text <- function(endpoint, params) {
  full <- paste0(estat_base_url, "/", endpoint, "?", estat_query(c(list(appId = estat_app_id()), params)))
  con <- url(full, encoding = "UTF-8")
  on.exit(close(con))
  paste(readLines(con, warn = FALSE), collapse = "\n")
}

# getStatsData（JSON）を呼び、応答をそのまま文字列で返す（estat_sample.json の保存用）
estat_get_stats_data_raw <- function(stats_data_id, ...) {
  estat_fetch_text("json/getStatsData", list(statsDataId = stats_data_id, ...))
}

# getStatsData（JSON）を呼び、値の表（data.frame）を返す。
# 列: 表章事項・分類（@tab, @cat01 ...）、地域（@area）、時間（@time）、単位（@unit）、値（$）
estat_get_stats_data <- function(stats_data_id, ...) {
  txt <- estat_get_stats_data_raw(stats_data_id, ...)
  res <- jsonlite::fromJSON(txt, simplifyVector = TRUE)
  st <- res$GET_STATS_DATA$RESULT
  if (!identical(as.character(st$STATUS), "0")) {
    stop("e-Stat API がエラーを返しました（STATUS ", st$STATUS, "）: ", st$ERROR_MSG, call. = FALSE)
  }
  values <- res$GET_STATS_DATA$STATISTICAL_DATA$DATA_INF$VALUE
  # TODO: 10万件を超える表は NEXT_KEY を使って続きを取る（startPosition）
  values
}

# getSimpleStatsData（CSV）を呼び、本文を文字列で返す（e-StatのCSVの形のまま）
estat_get_simple_csv <- function(stats_data_id, ...) {
  estat_fetch_text("getSimpleStatsData", list(statsDataId = stats_data_id, ...))
}

# 書き出し先（プロジェクトのルートで実行する前提）
estat_out <- function(file) file.path("public", "data", file)
