# ステップ102「Shiny入門」の確認
# アプリを起動（runApp）はせず、学生の PC を止めない方法で確かめる。
# 1. shiny が入っている（1.5.0 以降。testServer() を使うため）
# 2. app.R があり、文法の誤りがない。最後が shinyApp(ui, server) で、runApp() を書いていない
# 3. shiny::shinyAppFile("app.R") で読み込める（データの読み込みを含めて app.R が最後まで動く）
# 4. 画面（ui）の HTML に入力が1つ以上、出力が1つ以上ある
# 5. server で reactive() を使っている
# 6. shiny::testServer() で server を動かし、入力に初期値を入れると、すべての出力がエラーなく作られる
# 7. 入力を別の値に変えると、出力のどれかが変わる
# 学生のフォルダにファイルは作らない（図は testServer が一時ファイルに描く）。

cat("ステップ102「Shiny入門」の確認\n")
cat("アプリのフォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

# ---- 1. shiny ----
has_shiny <- requireNamespace("shiny", quietly = TRUE)
shiny_ok <- has_shiny && utils::packageVersion("shiny") >= "1.5.0"
r108_item(shiny_ok,
  paste0("shiny パッケージが入っている",
         if (has_shiny) paste0("（", utils::packageVersion("shiny"), "）") else ""),
  if (has_shiny) "shiny が古すぎます。install.packages(\"shiny\") で新しくしてから、R を再起動しましょう。"
  else "コンソールで install.packages(\"shiny\") を実行してから、もう一度 source してください。")

# ---- 2. app.R ----
app_file <- "app.R"
has_app <- file.exists(app_file)
r108_item(has_app, "このフォルダに app.R がある",
  c(if (length(list.files(pattern = "\\.[Rr]$"))) paste0("いまあるスクリプト: ",
      paste(utils::head(setdiff(list.files(pattern = "\\.[Rr]$"), "check_102.R"), 5), collapse = ", ")),
    "アプリのコードは、ファイル名を app.R にしてプロジェクトのフォルダの一番上に保存します。check_102.R も同じフォルダに置きます。"))

parsed <- if (has_app) tryCatch(parse(app_file, keep.source = TRUE, encoding = "UTF-8"), error = function(e) e) else NULL
parse_ok <- has_app && !inherits(parsed, "error")
if (has_app) {
  r108_item(parse_ok, "app.R に文法の誤りがない",
    if (inherits(parsed, "error")) paste0("app.R を読めません: ", conditionMessage(parsed),
      "\n      かっこ ( ) や { }、カンマの数を確かめましょう。RStudio ではエディタの左端に赤い × が出ます。"))
}
calls <- character()
if (parse_ok) {
  pd <- utils::getParseData(parsed)
  if (!is.null(pd) && nrow(pd)) calls <- unique(pd$text[pd$token == "SYMBOL_FUNCTION_CALL"])
}
ends_ok <- parse_ok && length(parsed) > 0 &&
  is.call(parsed[[length(parsed)]]) &&
  identical(sub("^shiny::", "", paste(deparse(parsed[[length(parsed)]][[1]]), collapse = "")), "shinyApp") &&
  !any(c("runApp", "runGadget") %in% calls)
r108_item(ends_ok, "app.R の最後の行が shinyApp(ui, server) で、runApp() を書いていない",
  if (!parse_ok) "先に上の項目を直しましょう。"
  else if (any(c("runApp", "runGadget") %in% calls)) "app.R の中に runApp() を書くと、読み込んだだけでアプリが起動して止まらなくなります。app.R からは消し、起動は RStudio の「Run App」かコンソールで行いましょう。"
  else "app.R は ui と server を作り、最後の行に shinyApp(ui, server) を書きます。")

# ---- 3. shinyAppFile で読み込む ----
app <- NULL
load_msg <- ""
if (shiny_ok && parse_ok && ends_ok) {
  cat("\napp.R を読み込んでいます（アプリは起動しません）…\n")
  app <- tryCatch(
    suppressMessages(suppressWarnings(shiny::shinyAppFile(app_file))),
    error = function(e) { load_msg <<- conditionMessage(e); NULL })
}
load_ok <- !is.null(app)
r108_item(load_ok, "shinyAppFile(\"app.R\") でエラーなく読み込める（データの読み込みを含む）",
  if (!(shiny_ok && parse_ok && ends_ok)) "先に上の項目を直しましょう。"
  else c(paste0("エラー: ", load_msg),
    if (grepl("cannot open|does not exist|存在しません|開くことができません", load_msg))
      "データのパスを確かめましょう。app.R と同じフォルダの data フォルダに置き、read_csv(\"data/sora_stores.csv\") のように書きます。"
    else if (grepl("could not find function|見つけることができませんでした", load_msg))
      "その関数のパッケージを app.R の先頭で library() しているか確かめましょう。"
    else "RStudio で app.R を開いて「Run App」を押し、コンソールに出るエラーも見てみましょう。"))

# ---- 4. 画面の HTML から入力と出力を探す ----
html <- ""
if (load_ok) {
  req <- list(PATH_INFO = "/", REQUEST_METHOD = "GET", QUERY_STRING = "", SCRIPT_NAME = "",
              HTTP_HOST = "127.0.0.1", SERVER_NAME = "127.0.0.1", SERVER_PORT = "80",
              rook.url_scheme = "http")
  res <- tryCatch(suppressWarnings(app$httpHandler(req)), error = function(e) e)
  if (!inherits(res, "error") && !is.null(res$content)) {
    html <- res$content
    if (is.raw(html)) html <- rawToChar(html)
    html <- enc2utf8(paste(html, collapse = "\n"))
    Encoding(html) <- "UTF-8"
  }
}

attrs_of <- function(tag) {
  m <- regmatches(tag, gregexpr("([A-Za-z_:][-A-Za-z0-9_:.]*)(=\"[^\"]*\"|='[^']*')?", tag))[[1]][-1]
  nm <- sub("=.*$", "", m)
  val <- sub("^[^=]*=?", "", m)
  val <- sub("^[\"'](.*)[\"']$", "\\1", val)
  val <- gsub("&amp;", "&", gsub("&lt;", "<", gsub("&gt;", ">", gsub("&quot;", "\"", gsub("&#39;", "'", val, fixed = TRUE), fixed = TRUE), fixed = TRUE), fixed = TRUE), fixed = TRUE)
  stats::setNames(as.list(val), tolower(nm))
}
num1 <- function(x) { v <- suppressWarnings(as.numeric(x)); if (length(v) != 1L) NA_real_ else v }
has_class <- function(a, cls) !is.null(a$class) && any(strsplit(a$class, "\\s+")[[1]] %in% cls)

# 入力ごとに、初期値と、変えてみる値（あれば）を決める
find_inputs <- function(html) {
  tags <- regmatches(html, gregexpr("<(select|input|textarea|button|div)\\b[^>]*>", html))[[1]]
  pos <- gregexpr("<(select|input|textarea|button|div)\\b[^>]*>", html)[[1]]
  out <- list()
  add <- function(id, type, default, alt = NULL) {
    if (is.null(out[[id]])) out[[id]] <<- list(id = id, type = type, default = default, alt = alt)
  }
  for (i in seq_along(tags)) {
    tg <- tags[i]
    a <- attrs_of(tg)
    el <- tolower(sub("^<([A-Za-z]+).*$", "\\1", tg))
    id <- a$id
    if (el == "select" && !is.null(id)) {
      rest <- substring(html, pos[i])
      body <- sub("(?s)</select>.*$", "", rest, perl = TRUE)
      opts <- regmatches(body, gregexpr("<option\\b[^>]*>", body))[[1]]
      vals <- vapply(opts, function(o) { v <- attrs_of(o)$value; if (is.null(v)) NA_character_ else v }, "", USE.NAMES = FALSE)
      sel <- grepl("\\bselected\\b", opts)
      vals_ok <- vals[!is.na(vals)]
      multi <- !is.null(a$multiple)
      def <- if (any(sel)) vals[sel] else if (length(vals_ok) && !multi) vals_ok[1] else character()
      alt_v <- setdiff(vals_ok, def)
      add(id, "select", if (multi) def else def[1], if (length(alt_v)) alt_v[1] else NULL)
    } else if (el == "div" && !is.null(id) && has_class(a, c("shiny-input-radiogroup", "shiny-input-checkboxgroup"))) {
      boxes <- regmatches(html, gregexpr("<input\\b[^>]*>", html))[[1]]
      boxes <- boxes[vapply(boxes, function(b) identical(attrs_of(b)$name, id), TRUE)]
      vals <- vapply(boxes, function(o) { v <- attrs_of(o)$value; if (is.null(v)) NA_character_ else v }, "", USE.NAMES = FALSE)
      chk <- grepl("\\bchecked\\b", boxes)
      if (has_class(a, "shiny-input-radiogroup")) {
        def <- if (any(chk)) vals[chk][1] else if (length(vals)) vals[1] else NULL
        alt_v <- setdiff(vals, def)
        add(id, "radio", def, if (length(alt_v)) alt_v[1] else NULL)
      } else {
        def <- vals[chk]
        alt_v <- if (length(vals) && !identical(sort(def), sort(vals))) vals else if (length(vals) > 1) vals[1] else NULL
        add(id, "checkboxgroup", def, alt_v)
      }
    } else if (el == "div" && !is.null(id) && has_class(a, c("shiny-date-input", "shiny-date-range-input"))) {
      rest <- substring(html, pos[i], pos[i] + 3000)
      d <- regmatches(rest, gregexpr("data-initial-date=\"([^\"]*)\"", rest))[[1]]
      d <- sub("^data-initial-date=\"([^\"]*)\"$", "\\1", d)
      d <- d[nzchar(d)]
      n <- if (has_class(a, "shiny-date-range-input")) 2L else 1L
      def <- if (length(d) >= n) as.Date(d[seq_len(n)]) else rep(Sys.Date(), n)
      add(id, "date", def, def - 30)
    } else if (el == "input" && !is.null(id)) {
      type <- if (is.null(a$type)) "text" else tolower(a$type)
      if (has_class(a, "js-range-slider")) {
        mn <- num1(a$`data-min`); mx <- num1(a$`data-max`); from <- num1(a$`data-from`); to <- num1(a$`data-to`)
        is_date <- !is.null(a$`data-data-type`) && a$`data-data-type` %in% c("date", "datetime")
        conv <- function(x) if (is_date) as.Date(as.POSIXct(x / 1000, origin = "1970-01-01", tz = "UTC")) else x
        if (!is.na(to)) {
          def <- conv(c(from, to))
          alt_v <- conv(c(mn, mx))
          if (identical(def, alt_v)) alt_v <- conv(c(mn, (mn + mx) / 2))
        } else {
          def <- conv(from)
          alt_v <- conv(if (!is.na(mx) && from != mx) mx else mn)
        }
        add(id, "slider", def, if (!identical(def, alt_v)) alt_v else NULL)
      } else if (type == "checkbox") {
        chk <- !is.null(a$checked)
        add(id, "checkbox", chk, !chk)
      } else if (type == "number") {
        v <- num1(a$value)
        if (is.na(v)) v <- 1
        st <- num1(a$step); if (is.na(st)) st <- 1
        mx <- num1(a$max)
        alt_v <- if (!is.na(mx) && v + st > mx) v - st else v + st
        add(id, "number", v, alt_v)
      } else if (type %in% c("text", "password", "search", "email", "url") &&
                 (has_class(a, c("shiny-input-text", "shiny-input-password", "form-control")))) {
        v <- if (is.null(a$value)) "" else a$value
        add(id, "text", v, paste0(v, "a"))
      }
    } else if (el == "textarea" && !is.null(id)) {
      add(id, "text", "", "a")
    } else if (el == "button" && !is.null(id) && has_class(a, c("action-button", "shiny-download-link"))) {
      if (has_class(a, "action-button")) add(id, "button", 0L, 1L)
    }
  }
  out
}

find_outputs <- function(html) {
  tags <- regmatches(html, gregexpr("<[A-Za-z]+\\b[^>]*\\bid=\"[^\"]+\"[^>]*>", html))[[1]]
  ids <- character()
  for (tg in tags) {
    a <- attrs_of(tg)
    if (!is.null(a$class) && grepl("(^|\\s)(shiny-[a-z-]*output|html-widget-output|shiny-bound-output|uiOutput)(\\s|$)", a$class)) {
      ids <- c(ids, a$id)
    }
  }
  unique(ids)
}

inputs <- if (nzchar(html)) tryCatch(find_inputs(html), error = function(e) list()) else list()
outputs <- if (nzchar(html)) tryCatch(find_outputs(html), error = function(e) character()) else character()
r108_item(load_ok && length(inputs) >= 1,
  paste0("画面（ui）に入力が1つ以上ある",
         if (length(inputs)) paste0("（", paste(names(inputs), collapse = ", "), "）") else ""),
  if (!load_ok) "先に上の項目を直しましょう。"
  else "ui に selectInput(\"region\", \"地域\", choices = ...) のような入力を置きましょう。")
r108_item(load_ok && length(outputs) >= 1,
  paste0("画面（ui）に出力が1つ以上ある",
         if (length(outputs)) paste0("（", paste(outputs, collapse = ", "), "）") else ""),
  if (!load_ok) "先に上の項目を直しましょう。"
  else "ui に plotOutput(\"sales_plot\") のような出力の置き場所を作りましょう。")

# ---- 5. reactive ----
r108_item(parse_ok && "reactive" %in% calls, "server で reactive() を使っている",
  "選んだ地域で絞り込んだデータを selected <- reactive({ ... }) で作り、図と表の両方で selected() として使いましょう。")

# ---- 6・7. testServer で server を動かす ----
run_outputs <- function(app, inputs, outputs) {
  defaults <- lapply(inputs, `[[`, "default")
  defaults <- defaults[!vapply(defaults, is.null, TRUE)]
  # testServer の中で書き換えるので、環境に結果を入れる
  st <- new.env()
  st$ok <- FALSE; st$errors <- character(); st$changed <- character(); st$changed_by <- ""; st$fatal <- ""
  get_all <- function(output) {
    lapply(stats::setNames(outputs, outputs), function(o) tryCatch(output[[o]], error = function(e) e))
  }
  is_bad <- function(v) inherits(v, "error") && !inherits(v, c("shiny.silent.error", "validation"))
  strip <- function(v) {
    if (is.list(v) && !is.null(v$src)) v$src else if (is.list(v)) v[setdiff(names(v), c("coordmap", "alt"))] else v
  }
  body_fun <- function(session, output) {
    if (length(defaults)) do.call(session$setInputs, defaults)
    v0 <- get_all(output)
    bad <- names(v0)[vapply(v0, is_bad, TRUE)]
    st$errors <- vapply(bad, function(o) paste0("output$", o, ": ", conditionMessage(v0[[o]])), "")
    st$ok <- length(bad) == 0
    if (st$ok) {
      for (inp in inputs) {
        if (is.null(inp$alt)) next
        do.call(session$setInputs, stats::setNames(list(inp$alt), inp$id))
        v1 <- get_all(output)
        ch <- outputs[vapply(outputs, function(o) !identical(strip(v0[[o]]), strip(v1[[o]])), TRUE)]
        if (length(ch)) { st$changed <- ch; st$changed_by <- inp$id; break }
        do.call(session$setInputs, stats::setNames(list(inp$default), inp$id))
      }
    }
  }
  tryCatch(
    suppressMessages(suppressWarnings(shiny::testServer(app, body_fun(session, output)))),
    error = function(e) st$fatal <- conditionMessage(e))
  as.list(st)
}

can_test <- load_ok && length(inputs) >= 1 && length(outputs) >= 1
if (can_test) {
  cat("\nserver を動かして、出力を作っています…\n")
  tr <- run_outputs(app, inputs, outputs)
  r108_item(tr$ok && !nzchar(tr$fatal),
    "入力に初期値を入れると、すべての出力がエラーなく作られる",
    if (nzchar(tr$fatal)) paste0("server を動かせませんでした: ", tr$fatal)
    else c(paste0("エラー: ", utils::head(tr$errors, 3)),
      if (any(grepl("hasn't been defined|has not been defined|not been defined", tr$errors)))
        "ui の出力の名前（plotOutput(\"sales_plot\") の \"sales_plot\"）と、server の output$sales_plot の名前がそろっているか確かめましょう。"
      else "RStudio で「Run App」を押してアプリを動かし、コンソールに出るエラーを見て直しましょう。"))
  r108_item(tr$ok && length(tr$changed) >= 1,
    paste0("入力を変えると出力が変わる",
           if (length(tr$changed)) paste0("（", tr$changed_by, " を変えると ", paste(tr$changed, collapse = ", "), " が変わる）") else ""),
    if (!tr$ok) "先に上の項目を直しましょう。"
    else "出力を作る render の中で input$region（または reactive で作った selected()）を使い、選んだ値でデータを絞り込みましょう。")
} else {
  msg <- "上の項目（読み込み・入力・出力）を直すと、server を動かして確かめます。"
  r108_item(FALSE, "入力に初期値を入れると、すべての出力がエラーなく作られる", msg)
  r108_item(FALSE, "入力を変えると出力が変わる", msg)
}

r108_finish(102, c(120L, 27L, 26L, 18L, 7L, 27L, 26L, 24L, 7L, 110L, 110L, 110L, 108L))
