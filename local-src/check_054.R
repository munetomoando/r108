# ステップ54: 総合演習・第II段階の関門「ミニ卒論」
# 確かめること: mini_thesis.qmd に、問い・データ・方法・結果・結論の5つの見出しがこの順にあり、
# 本文がおおむね3000字以上（目安4000字）、回帰表1つ以上、図2つ以上、文献3件以上を引用し、
# Word（docx）にレンダリングでき、図表の相互参照と引用が解決していること。
#
# 本文の字数の数え方: YAML ヘッダ、コードチャンク、<!-- --> のコメント、見出しの行、::: の行を除き、
# 空白（全角の空白・改行を含む）を除いた文字数。句読点・数字・英字は1文字ずつ数える。

cat("R108 ステップ54「ミニ卒論」（第II段階の関門）の確認を始めます。\n")
cat("作業フォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

min_chars <- 3000L
qmd <- "mini_thesis.qmd"
others <- setdiff(list.files(".", pattern = "\\.qmd$"), c(qmd, "paper.qmd"))
r108_item(file.exists(qmd),
  "作業フォルダに mini_thesis.qmd がある",
  if (length(others)) paste0(paste(others, collapse = ", "), " はありますが、ミニ卒論の名前を mini_thesis.qmd にしてください。")
  else "アプリから雛形 mini_thesis.qmd をダウンロードし、プロジェクトのフォルダに置いてください。")

# <!-- --> のメモ（HTML コメント）は Word に出ないので、行数を保ったまま空にしてから読む。
# 書き換えた内容は一時ファイル（tempdir の中）に置き、学生のファイルには触れない。
read_without_comments <- function(path) {
  x <- enc2utf8(readLines(path, encoding = "UTF-8", warn = FALSE))
  txt <- paste(x, collapse = "\n")
  m <- gregexpr("(?s)<!--.*?-->", txt, perl = TRUE)
  regmatches(txt, m) <- lapply(regmatches(txt, m), function(s) gsub("[^\n]", "", s))
  tmp <- tempfile(fileext = ".qmd")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(txt, tmp, useBytes = TRUE)
  r108_read_qmd(tmp)
}
q <- if (file.exists(qmd)) tryCatch(read_without_comments(qmd), error = function(e) NULL) else NULL

# ---- YAML ヘッダ ----
yaml_str <- function(x) if (is.character(x) && length(x) >= 1) paste(x, collapse = " ") else ""
title <- yaml_str(q$yaml$title)
author <- yaml_str(unlist(q$yaml$author))
r108_item(nzchar(trimws(title)) && !grepl("（題名）|ここに", title) &&
            nzchar(trimws(author)) && !grepl("^\\s*氏名\\s*$", author),
  "YAML ヘッダに題名（title）と自分の名前（author）を書いている",
  "雛形の title: と author: を、自分の論文の題名と自分の名前に書き換えます。")

fmt <- q$yaml$format
fmt_names <- if (is.list(fmt)) names(fmt) else as.character(fmt)
r108_item("docx" %in% fmt_names,
  "YAML ヘッダの format に docx（Word）がある",
  "YAML ヘッダに format: docx と書きます（ほかの形式と並べるときは format: の下に docx: default）。")

# ---- 5つの見出し ----
parts <- list(
  "問い" = "問い|はじめに|序論|研究課題",
  "データ" = "データ",
  "方法" = "方法|手法|モデル|分析の枠組み|推定式",
  "結果" = "結果",
  "結論" = "結論|おわりに|まとめ|むすび"
)
heads <- if (is.null(q)) character() else q$headings$text
pos <- vapply(parts, function(p) { w <- grep(p, heads); if (length(w)) w[1] else NA_integer_ }, 1L)
missing_parts <- names(parts)[is.na(pos)]
in_order <- !anyNA(pos) && !is.unsorted(pos, strictly = TRUE)
r108_item(length(missing_parts) == 0 && in_order,
  "「問い・データ・方法・結果・結論」の5つの見出しが、この順にある",
  if (length(missing_parts)) paste0("見つからない見出し: ", paste(missing_parts, collapse = "・"),
    "。「## 問い」のように、行の先頭に ## と空白を置いて書きます（「## はじめに」「## おわりに」も認めます）。")
  else "見出しの順番を「問い → データ → 方法 → 結果 → 結論」にそろえます。")

# ---- 本文の字数 ----
count_chars <- function(q) {
  if (is.null(q)) return(0L)
  b <- q$body
  b[q$headings$line] <- ""
  b <- b[!grepl("^\\s*:::", b)]
  txt <- paste(b, collapse = "\n")
  txt <- gsub("[[:space:]　]", "", txt, perl = TRUE)
  nchar(txt, type = "chars")
}
nchar_body <- count_chars(q)
cat("  （本文の字数: ", format(nchar_body, big.mark = ","), " 字。YAML・コードチャンク・コメント・見出し・空白を除いて数えています）\n", sep = "")
r108_item(nchar_body >= min_chars,
  paste0("本文がおおむね3,000字以上ある（目安は4,000字。いまは ", format(nchar_body, big.mark = ","), " 字）"),
  "問い・データ・方法・結果・結論のそれぞれを、自分の言葉で書き足します。雛形の <!-- --> の中の説明は字数に数えません。")

# ---- 回帰表 ----
chunk_code <- function(ch) paste(ch$code, collapse = "\n")
all_code <- if (is.null(q)) "" else paste(vapply(q$chunks, chunk_code, ""), collapse = "\n")
table_funs <- "\\b(modelsummary|msummary|etable|tbl_regression|stargazer|huxreg|export_summs)\\s*\\("
est_funs <- "\\b(lm|glm|feols|feglm|fepois|lm_robust|plm|ivreg|feols\\.fit)\\s*\\("
reg_tables <- if (is.null(q)) character() else unlist(lapply(q$chunks, function(ch) {
  lab <- ch$options$label
  if (!is.null(lab) && startsWith(lab, "tbl-") && grepl(table_funs, chunk_code(ch))) lab else NULL
}))
r108_item(length(reg_tables) >= 1 && grepl(est_funs, all_code),
  paste0("回帰表が1つ以上ある（ラベルが tbl- で始まるチャンクで modelsummary() などを使う）",
         if (length(reg_tables)) paste0("：", paste(reg_tables, collapse = ", ")) else ""),
  "lm() や feols() で推定し、#| label: tbl-reg と #| tbl-cap: \"…\" を付けたチャンクで、modelsummary() の結果を表にします（雛形の tbl-reg のチャンクが見本です）。")

# ---- 図 ----
fig_labels <- if (is.null(q)) character() else unlist(lapply(q$chunks, function(ch) {
  lab <- ch$options$label
  if (!is.null(lab) && startsWith(lab, "fig-") && !is.null(ch$options[["fig-cap"]]) && nzchar(ch$options[["fig-cap"]])) lab else NULL
}))
fig_labels <- unique(c(fig_labels, if (is.null(q)) character() else q$labels[startsWith(q$labels, "fig-")]))
r108_item(length(fig_labels) >= 2,
  paste0("図が2つ以上ある（ラベルが fig- で始まり、fig-cap がある。いまは ", length(fig_labels), " 個）"),
  "図を描くチャンクの先頭に #| label: fig-… と #| fig-cap: \"図の説明\" を書きます。2つ目の図も同じように作ります。")

# ---- 文献 ----
bibs <- as.character(unlist(q$yaml$bibliography))
keys <- unique(unlist(lapply(bibs[file.exists(bibs)], function(b) tryCatch(r108_read_bib(b), error = function(e) character()))))
cites <- if (is.null(q)) character() else q$cites
used <- intersect(cites, keys)
unknown <- setdiff(cites, keys)
r108_item(length(bibs) >= 1 && all(file.exists(bibs)) && length(used) >= 3 && length(unknown) == 0,
  paste0("文献を3件以上、@キー で引用している（いまは ", length(used), " 件）"),
  if (!length(bibs)) "YAML ヘッダに bibliography: references.bib を書き、references.bib を同じフォルダに置きます。"
  else if (!all(file.exists(bibs))) paste0(paste(bibs[!file.exists(bibs)], collapse = ", "), " が見つかりません。mini_thesis.qmd と同じフォルダに置きます。")
  else if (length(unknown)) paste0("文献ファイルにないキー: ", paste(unknown, collapse = ", "), "。綴りを references.bib と同じにするか、文献を加えます。")
  else "本文に @card1994 や [@neumark2008] のように、references.bib のキーを書いて3件以上引用します。")

# ---- 相互参照 ----
xr <- if (is.null(q)) character() else q$crossrefs
badx <- setdiff(xr[grepl("^(fig|tbl)-", xr)], if (is.null(q)) character() else q$labels)
r108_item(any(startsWith(xr, "fig-")) && any(startsWith(xr, "tbl-")) && length(badx) == 0,
  "本文で図を @fig-…、表を @tbl-… で参照している",
  if (length(badx)) paste0("見つからないラベル: ", paste(badx, collapse = ", "), "。チャンクの #| label: と同じ綴りにします。")
  else "本文に「@fig-scatter に示すように」「推定結果を @tbl-reg に示す」のように書きます。")

# ---- レンダリング ----
quarto <- r108_find_quarto()
r108_item(!is.null(quarto),
  "Quarto が見つかる",
  "RStudio を最新版にするか、https://quarto.org/docs/get-started/ から Quarto を入れ、RStudio（Positron）を開き直してください。")

rend <- list(ok = FALSE, output = NA_character_, log = "")
if (!is.null(q) && !is.null(quarto)) {
  cat("\n  mini_thesis.qmd を Word（docx）にレンダリングしています（1分ほどかかることがあります）…\n")
  rend <- r108_render(qmd, to = "docx")
}
r108_item(rend$ok,
  "mini_thesis.qmd を Word（docx）にレンダリングできる",
  if (nzchar(rend$log)) paste0("RStudio の Render ボタン（Positron は Preview）で試し、エラーの行を直してください。Quarto の出力:\n        ", r108_log_hint(rend$log))
  else "上の ✗ の項目を先に直してください。")

if (rend$ok) {
  files <- r108_docx_files(rend$output)
  txt <- tryCatch(r108_docx_text(rend$output), error = function(e) "")
  xml <- tryCatch(r108_docx_text(rend$output, xml = TRUE), error = function(e) "")
  n_img <- sum(grepl("^word/media/", files))
  r108_item(n_img >= 2 && grepl("<w:tbl>", xml, fixed = TRUE),
    paste0("Word の中に図が2つ以上と表がある（図 ", n_img, " 個）"),
    "図のチャンクの最後の行が ggplot() の図に、表のチャンクの最後の行が knitr::kable() などの表になっているか確かめます。")
  unres_x <- unique(unlist(regmatches(txt, gregexpr("\\?@[A-Za-z0-9_:-]+", txt))))
  unres_c <- cites[vapply(cites, function(k) grepl(paste0(k, "?"), txt, fixed = TRUE), logical(1))]
  r108_item(nzchar(txt) && length(unres_x) == 0 && length(unres_c) == 0,
    "Word の中で図表の参照と文献の引用がすべて解決している",
    paste0("解決していないもの: ", paste(c(unres_x, unres_c), collapse = ", "),
      "。ラベルやキーの綴りを確かめます。"))
}

r108_finish("054", c(120L, 27L, 26L, 18L, 7L, 26L, 31L, 30L, 7L, 19L, 107L, 31L, 29L))
