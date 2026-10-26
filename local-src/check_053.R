# ステップ53「再現可能な分析にする」の確認
# 1. renv.lock がある／スクリプトで使うパッケージが記録されている
# 2. 番号付きのスクリプト（01_〜.R, 02_〜.R …）が2本以上ある
# 3. here() でパスを書き、setwd() や絶対パスを使っていない
# 4. set.seed() で乱数の種を固定している
# 5. プロジェクトを一時フォルダに2回コピーし、それぞれでスクリプトを番号順に実行して、
#    できた結果ファイル（csv など）が一致する。学生のフォルダのファイルは書き換えない。

cat("ステップ53「再現可能な分析にする」の確認\n")
cat("プロジェクトのフォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

# ---- 番号付きスクリプトを探す ----
script_dirs <- c("scripts", "R", "code", ".")
script_pat <- "^[0-9]{2}_.*\\.[Rr]$"
found <- lapply(script_dirs, function(d) {
  if (!dir.exists(d)) return(character())
  f <- sort(list.files(d, pattern = script_pat))
  if (d == ".") f else file.path(d, f)
})
n_found <- lengths(found)
scripts <- if (any(n_found > 0)) found[[which.max(n_found)]] else character()

# ---- スクリプトを構文解析して、呼んでいる関数・パッケージ・文字列を集める ----
base_pkgs <- c("base", "stats", "utils", "graphics", "grDevices", "methods", "datasets",
               "tools", "parallel", "grid", "splines", "stats4", "tcltk", "compiler")
io_funs <- c("read_csv", "read_csv2", "read_tsv", "read_delim", "read_excel", "read.csv",
             "read_rds", "readRDS", "write_csv", "write_tsv", "write.csv", "write_rds",
             "saveRDS", "ggsave", "load", "save", "readLines", "writeLines", "source",
             "read_dta", "read_sav", "fread", "fwrite")

scan_script <- function(path) {
  info <- list(ok = FALSE, calls = character(), pkgs = character(), strings = character(), error = "")
  ex <- tryCatch(parse(path, keep.source = TRUE, encoding = "UTF-8"),
                 error = function(e) e)
  if (inherits(ex, "error")) {
    info$error <- conditionMessage(ex)
    return(info)
  }
  pd <- utils::getParseData(ex)
  if (is.null(pd) || !nrow(pd)) {
    info$ok <- TRUE
    return(info)
  }
  pd <- pd[pd$terminal, ]
  pd <- pd[order(pd$line1, pd$col1), ]
  calls <- pd$text[pd$token == "SYMBOL_FUNCTION_CALL"]
  pkgs <- pd$text[pd$token == "SYMBOL_PACKAGE"]
  # library(x) / require(x) / library("x") の x
  li <- which(pd$token == "SYMBOL_FUNCTION_CALL" & pd$text %in% c("library", "require", "requireNamespace"))
  for (i in li) {
    if (i + 2 <= nrow(pd) && pd$token[i + 2] %in% c("SYMBOL", "STR_CONST")) {
      pkgs <- c(pkgs, gsub("^[\"']|[\"']$", "", pd$text[i + 2]))
    }
  }
  strings <- pd$text[pd$token == "STR_CONST"]
  strings <- vapply(strings, function(s) {
    v <- tryCatch(eval(parse(text = s, keep.source = FALSE)[[1]]), error = function(e) s)
    if (is.character(v) && length(v) == 1) v else s
  }, "", USE.NAMES = FALSE)
  info$ok <- TRUE
  info$calls <- unique(calls)
  info$pkgs <- setdiff(unique(pkgs), base_pkgs)
  info$strings <- unique(strings)
  info
}
scanned <- setNames(lapply(scripts, scan_script), scripts)
parse_ok <- length(scripts) > 0 && all(vapply(scanned, `[[`, TRUE, "ok"))

# ---- 1. renv.lock ----
lock_ok <- file.exists("renv.lock")
lock_pkgs <- character()
if (lock_ok) {
  lock <- enc2utf8(readLines("renv.lock", encoding = "UTF-8", warn = FALSE))
  lock_ok <- any(grepl("\"Packages\"", lock, fixed = TRUE))
  m <- regmatches(lock, regexec("^\\s*\"Package\"\\s*:\\s*\"([^\"]+)\"", lock))
  lock_pkgs <- unique(vapply(m[lengths(m) > 0], `[[`, "", 2))
}
r108_item(lock_ok, "renv.lock がある",
  "プロジェクトを開いた状態で renv::init() を実行し、パッケージを入れたら renv::snapshot() で renv.lock を書き出しましょう。")

# ---- 2. 番号付きスクリプト ----
r108_item(length(scripts) >= 2,
  paste0("番号付きのスクリプトが2本以上ある",
         if (length(scripts)) paste0("（", paste(basename(scripts), collapse = ", "), "）") else ""),
  "scripts フォルダに 01_clean.R、02_analysis.R のように、2桁の番号と _ で始まる名前のスクリプトを置きましょう。")
if (length(scripts) && !parse_ok) {
  bad <- names(scanned)[!vapply(scanned, `[[`, TRUE, "ok")]
  r108_item(FALSE, "スクリプトに文法の誤りがない",
    paste0(bad[1], " を読めません: ", scanned[[bad[1]]]$error))
}

# ---- 3. パッケージが renv.lock に記録されている ----
used_pkgs <- sort(unique(unlist(lapply(scanned, `[[`, "pkgs"))))
missing_pkgs <- setdiff(used_pkgs, lock_pkgs)
r108_item(lock_ok && parse_ok && length(missing_pkgs) == 0,
  "スクリプトで使うパッケージがすべて renv.lock に記録されている",
  if (length(missing_pkgs) && lock_ok)
    paste0("renv.lock に ", paste(missing_pkgs, collapse = ", "),
           " がありません。renv::status() で確かめ、renv::snapshot() をもう一度実行しましょう。")
  else "先に renv.lock とスクリプトを用意しましょう。")

# ---- 4. here() を使い、setwd() や絶対パスを使っていない ----
uses_here <- vapply(scanned, function(s) "here" %in% s$calls, TRUE)
does_io <- vapply(scanned, function(s) any(io_funs %in% s$calls), TRUE)
abs_pat <- "^(/[A-Za-z]|~[/\\\\]|[A-Za-z]:[/\\\\]|\\\\\\\\|\\.\\.[/\\\\])"
bad_paths <- unique(unlist(lapply(scanned, function(s) s$strings[grepl(abs_pat, s$strings)])))
uses_setwd <- names(scanned)[vapply(scanned, function(s) "setwd" %in% s$calls, TRUE)]
no_here <- names(scanned)[does_io & !uses_here]
here_ok <- parse_ok && any(uses_here) && length(no_here) == 0
r108_item(here_ok, "ファイルを読み書きするスクリプトで here() を使っている",
  if (length(no_here)) paste0(paste(basename(no_here), collapse = ", "),
    " でファイルの場所を here(\"data\", \"pref_panel.csv\") のように書きましょう（library(here) が必要です）。")
  else "read_csv() や write_csv() に渡すパスを here() で書きましょう。")
safe_paths <- parse_ok && length(uses_setwd) == 0 && length(bad_paths) == 0
r108_item(safe_paths, "setwd() や、自分の PC でしか通じないパスを使っていない",
  c(if (length(uses_setwd)) paste0(paste(basename(uses_setwd), collapse = ", "),
      " の setwd() を消し、パスは here() で書きましょう。"),
    if (length(bad_paths)) paste0("次のパスはほかの PC では通じません: ",
      paste(utils::head(bad_paths, 3), collapse = ", "), "。here() でプロジェクトからの位置を書きましょう。")))

# ---- 5. set.seed ----
uses_seed <- any(vapply(scanned, function(s) "set.seed" %in% s$calls, TRUE))
r108_item(parse_ok && uses_seed, "set.seed() で乱数の種を固定している",
  "ブートストラップなど乱数を使う直前に set.seed(2026) のように書き、誰が何度実行しても同じ結果になるようにしましょう。")

# ---- 6〜8. 一時フォルダで2回実行して、結果を比べる ----
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
skip_pat <- "^(renv/(library|staging|sandbox|cellar|python|local)|\\.Rproj\\.user|\\.git|\\.quarto|output)(/|$)"
result_ext <- "\\.(csv|tsv|txt|md|json)$"
old_time <- as.POSIXct("2000-01-01 00:00:00", tz = "UTC")

run_in_copy <- function(tag) {
  dest <- tempfile(paste0("r108_053_", tag, "_"))
  dir.create(dest, recursive = TRUE)
  files <- list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE)
  files <- files[!grepl(skip_pat, files)]
  for (d in unique(dirname(files))) dir.create(file.path(dest, d), recursive = TRUE, showWarnings = FALSE)
  file.copy(files, file.path(dest, files), overwrite = TRUE)
  Sys.setFileTime(file.path(dest, files), old_time)
  old_wd <- setwd(dest)
  old_libs <- Sys.getenv("R_LIBS", unset = NA)
  Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  on.exit({
    setwd(old_wd)
    if (is.na(old_libs)) Sys.unsetenv("R_LIBS") else Sys.setenv(R_LIBS = old_libs)
  }, add = TRUE)
  res <- list(dir = dest, ok = TRUE, failed = "", log = "", md5 = character())
  for (s in scripts) {
    out <- suppressWarnings(tryCatch(
      system2(rscript, c("--no-init-file", shQuote(s)), stdout = TRUE, stderr = TRUE, timeout = 600),
      error = function(e) structure(conditionMessage(e), status = 127L)))
    st <- attr(out, "status")
    if (!is.null(st) && st != 0) {
      res$ok <- FALSE
      res$failed <- s
      err <- grep("^(Error|エラー)", out)
      shown <- if (length(err)) out[err[1]:length(out)] else utils::tail(out, 8)
      shown <- utils::head(shown[nzchar(trimws(shown))], 8)
      for (p in unique(c(normalizePath(dest, winslash = "/"), dest))) shown <- gsub(paste0(p, "/"), "", shown, fixed = TRUE)
      res$log <- paste0("        ", shown, collapse = "\n")
      break
    }
  }
  made <- list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE)
  made <- made[!grepl("^renv/", made)]
  made <- made[file.mtime(made) > old_time + 86400 * 365]
  made <- sort(made[grepl(result_ext, made, ignore.case = TRUE)])
  res$md5 <- tools::md5sum(made)
  names(res$md5) <- made
  res
}

can_run <- length(scripts) >= 2 && parse_ok && safe_paths
if (can_run) {
  cat("\n一時フォルダにプロジェクトをコピーし、スクリプトを番号順に2回実行しています（少し時間がかかります）…\n")
  run1 <- run_in_copy("a")
  run2 <- if (run1$ok) run_in_copy("b") else NULL
  unlink(c(run1$dir, run2$dir), recursive = TRUE)
  r108_item(run1$ok && run2$ok,
    "まっさらなコピーで、スクリプトを番号順に実行するとエラーなく最後まで動く",
    if (!run1$ok) paste0(run1$failed, " でエラーになりました（output フォルダがない状態から番号順に実行しています）。\n",
                         "      エラーの内容:\n", run1$log)
    else if (!is.null(run2) && !run2$ok) paste0("2回目の実行で ", run2$failed, " がエラーになりました。\n",
                                                "      エラーの内容:\n", run2$log))
  if (run1$ok) {
    cat("  （作られた結果ファイル: ",
        if (length(run1$md5)) paste(names(run1$md5), collapse = ", ") else "なし", "）\n", sep = "")
  }
  r108_item(run1$ok && length(run1$md5) >= 1,
    "結果をファイル（csv など）に書き出している",
    if (run1$ok) "推定結果を write_csv(結果, here(\"output\", \"result.csv\")) のようにファイルに保存しましょう。"
    else "先に上の項目（エラーなく最後まで動く）を直しましょう。")
  same <- run1$ok && !is.null(run2) && run2$ok && length(run1$md5) >= 1 &&
    identical(names(run1$md5), names(run2$md5)) && identical(unname(run1$md5), unname(run2$md5))
  diff_files <- if (run1$ok && !is.null(run2) && run2$ok) {
    union(setdiff(names(run1$md5), names(run2$md5)),
          names(run1$md5)[names(run1$md5) %in% names(run2$md5) &
                            run1$md5 != run2$md5[names(run1$md5)]])
  } else character()
  r108_item(same, "2回実行した結果ファイルが一致する（再現できる）",
    if (length(diff_files)) paste0(paste(diff_files, collapse = ", "),
      " の中身が1回目と2回目で違いました。乱数を使う前に set.seed() を置いているか確かめましょう。")
    else "先に上の項目を直しましょう。")
} else {
  msg <- "上の項目（番号付きスクリプト・here()・setwd()）を直すと、実際に実行して確かめます。"
  r108_item(FALSE, "まっさらなコピーで、スクリプトを番号順に実行するとエラーなく最後まで動く", msg)
  r108_item(FALSE, "結果をファイル（csv など）に書き出している", msg)
  r108_item(FALSE, "2回実行した結果ファイルが一致する（再現できる）", msg)
}

r108_finish(53, c(120L, 27L, 26L, 18L, 7L, 26L, 31L, 25L, 7L, 111L, 28L, 27L, 104L))
