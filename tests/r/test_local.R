# ローカル実行ステップの確認スクリプト（public/local/check_0XX.R）のテスト
#   Rscript tests/r/test_local.R          # 全部
#   Rscript tests/r/test_local.R 051      # ステップ51だけ
#   R108_TEST_VERBOSE=1 Rscript tests/r/test_local.R 104   # 合格した見本の出力も表示する
#
# tests/local/<ステップ>/<見本>/ を自動で探し、見本ごとに一時フォルダへコピーして、
# そこを作業フォルダにして別の R で source("check_0XX.R") を実行する。
#   pass      … 修了コードが表示され、その SHA-256 が step.yaml の code_sha256 と一致すること
#   fail-*    … 修了コードが表示されないこと。_expect_fail.txt があれば、その各行を含む ✗ の行が出ること
# 見本フォルダの特別なファイル（コピーしない）:
#   _data.txt         … public/data/ からコピーするファイル名（1行1つ）。作業フォルダの data/ に置く
#   _expect_fail.txt  … 落ちるべき確認項目の文字列（1行1つ）
#   _setup.R          … コピーのあと、一時フォルダを作業フォルダにして別の R で実行する（Git のリポジトリを
#                       作るなど）。_setup.R がある見本では、この PC の git の設定（~/.gitconfig など）を
#                       読まないように、GIT_CONFIG_GLOBAL を空のファイル、GIT_CONFIG_NOSYSTEM=1 にして
#                       _setup.R と確認スクリプトを実行する
# quarto は環境変数 QUARTO_PATH → PATH → RStudio・Positron 同梱の順に探す（確認スクリプトと同じ）。
# 見つからないときは、r108_render() を使うステップの見本をスキップする。

args <- commandArgs(trailingOnly = TRUE)
root <- normalizePath(".")
if (!dir.exists(file.path(root, "tests", "local"))) stop("プロジェクトのルート（r108/）で実行してください。")

# 確認スクリプトを作り直す（node がなければ、いまある public/local/ を使う）
st <- tryCatch(system2("node", file.path(root, "scripts", "build-r.mjs"), stdout = TRUE, stderr = TRUE),
               error = function(e) structure("node が見つかりません", status = 1L))
if (!is.null(attr(st, "status"))) cat("（注意）scripts/build-r.mjs を実行できませんでした。public/local/ をそのまま使います。\n")

common <- new.env()
sys.source(file.path(root, "local-src", "_common.R"), envir = common, keep.source = FALSE)
quarto <- common$r108_find_quarto()
cat("quarto: ", if (is.null(quarto)) "見つかりません（レンダリングするステップはスキップ）" else quarto, "\n\n", sep = "")

rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
cases <- list.dirs(file.path(root, "tests", "local"), recursive = TRUE)
cases <- cases[grepl("/[0-9]{3}/(pass|fail-[^/]+)$", cases)]
if (length(args)) cases <- cases[basename(dirname(cases)) %in% sprintf("%03d", as.integer(args))]

sha256 <- function(s) {
  if (requireNamespace("openssl", quietly = TRUE)) return(as.character(openssl::sha256(s)))
  digest::digest(s, algo = "sha256", serialize = FALSE)
}
expected_hash <- function(step) {
  f <- file.path(root, "content", "steps", step, "step.yaml")
  if (!file.exists(f)) return(NA_character_)
  y <- yaml::read_yaml(f)
  if (is.null(y$local$code_sha256)) NA_character_ else y$local$code_sha256
}

n_fail <- 0L
n_run <- 0L
n_skip <- 0L
for (case in cases) {
  step <- basename(dirname(case))
  kind <- basename(case)
  name <- paste0(step, "/", kind)
  script <- file.path(root, "public", "local", paste0("check_", step, ".R"))
  src <- file.path(root, "local-src", paste0("check_", step, ".R"))
  if (!file.exists(script)) { cat("✗ ", name, ": ", script, " がありません\n", sep = ""); n_fail <- n_fail + 1L; next }
  if (is.null(quarto) && any(grepl("r108_render\\(", readLines(src, warn = FALSE)))) {
    cat("- ", name, ": quarto がないのでスキップ\n", sep = ""); n_skip <- n_skip + 1L; next
  }
  tmp <- tempfile(paste0("r108_", step, "_"))
  dir.create(tmp)
  files <- list.files(case, all.files = TRUE, recursive = TRUE, no.. = TRUE)
  files <- files[!files %in% c("_data.txt", "_expect_fail.txt", "_setup.R")]
  for (f in files) {
    dir.create(dirname(file.path(tmp, f)), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(case, f), file.path(tmp, f))
  }
  if (file.exists(file.path(case, "_data.txt"))) {
    dir.create(file.path(tmp, "data"), showWarnings = FALSE)
    for (d in trimws(readLines(file.path(case, "_data.txt"), warn = FALSE))) {
      if (nzchar(d)) file.copy(file.path(root, "public", "data", d), file.path(tmp, "data", d))
    }
  }
  setup <- file.path(case, "_setup.R")
  git_env <- NULL
  if (file.exists(setup)) {
    # この PC の git の設定を読まない（見本ごとに同じ結果になるように）
    empty_cfg <- tempfile("gitconfig_")
    file.create(empty_cfg)
    keys <- c("GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM")
    git_env <- Sys.getenv(keys, unset = NA, names = TRUE)
    Sys.setenv(GIT_CONFIG_GLOBAL = empty_cfg, GIT_CONFIG_NOSYSTEM = "1")
    sexpr <- sprintf('setwd("%s"); source("%s", encoding = "UTF-8")', tmp, normalizePath(setup, winslash = "/"))
    sout <- suppressWarnings(system2(rscript, c("--no-save", "--no-restore", "-e", shQuote(sexpr)), stdout = TRUE, stderr = TRUE))
    if (!is.null(attr(sout, "status"))) {
      cat("✗ ", name, ": _setup.R がエラーで止まった\n", sep = "")
      cat(paste0("    | ", sout), sep = "\n")
      n_fail <- n_fail + 1L
      for (k in keys) if (is.na(git_env[[k]])) Sys.unsetenv(k) else do.call(Sys.setenv, as.list(git_env[k]))
      unlink(c(tmp, empty_cfg), recursive = TRUE)
      next
    }
  }
  file.copy(script, tmp)
  before <- list.files(tmp, recursive = TRUE, all.files = TRUE)
  expr <- sprintf('setwd("%s"); source("%s", encoding = "UTF-8")', tmp, basename(script))
  t0 <- Sys.time()
  out <- suppressWarnings(system2(rscript, c("--no-save", "--no-restore", "-e", shQuote(expr)), stdout = TRUE, stderr = TRUE))
  secs <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
  if (!is.null(git_env)) {
    for (k in names(git_env)) if (is.na(git_env[[k]])) Sys.unsetenv(k) else do.call(Sys.setenv, as.list(git_env[k]))
    unlink(empty_cfg)
  }
  n_run <- n_run + 1L
  codes <- unique(unlist(regmatches(out, gregexpr(paste0("R108-", step, "-[0-9A-F]{4}"), out))))
  problems <- character()
  if (!is.null(attr(out, "status"))) problems <- c(problems, "確認スクリプトがエラーで止まった")
  if (kind == "pass") {
    if (length(codes) != 1) problems <- c(problems, "修了コードが表示されない")
    else {
      h <- expected_hash(step)
      if (!is.na(h) && sha256(codes) != h) problems <- c(problems, "修了コードの SHA-256 が step.yaml と違う")
    }
  } else {
    if (length(codes)) problems <- c(problems, "落ちるべきなのに修了コードが表示された")
    ef <- file.path(case, "_expect_fail.txt")
    if (file.exists(ef)) {
      xlines <- out[grepl("^\\s*\u2717 ", out)]
      for (e in trimws(readLines(ef, encoding = "UTF-8", warn = FALSE))) {
        if (nzchar(e) && !any(grepl(e, xlines, fixed = TRUE))) problems <- c(problems, paste0("✗ にならない項目: ", e))
      }
    }
  }
  # レンダリングの出力（docx・html・pdf・*_files/・.quarto/）以外のファイルが増えていないか
  after <- list.files(tmp, recursive = TRUE, all.files = TRUE)
  extra <- setdiff(after, before)
  extra <- extra[!grepl("\\.(docx|html|pdf)$|_files/|^\\.quarto/", extra)]
  if (length(extra)) cat("    （注意）", name, " で増えたファイル: ", paste(extra, collapse = ", "), "\n", sep = "")
  if (length(problems)) {
    n_fail <- n_fail + 1L
    cat("✗ ", name, " (", secs, "秒): ", paste(problems, collapse = " / "), "\n", sep = "")
    cat(paste0("    | ", out), sep = "\n")
  } else {
    cat("✓ ", name, " (", secs, "秒)\n", sep = "")
    if (nzchar(Sys.getenv("R108_TEST_VERBOSE"))) cat(paste0("    | ", out), sep = "\n")
  }
  unlink(tmp, recursive = TRUE)
}
cat(sprintf("\n%d 件を実行、%d 件スキップ、失敗 %d 件\n", n_run, n_skip, n_fail))
quit(status = if (n_fail > 0) 1L else 0L)
