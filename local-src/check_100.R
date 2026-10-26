# ステップ100: Quarto で業務レポート
# 確かめること: report.qmd が ec_orders・ec_products を読み、YAML ヘッダに html 出力・コードを表示しない設定・
# params があり、コードで params$… を使い、最初の見出しが「要約」で、要約の数値をインラインコードで書いていること。
# HTML にレンダリングでき、HTML にコードが表示されず、冒頭が要約の節で、図があること。

cat("R108 ステップ100「Quartoで業務レポート」の確認を始めます。\n")
cat("作業フォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

qmd <- "report.qmd"
others <- setdiff(list.files(".", pattern = "\\.qmd$"), c(qmd, "paper.qmd", "mini_thesis.qmd", "dashboard.qmd"))
r108_item(file.exists(qmd),
  "作業フォルダに report.qmd がある",
  if (length(others)) paste0(paste(others, collapse = ", "), " はありますが、レポートの名前を report.qmd にしてください。")
  else "アプリから雛形 report.qmd をダウンロードし、プロジェクトのフォルダに置いてください。")

q <- if (file.exists(qmd)) tryCatch(r108_read_qmd(qmd), error = function(e) NULL) else NULL
code <- if (is.null(q)) "" else paste(unlist(lapply(q$chunks, `[[`, "code")), collapse = "\n")

need <- c("ec_orders.csv", "ec_products.csv")
miss_data <- need[!file.exists(file.path("data", need))]
r108_item(length(miss_data) == 0 && all(vapply(need, function(f) grepl(f, code, fixed = TRUE), logical(1))),
  "data フォルダに ec_orders.csv と ec_products.csv があり、チャンクの中で読み込んでいる",
  if (length(miss_data)) paste0("アプリから ", paste(miss_data, collapse = " と "), " をダウンロードし、data フォルダに置きます。")
  else "setup のチャンクで read_csv(\"data/ec_orders.csv\") と read_csv(\"data/ec_products.csv\") を実行します。")

# ---- YAML ヘッダ ----
yaml_str <- function(x) if (is.character(x) && length(x) >= 1) paste(x, collapse = " ") else ""
title <- yaml_str(q$yaml$title)
author <- yaml_str(unlist(q$yaml$author))
r108_item(nzchar(trimws(title)) && nzchar(trimws(author)) && !grepl("^\\s*氏名\\s*$", author),
  "YAML ヘッダに題名（title）と自分の名前（author）がある",
  "雛形の author: \"氏名\" を自分の名前に書き換えます。")

fmt <- q$yaml$format
fmt_names <- if (is.list(fmt)) names(fmt) else as.character(fmt)
r108_item("html" %in% fmt_names,
  "YAML ヘッダの format に html がある",
  "YAML ヘッダに format: html と書きます（雛形のように format: の下に html: と書いても同じです）。")

is_false <- function(v) isFALSE(v) || identical(tolower(as.character(v)), "false")
echo_yaml <- is_false(q$yaml$execute$echo) || (is.list(fmt) && is_false(fmt$html$echo))
echo_chunks <- length(q$chunks) > 0 && all(vapply(q$chunks, function(ch) is_false(ch$options$echo), logical(1)))
r108_item(!is.null(q) && (echo_yaml || echo_chunks),
  "コードを表示しない設定（execute: の echo: false）がある",
  "YAML ヘッダに次の2行を加えます（行の先頭の空白もそのまま）。\n        execute:\n          echo: false")

# ---- パラメータ ----
pr <- q$yaml$params
pnames <- if (is.list(pr)) names(pr) else character()
used <- pnames[vapply(pnames, function(p) grepl(paste0("params\\s*\\$\\s*`?", p, "\\b"), code, perl = TRUE), logical(1))]
r108_item(length(pnames) >= 1 && length(used) >= 1,
  paste0("YAML ヘッダに params があり、チャンクの中で params$… として使っている",
         if (length(used)) paste0("（", paste0("params$", used, collapse = ", "), "）") else ""),
  if (!length(pnames)) "YAML ヘッダに「params:」と、その下に「  month: \"2025-12-01\"」を加えます。"
  else paste0("setup のチャンクの m <- ymd(\"2025-12-01\") を m <- ymd(params$", pnames[1], ") に書き換えます。"))

# ---- 要約 ----
summary_pat <- "要約|結論|サマリー|[Ss]ummary"
first_h <- if (is.null(q) || !nrow(q$headings)) "" else q$headings$text[1]
r108_item(grepl(summary_pat, first_h, perl = TRUE),
  paste0("最初の見出しが「要約」になっている（いまの最初の見出し: ", if (nzchar(first_h)) first_h else "なし", "）"),
  "setup のチャンクのすぐ下（「## 売上・客数・客単価」より前）に「## 要約」の見出しを書きます。")

sec <- if (is.null(q)) character() else r108_qmd_section(q, summary_pat)
n_inline <- sum(lengths(regmatches(sec, gregexpr("`r [^`]+`", sec))))
r108_item(grepl(summary_pat, first_h, perl = TRUE) && n_inline >= 2,
  paste0("要約の数値を、インラインコード `r …` で2つ以上書いている（いまは ", n_inline, " 個）"),
  "要約の文に、`r round(now$sales / 10000)` のように、バッククォート・r・空白・R の式・バッククォートの形で数値を埋め込みます。")

# ---- レンダリング ----
pkgs <- c("rmarkdown", "knitr")
missing <- pkgs[!vapply(pkgs, function(p) nzchar(system.file(package = p)), logical(1))]
r108_item(length(missing) == 0,
  "Quarto が R のチャンクを実行するためのパッケージ（rmarkdown, knitr）が入っている",
  paste0("コンソールで install.packages(c(", paste0("\"", missing, "\"", collapse = ", "), ")) を実行します。"))

quarto <- r108_find_quarto()
r108_item(!is.null(quarto),
  "Quarto が見つかる",
  "RStudio を最新版にするか、https://quarto.org/docs/get-started/ から Quarto を入れ、RStudio（Positron）を開き直してください。")

rend <- list(ok = FALSE, output = NA_character_, log = "")
if (!is.null(q) && !is.null(quarto)) {
  cat("\n  report.qmd を HTML にレンダリングしています（数十秒かかることがあります）…\n")
  rend <- r108_render(qmd, to = "html")
}
hint_render <- if (!nzchar(rend$log)) "上の ✗ の項目を先に直してください。" else {
  paste0("RStudio の Render ボタン（Positron は Preview）で試し、エラーの行を直してください。",
    if (grepl("not found|could not find|見つけることができません|見つかりません|がありません", rend$log)) "要約のインラインコードは上から順に実行されます。使う関数や変数（library(tidyverse)、m、now）は、要約より上の setup のチャンクで用意しておきます。" else "",
    "Quarto の出力:\n        ", r108_log_hint(rend$log))
}
r108_item(rend$ok, "report.qmd を HTML（report.html）にレンダリングできる", hint_render)

if (rend$ok) {
  h <- tryCatch(r108_read_html(rend$output), error = function(e) NULL)
  r108_item(!is.null(h) && h$n_code == 0,
    paste0("HTML にコードが表示されていない", if (!is.null(h) && h$n_code > 0) paste0("（いまは ", h$n_code, " か所）") else ""),
    "echo: true のチャンクや code-fold の設定があると、コードが HTML に入ります。消してからレンダリングし直します。")
  hd <- if (is.null(h)) NULL else h$headings[!h$headings$title, , drop = FALSE]
  stext <- if (is.null(h)) "" else r108_html_section(h, summary_pat)
  r108_item(!is.null(hd) && nrow(hd) >= 1 && grepl(summary_pat, hd$text[1], perl = TRUE) &&
              grepl("[0-9]", stext) && !grepl("`r ", stext, fixed = TRUE),
    "HTML の冒頭が要約の節で、要約に計算した数値が入っている",
    "インラインコードは `r と式の間に空白を1つ置きます。要約が最初の見出しになっているかも確かめます。")
  r108_item(!is.null(h) && (h$n_img + h$n_widget) >= 1,
    "HTML の中に図がある",
    "図のチャンクの最後の行が ggplot() の図になっているか確かめます。")
}

r108_finish("100", c(120L, 27L, 26L, 18L, 7L, 27L, 26L, 26L, 7L, 108L, 24L, 111L, 28L))
