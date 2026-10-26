# ---- 共通部分（local-src/_common.R） ----
# ビルド（scripts/build-r.mjs）で check_0XX.R の前につなぎ、全体を local({ ... }) で包む。
# そのため、ここで定義した関数や変数は学生のグローバル環境に残らない。
#
# 確認スクリプト（local-src/check_0XX.R）で使える関数:
#   r108_item(ok, label, hint = NULL)  確認項目を1つ記録して ✓/✗ を表示する
#   r108_find_quarto()                 quarto コマンドのパス（なければ NULL）
#   r108_render(qmd, to = "docx")      quarto でレンダリング → list(ok, output, log)
#                                      to は "docx"・"html"・"dashboard"（出力は .html）など
#   r108_read_qmd(qmd)                 qmd を読み、YAML・見出し・チャンク・@key を取り出す
#   r108_finish(step, code)            全項目合格なら修了コードを表示する
# 補助（任意）: r108_docx_text(docx), r108_docx_files(docx), r108_read_bib(bib),
#               r108_log_hint(log)（レンダリングのログからエラーの要点を取り出す）
#               r108_qmd_section(q, pattern)（r108_read_qmd() の結果から、見出しが pattern に合う節の本文の行）
#               r108_read_html(html)（HTML の見出し・表示されたコード・図・数値カード・表を数える）
#               r108_html_section(h, pattern)（r108_read_html() の結果から、見出しが pattern に合う節の文字列）
# Git（ステップ104・105・108）: r108_git_find(), r108_git(args, git), r108_git_install_hint(),
#               r108_git_toplevel(git), r108_git_n_commits(git), r108_git_tracked(git),
#               r108_git_ignored(path, git), r108_git_history_files(git), r108_git_dirty(git),
#               r108_secret_pattern（機密のファイル）, r108_token_patterns（トークンらしい文字列）
#
# 修了コードは平文で書かず、次で作った整数ベクトルを r108_finish() に渡す:
#   dput(bitwXor(utf8ToInt("R108-0XX-XXXX"), 42L))

if (getRversion() < "4.1.0") {
  stop("This script needs R 4.1 or later. Please install the latest R from https://cran.r-project.org/")
}

.r108 <- new.env(parent = emptyenv())
.r108$items <- data.frame(label = character(), ok = logical(), stringsAsFactors = FALSE)

# 確認項目を1つ記録し、✓ か ✗ を表示する。ok が NA・長さ0・エラーなら失敗。
r108_item <- function(ok, label, hint = NULL) {
  res <- tryCatch(
    suppressWarnings({
      v <- ok
      is.logical(v) && length(v) == 1L && !is.na(v) && v
    }),
    error = function(e) FALSE
  )
  .r108$items <- rbind(.r108$items, data.frame(label = label, ok = res, stringsAsFactors = FALSE))
  cat(if (res) "  \u2713 " else "  \u2717 ", label, "\n", sep = "")
  if (!res && !is.null(hint) && length(hint) > 0 && any(nzchar(hint))) {
    cat(paste0("      \u2192 ", hint, collapse = "\n"), "\n", sep = "")
  }
  invisible(res)
}

# quarto コマンドを探す。QUARTO_PATH → PATH → RStudio・Positron 同梱 → 標準のインストール先。
r108_find_quarto <- function() {
  exe <- if (.Platform$OS.type == "windows") "quarto.exe" else "quarto"
  ok_file <- function(p) length(p) == 1L && !is.na(p) && nzchar(p) && file.exists(p) && !dir.exists(p)
  env <- Sys.getenv("QUARTO_PATH")
  if (ok_file(env)) return(normalizePath(env, winslash = "/"))
  w <- Sys.which("quarto")[[1]]
  if (ok_file(w)) return(normalizePath(w, winslash = "/"))
  cands <- character()
  # RStudio は同梱 pandoc の場所を RSTUDIO_PANDOC に入れる（quarto/bin/tools/... の下）
  rp <- Sys.getenv("RSTUDIO_PANDOC")
  if (nzchar(rp)) {
    d <- rp
    for (i in 1:4) {
      cands <- c(cands, file.path(d, exe), file.path(d, "bin", exe), file.path(d, "quarto", "bin", exe))
      d <- dirname(d)
    }
  }
  if (.Platform$OS.type == "windows") {
    roots <- unique(c(Sys.getenv("LOCALAPPDATA"), Sys.getenv("ProgramFiles"),
                      Sys.getenv("ProgramW6432"), "C:/Program Files"))
    roots <- roots[nzchar(roots)]
    for (r in roots) {
      cands <- c(cands,
        file.path(r, "Programs", "Quarto", "bin", exe),
        file.path(r, "Quarto", "bin", exe),
        file.path(r, "RStudio", "resources", "app", "bin", "quarto", "bin", exe),
        file.path(r, "Programs", "RStudio", "resources", "app", "bin", "quarto", "bin", exe),
        file.path(r, "Positron", "resources", "app", "quarto", "bin", exe),
        file.path(r, "Programs", "Positron", "resources", "app", "quarto", "bin", exe))
    }
  } else {
    apps <- c("/Applications", file.path(path.expand("~"), "Applications"))
    for (a in apps) {
      cands <- c(cands,
        file.path(a, "quarto", "bin", exe),
        file.path(a, "RStudio.app", "Contents", "Resources", "app", "quarto", "bin", exe),
        file.path(a, "RStudio.app", "Contents", "MacOS", "quarto", "bin", exe),
        file.path(a, "Positron.app", "Contents", "Resources", "app", "quarto", "bin", exe))
    }
    cands <- c(cands, "/usr/local/bin/quarto", "/opt/quarto/bin/quarto",
               "/usr/lib/rstudio/resources/app/bin/quarto/bin/quarto",
               "/usr/lib/rstudio/bin/quarto/bin/quarto",
               "/usr/share/positron/resources/app/quarto/bin/quarto")
  }
  for (p in cands) if (ok_file(p)) return(normalizePath(p, winslash = "/"))
  NULL
}

# quarto で qmd をレンダリングする。PDF は TinyTeX が要るので、確認には docx を使う。
r108_render <- function(qmd, to = "docx") {
  fail <- function(log) list(ok = FALSE, output = NA_character_, log = log)
  if (!file.exists(qmd)) return(fail(paste0(qmd, " がありません。")))
  quarto <- r108_find_quarto()
  if (is.null(quarto)) return(fail("quarto が見つかりません。"))
  qmd <- normalizePath(qmd, winslash = "/")
  ext <- switch(to, docx = "docx", html = "html", dashboard = "html", revealjs = "html", pdf = "pdf", typst = "pdf", to)
  expected <- paste0(tools::file_path_sans_ext(qmd), ".", ext)
  start <- Sys.time() - 2
  # quarto がこの R を使うように QUARTO_R を一時的に設定し、終わったら元に戻す
  old <- Sys.getenv("QUARTO_R", unset = NA)
  Sys.setenv(QUARTO_R = file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"))
  on.exit(if (is.na(old)) Sys.unsetenv("QUARTO_R") else Sys.setenv(QUARTO_R = old), add = TRUE)
  out <- suppressWarnings(tryCatch(
    system2(quarto, c("render", shQuote(qmd), "--to", to), stdout = TRUE, stderr = TRUE),
    error = function(e) structure(conditionMessage(e), status = 127L)
  ))
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  log <- gsub("\033\\[[0-9;]*m", "", paste(out, collapse = "\n"))   # 色の制御文字を除く
  output <- expected
  if (!file.exists(output)) {
    # _quarto.yml の output-dir などで別の場所に出たとき
    found <- list.files(dirname(qmd), pattern = paste0("\\.", ext, "$"), recursive = TRUE, full.names = TRUE)
    found <- found[file.mtime(found) >= start]
    output <- if (length(found)) found[[1]] else NA_character_
  }
  ok <- status == 0L && !is.na(output) && file.exists(output) && file.mtime(output) >= start
  list(ok = isTRUE(ok), output = output, log = log)
}

# レンダリングのログから、エラーの行と「Quitting from」の行を取り出す（hint 用）
r108_log_hint <- function(log, n = 8) {
  l <- strsplit(log, "\n")[[1]]
  l <- trimws(l[nzchar(trimws(l))])
  err <- grep("^(Error|ERROR|\u30a8\u30e9\u30fc)|Quitting from|object .* not found", l)
  pick <- if (length(err)) unique(unlist(lapply(err, function(i) i + 0:3))) else seq.int(max(1L, length(l) - n + 1L), length(l))
  pick <- pick[pick >= 1 & pick <= length(l)]
  paste(utils::head(l[pick], n), collapse = "\n        ")
}

# qmd を UTF-8 で読み、YAML ヘッダ・見出し・チャンク・ラベル・@key を取り出す。
r108_read_qmd <- function(qmd) {
  lines <- readLines(qmd, encoding = "UTF-8", warn = FALSE)
  lines <- enc2utf8(lines)
  lines <- sub("^\ufeff", "", lines)
  # <!-- --> \u306e\u30e1\u30e2\u306f Word \u306b\u51fa\u306a\u3044\u306e\u3067\u3001\u884c\u6570\u3092\u4fdd\u3063\u305f\u307e\u307e\u7a7a\u306b\u3059\u308b\uff08\u4e2d\u306e @key \u3092\u5f15\u7528\u306b\u6570\u3048\u306a\u3044\uff09
  n <- length(lines)
  txt <- paste(lines, collapse = "\n")
  m <- gregexpr("(?s)<!--.*?-->", txt, perl = TRUE)
  regmatches(txt, m) <- lapply(regmatches(txt, m), function(x) gsub("[^\n]", "", x))
  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  length(lines) <- n            # 末尾の空行は strsplit で落ちるので補う
  lines[is.na(lines)] <- ""
  # YAML ヘッダ（先頭の --- から次の --- または ... まで）
  yaml_text <- character()
  body_from <- 1L
  first <- which(nzchar(trimws(lines)))[1]
  if (!is.na(first) && trimws(lines[first]) == "---") {
    ends <- which(trimws(lines) %in% c("---", "...") & seq_len(n) > first)
    if (length(ends)) {
      yaml_text <- lines[seq_len(ends[1] - first - 1L) + first]
      body_from <- ends[1] + 1L
    }
  }
  yaml <- NULL
  if (length(yaml_text) && requireNamespace("yaml", quietly = TRUE)) {
    yaml <- tryCatch(yaml::yaml.load(paste(yaml_text, collapse = "\n")), error = function(e) NULL)
  }
  # 本文をコードブロックの内と外に分ける
  in_code <- FALSE
  fence <- ""
  is_code <- logical(n)
  is_code[seq_len(body_from - 1L)] <- TRUE   # YAML は本文に含めない
  chunks <- list()
  cur <- NULL
  for (i in seq_len(n)[seq_len(n) >= body_from]) {
    l <- lines[i]
    if (!in_code) {
      m <- regmatches(l, regexec("^\\s*(`{3,}|~{3,})\\s*(.*)$", l))[[1]]
      if (length(m)) {
        in_code <- TRUE
        fence <- m[2]
        is_code[i] <- TRUE
        info <- trimws(m[3])
        cur <- list(start = i, header = info, engine = NA_character_, options = list(), code = character())
        hm <- regmatches(info, regexec("^\\{\\s*([A-Za-z0-9_]+)[ ,]*([^}]*)\\}", info))[[1]]
        if (length(hm)) {
          cur$engine <- hm[2]
          rest <- trimws(hm[3])
          # {r 名前} や {r, label = "名前"} の形のラベル
          if (nzchar(rest)) {
            lab <- regmatches(rest, regexec("label\\s*=\\s*[\"']?([^\"', ]+)", rest))[[1]]
            if (length(lab)) cur$options$label <- lab[2]
            else if (!grepl("=", strsplit(rest, ",")[[1]][1])) cur$options$label <- trimws(strsplit(rest, ",")[[1]][1])
          }
        }
        next
      }
    } else {
      is_code[i] <- TRUE
      if (grepl(paste0("^\\s*", substr(fence, 1, 1), "{", nchar(fence), ",}\\s*$"), l)) {
        in_code <- FALSE
        if (!is.na(cur$engine)) chunks[[length(chunks) + 1L]] <- cur
        cur <- NULL
        next
      }
      om <- regmatches(l, regexec("^\\s*#\\|\\s*([A-Za-z0-9_.-]+)\\s*:\\s*(.*)$", l))[[1]]
      if (length(om)) {
        val <- trimws(om[3])
        val <- sub("^([\"'])(.*)\\1$", "\\2", val)
        cur$options[[om[2]]] <- val
      } else {
        cur$code <- c(cur$code, l)
      }
    }
  }
  if (in_code && !is.null(cur) && !is.na(cur$engine)) chunks[[length(chunks) + 1L]] <- cur
  body <- lines
  body[is_code] <- ""
  # 見出し（コードブロックの中の # は数えない）
  hl <- which(!is_code & grepl("^#{1,6}\\s+\\S", lines))
  headings <- data.frame(
    line = hl,
    level = nchar(sub("^(#{1,6}).*$", "\\1", lines[hl])),
    text = trimws(sub("\\s*\\{[^}]*\\}\\s*$", "", sub("^#{1,6}\\s+", "", lines[hl]))),
    stringsAsFactors = FALSE
  )
  # ラベル: チャンクの #| label: と、本文の {#fig-...} {#tbl-...} {#sec-...}
  chunk_labels <- vapply(chunks, function(ch) if (is.null(ch$options$label)) NA_character_ else ch$options$label, "")
  inline_labels <- unlist(regmatches(body, gregexpr("\\{#[A-Za-z0-9_:-]+", body)))
  inline_labels <- sub("^\\{#", "", inline_labels)
  labels <- unique(c(chunk_labels[!is.na(chunk_labels)], inline_labels))
  # 本文の @key（メールアドレスの @ は除く）
  txt <- paste(body, collapse = "\n")
  keys <- regmatches(txt, gregexpr("(?<![A-Za-z0-9_.@-])-?@\\{?[A-Za-z0-9_][A-Za-z0-9_:.#$%&+?<>~/-]*", txt, perl = TRUE))[[1]]
  keys <- sub("^-?@\\{?", "", keys)
  keys <- sub("[.:#$%&+?<>~/-]+$", "", keys)
  keys <- keys[nzchar(keys)]
  is_xref <- grepl("^(fig|tbl|sec|eq|lst|thm|lem|cor|prp|cnj|def|exm|exr)-", keys)
  list(
    lines = lines,
    yaml = yaml,
    yaml_text = yaml_text,
    headings = headings,
    chunks = chunks,
    labels = labels,
    refs = keys,
    cites = unique(keys[!is_xref]),
    crossrefs = unique(keys[is_xref]),
    body = body
  )
}

# r108_read_qmd() の結果から、見出しが pattern（正規表現）に合う最初の節の本文の行を返す。
# 節は次の同じかより上の階層の見出しの手前まで。コードチャンクの行は空になっている（インラインの `r ` は残る）。
r108_qmd_section <- function(q, pattern) {
  if (is.null(q) || !nrow(q$headings)) return(character())
  w <- grep(pattern, q$headings$text)
  if (!length(w)) return(character())
  i <- w[1]
  from <- q$headings$line[i] + 1L
  nxt <- which(seq_len(nrow(q$headings)) > i & q$headings$level <= q$headings$level[i])
  to <- if (length(nxt)) q$headings$line[nxt[1]] - 1L else length(q$body)
  if (to < from) return(character())
  q$body[from:to]
}

# HTML（quarto の html・dashboard の出力）を UTF-8 で読み、次を返す。一時ファイルは作らない。
#   html      … <script>・<style> を除いた HTML の文字列
#   text      … タグを除いた本文の文字列
#   headings  … 見出し（level, text, title = 題名の h1 か, start, end = HTML の中の位置）
#   n_code    … 表示されているコードのブロックの数（echo: true や code-fold で出る cell-code。code-fold は畳んでも数える）
#   n_img     … 図（<img> の png・jpg・svg・gif・data:image）の数
#   n_widget  … htmlwidgets（plotly など）の数
#   n_valuebox… 数値カード（ダッシュボードの valuebox）の数
#   n_table   … <table> の数
# HTML の断片からタグを除き、よく使う文字参照を戻す
r108_strip_tags <- function(s) {
  s <- gsub("<[^>]+>", "", s)
  s <- gsub("&nbsp;|&#160;", " ", s)
  s <- gsub("&lt;", "<", s, fixed = TRUE)
  s <- gsub("&gt;", ">", s, fixed = TRUE)
  s <- gsub("&quot;", "\"", s, fixed = TRUE)
  s <- gsub("&#39;|&#x27;|&apos;", "'", s)
  gsub("&amp;", "&", s, fixed = TRUE)
}

r108_read_html <- function(html) {
  x <- enc2utf8(paste(readLines(html, encoding = "UTF-8", warn = FALSE), collapse = "\n"))
  x <- gsub("(?is)<script\\b.*?</script>", "", x, perl = TRUE)
  x <- gsub("(?is)<style\\b.*?</style>", "", x, perl = TRUE)
  x <- gsub("(?s)<!--.*?-->", "", x, perl = TRUE)
  strip <- r108_strip_tags
  m <- gregexpr("(?is)<h([1-6])\\b([^>]*)>(.*?)</h\\1>", x, perl = TRUE)[[1]]
  headings <- data.frame(level = integer(), text = character(), title = logical(),
                         start = integer(), end = integer(), stringsAsFactors = FALSE)
  if (m[1] > 0) {
    st <- attr(m, "capture.start"); ln <- attr(m, "capture.length")
    cap <- function(k) substring(x, st[, k], st[, k] + ln[, k] - 1L)
    headings <- data.frame(
      level = as.integer(cap(1)),
      text = trimws(gsub("\\s+", " ", strip(cap(3)))),
      title = grepl("\\btitle\\b", cap(2)) & !grepl("card-title|value-box-title", cap(2)),
      start = as.integer(m),
      end = as.integer(m) + attr(m, "match.length") - 1L,
      stringsAsFactors = FALSE)
  }
  classes <- regmatches(x, gregexpr("class=\"[^\"]*\"", x))[[1]]
  has_class <- function(tokens) sum(vapply(strsplit(gsub("^class=\"|\"$", "", classes), "\\s+"),
                                           function(cl) any(cl %in% tokens), logical(1)))
  imgs <- regmatches(x, gregexpr("(?i)<img\\b[^>]*>", x, perl = TRUE))[[1]]
  imgs <- imgs[grepl("(?i)src=[\"'](data:image/|[^\"']+\\.(png|jpe?g|svg|gif)[\"'?#])", imgs, perl = TRUE)]
  list(
    html = x,
    text = strip(x),
    headings = headings,
    n_code = has_class("cell-code"),
    n_img = length(imgs),
    n_widget = has_class("html-widget"),
    n_valuebox = has_class(c("valuebox", "bslib-value-box")),
    n_table = sum(gregexpr("(?i)<table\\b", x, perl = TRUE)[[1]] > 0)
  )
}

# r108_read_html() の結果から、見出しが pattern（正規表現）に合う最初の節の文字列（タグを除く）を返す。
# 節は次の同じかより上の階層の見出しの手前まで。題名（title）の h1 は数えない。
r108_html_section <- function(h, pattern) {
  hd <- h$headings[!h$headings$title, , drop = FALSE]
  w <- grep(pattern, hd$text)
  if (!length(w)) return("")
  i <- w[1]
  nxt <- which(seq_len(nrow(hd)) > i & hd$level <= hd$level[i])
  to <- if (length(nxt)) hd$start[nxt[1]] - 1L else nchar(h$html)
  s <- substr(h$html, hd$end[i] + 1L, to)
  trimws(gsub("\\s+", " ", r108_strip_tags(s)))
}

# docx の中のファイル一覧（word/media/ に画像があるかなどを調べる）
r108_docx_files <- function(docx) {
  tryCatch(utils::unzip(docx, list = TRUE)$Name, error = function(e) character())
}

# docx の本文（word/document.xml）からタグを除いた文字列。一時ファイルは作らない。
r108_docx_text <- function(docx, xml = FALSE) {
  con <- unz(docx, "word/document.xml", encoding = "UTF-8")
  on.exit(close(con))
  x <- paste(readLines(con, warn = FALSE, encoding = "UTF-8"), collapse = "")
  x <- enc2utf8(x)
  if (xml) return(x)
  x <- gsub("</w:p>", "\n", x, fixed = TRUE)
  x <- gsub("<w:tab/>", "\t", x, fixed = TRUE)
  x <- gsub("<[^>]+>", "", x)
  x <- gsub("&lt;", "<", x, fixed = TRUE)
  x <- gsub("&gt;", ">", x, fixed = TRUE)
  x <- gsub("&quot;", "\"", x, fixed = TRUE)
  x <- gsub("&apos;", "'", x, fixed = TRUE)
  gsub("&amp;", "&", x, fixed = TRUE)
}

# references.bib のキーの一覧
r108_read_bib <- function(bib) {
  b <- enc2utf8(readLines(bib, encoding = "UTF-8", warn = FALSE))
  m <- regmatches(b, regexec("^\\s*@([A-Za-z]+)\\s*[{(]\\s*([^,[:space:]]+)\\s*,", b))
  keys <- vapply(m, function(x) if (length(x) && tolower(x[2]) != "comment" && tolower(x[2]) != "string") x[3] else NA_character_, "")
  unique(keys[!is.na(keys)])
}

# ---- Git の確認に使う関数（ステップ104・105・108。git は読むだけで、リポジトリを書き換えない） ----


# git コマンドのパス。見つからなければ NULL。macOS で開発ツールが入っていないときは、
# /usr/bin/git を実行するとインストールの画面が出るので、実行せずに NULL を返す。
r108_git_find <- function() {
  ok_file <- function(p) length(p) == 1L && !is.na(p) && nzchar(p) && file.exists(p) && !dir.exists(p)
  w <- Sys.which("git")[[1]]
  cands <- if (ok_file(w)) w else character()
  if (.Platform$OS.type == "windows") {
    roots <- unique(c(Sys.getenv("ProgramFiles"), Sys.getenv("ProgramW6432"), "C:/Program Files",
                      file.path(Sys.getenv("LOCALAPPDATA"), "Programs")))
    roots <- roots[nzchar(roots)]
    cands <- c(cands, file.path(roots, "Git", "cmd", "git.exe"), file.path(roots, "Git", "bin", "git.exe"))
  } else {
    cands <- c(cands, "/opt/homebrew/bin/git", "/usr/local/bin/git", "/usr/bin/git")
  }
  for (p in unique(cands)) {
    if (!ok_file(p)) next
    if (Sys.info()[["sysname"]] == "Darwin" && normalizePath(p) == "/usr/bin/git") {
      dev <- suppressWarnings(tryCatch(system2("xcode-select", "-p", stdout = TRUE, stderr = TRUE),
                                       error = function(e) structure("", status = 1L)))
      if (!is.null(attr(dev, "status")) || !length(dev) || !dir.exists(dev[1])) next
    }
    return(normalizePath(p, winslash = "/"))
  }
  NULL
}

# git を実行し、list(ok, status, out) を返す。リポジトリを書き換えないよう --no-optional-locks を付ける。
r108_git <- function(args, git = r108_git_find()) {
  if (is.null(git)) return(list(ok = FALSE, status = 127L, out = character()))
  q <- function(x) ifelse(grepl("^[A-Za-z0-9_./=:@-]+$", x), x, shQuote(x))
  out <- suppressWarnings(tryCatch(
    system2(git, c("--no-optional-locks", "-c", "core.quotepath=off", "-c", "color.ui=never", q(args)),
            stdout = TRUE, stderr = TRUE),
    error = function(e) structure(conditionMessage(e), status = 127L)))
  st <- attr(out, "status")
  if (is.null(st)) st <- 0L
  out <- enc2utf8(as.character(out))
  list(ok = st == 0L, status = st, out = out)
}

# git の入れ方（OS ごと）
r108_git_install_hint <- function() {
  if (.Platform$OS.type == "windows") {
    "Git for Windows を https://gitforwindows.org/ から入れ、RStudio を再起動してから、もう一度 source してください。"
  } else if (Sys.info()[["sysname"]] == "Darwin") {
    "macOS のターミナルで xcode-select --install を実行して開発ツール（Command Line Tools）を入れ、RStudio を再起動してから、もう一度 source してください。"
  } else {
    "Git を入れ（例 sudo apt install git）、RStudio を再起動してから、もう一度 source してください。"
  }
}

# 作業フォルダがリポジトリの一番上か。list(is_repo, top, here)
r108_git_toplevel <- function(git) {
  r <- r108_git(c("rev-parse", "--show-toplevel"), git)
  here <- normalizePath(getwd(), winslash = "/")
  top <- if (r$ok && length(r$out)) normalizePath(r$out[1], winslash = "/", mustWork = FALSE) else NA_character_
  list(is_repo = r$ok, top = top, here = here,
       at_top = r$ok && !is.na(top) && identical(tolower(top), tolower(here)))
}

# コミットの数（HEAD から数える）。コミットがなければ 0
r108_git_n_commits <- function(git) {
  r <- r108_git(c("rev-list", "--count", "HEAD"), git)
  if (!r$ok || !length(r$out)) return(0L)
  n <- suppressWarnings(as.integer(r$out[1]))
  if (is.na(n)) 0L else n
}

# 追跡しているファイル（HEAD ではなく、いまのインデックス）
r108_git_tracked <- function(git) {
  r <- r108_git(c("ls-files"), git)
  if (r$ok) r$out else character()
}

# path が .gitignore で除外されるか（ファイルがなくても、追跡していても、規則だけで判定する）
r108_git_ignored <- function(path, git) {
  r108_git(c("check-ignore", "--no-index", "-q", path), git)$status == 0L
}

# 過去のどのコミット（すべてのブランチ）に入ったことがあるファイルの一覧
r108_git_history_files <- function(git) {
  r <- r108_git(c("log", "--all", "--format=", "--name-only"), git)
  if (!r$ok) return(character())
  unique(r$out[nzchar(r$out)])
}

# 機密として扱うファイル（data/ の中と .Renviron）
r108_secret_pattern <- "(^|/)data/|(^|/)\\.Renviron$"

# まだコミットしていない変更（check_1XX.R は除く）
r108_git_dirty <- function(git) {
  r <- r108_git(c("status", "--porcelain", "--untracked-files=all"), git)
  if (!r$ok) return(NA_character_)
  x <- r$out[nzchar(r$out)]
  files <- sub("^.. ", "", x)
  files <- sub("^.* -> ", "", files)
  x[!grepl("(^|/)check_[0-9]{3}\\.R$", files)]
}

# トークンや API キーらしい文字列（git grep -E で使う）
r108_token_patterns <- c("ghp_[A-Za-z0-9]{30,}", "github_pat_[A-Za-z0-9_]{30,}", "gh[ousr]_[A-Za-z0-9]{30,}",
                         "sk-[A-Za-z0-9_-]{20,}", "AKIA[0-9A-Z]{16}", "-----BEGIN [A-Z ]*PRIVATE KEY-----")

# 全項目が合格なら修了コードを表示する。code は bitwXor(utf8ToInt(コード), 42L) の整数ベクトル。
r108_finish <- function(step, code) {
  items <- .r108$items
  n_ok <- sum(items$ok)
  n <- nrow(items)
  cat("\n")
  if (n > 0 && n_ok == n) {
    cc <- if (is.numeric(code)) intToUtf8(bitwXor(as.integer(code), 42L)) else as.character(code)
    bar <- strrep("=", 44)
    cat(bar, "\n", sep = "")
    cat("  ステップ", as.integer(step), "の確認に すべて合格しました（", n, "項目）\n", sep = "")
    cat("\n      修了コード:  ", cc, "\n\n", sep = "")
    cat("  このコードをアプリのステップ", as.integer(step), "の画面に貼り付けてください。\n", sep = "")
    cat(bar, "\n", sep = "")
    invisible(list(passed = TRUE, code = cc))
  } else {
    cat(n, " 項目のうち ", n - n_ok, " 項目が合格していません（\u2717 の項目）。\n", sep = "")
    cat("\u2192 の説明に沿って直してから、もう一度 source してください。\n", sep = "")
    invisible(list(passed = FALSE, code = NULL))
  }
}
