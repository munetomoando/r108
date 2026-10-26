# writexl が書く .xlsx には作成日時が入るため、毎回チェックサムが変わる。
# 作成日時を固定値に置き換え、ZIPの中身の順序と時刻をそろえて書き直す。
# zip コマンドが無い環境では何もしない（警告のみ）。
normalize_xlsx <- function(path, stamp = "2025-01-01T00:00:00Z") {
  if (!nzchar(Sys.which("zip"))) {
    warning("zip コマンドが見つからないため ", path, " の作成日時を固定できませんでした")
    return(invisible(FALSE))
  }
  path <- normalizePath(path)
  entries <- utils::unzip(path, list = TRUE)$Name
  tmp <- tempfile("xlsx_")
  dir.create(tmp)
  utils::unzip(path, exdir = tmp)
  core <- file.path(tmp, "docProps", "core.xml")
  if (file.exists(core)) {
    x <- readLines(core, warn = FALSE, encoding = "UTF-8")
    x <- gsub("(<dcterms:(created|modified)[^>]*>)[^<]*(</dcterms:)", paste0("\\1", stamp, "\\3"), x)
    con <- file(core, "wb"); writeBin(charToRaw(paste(x, collapse = "\n")), con); close(con)
  }
  fixed <- as.POSIXct("2025-01-01 00:00:00", tz = "UTC")
  for (f in file.path(tmp, entries)) Sys.setFileTime(f, fixed)
  unlink(path)
  old <- setwd(tmp); on.exit(setwd(old))
  status <- system2("zip", c("-X", "-q", "-D", shQuote(path), shQuote(entries)))
  if (status != 0) stop("xlsx の書き直しに失敗しました: ", path)
  invisible(TRUE)
}
