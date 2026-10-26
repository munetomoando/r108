# ステップ52: 参考文献と相互参照
# 確かめること: paper.qmd が references.bib を指定し、3件以上の文献を @key で引用していること、
# @fig- と @tbl- の相互参照があり、Word に出力したとき引用・相互参照・文献リストが解決していること。

cat("R108 ステップ52「参考文献と相互参照」の確認を始めます。\n")
cat("作業フォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

qmd <- "paper.qmd"
r108_item(file.exists(qmd),
  "作業フォルダに paper.qmd がある",
  "ステップ51で作った paper.qmd を、このプロジェクトのフォルダに置いてください。")
q <- if (file.exists(qmd)) tryCatch(r108_read_qmd(qmd), error = function(e) NULL) else NULL

bibs <- as.character(unlist(q$yaml$bibliography))
r108_item(length(bibs) >= 1 && all(file.exists(bibs)),
  paste0("YAML ヘッダの bibliography に文献ファイルを指定し、そのファイルがある",
         if (length(bibs)) paste0("（", paste(bibs, collapse = ", "), "）") else ""),
  if (length(bibs)) paste0(paste(bibs[!file.exists(bibs)], collapse = ", "), " が見つかりません。paper.qmd と同じフォルダに置いてください。")
  else "YAML ヘッダに bibliography: references.bib の1行を加えます。")

keys <- unique(unlist(lapply(bibs[file.exists(bibs)], function(b) tryCatch(r108_read_bib(b), error = function(e) character()))))
r108_item(length(keys) >= 3,
  paste0("文献ファイルに3件以上の文献がある（いまは ", length(keys), " 件）"),
  "references.bib に @article{キー, ...} や @book{キー, ...} の形で文献を加えます。")

cites <- if (is.null(q)) character() else q$cites
used <- intersect(cites, keys)
r108_item(length(used) >= 3,
  paste0("本文で3件以上の文献を @キー で引用している（いまは ", length(used), " 件）"),
  "本文に [@card1994] や @neumark2008 のように、references.bib のキーを書いて引用します。")

unknown <- setdiff(cites, keys)
r108_item(length(cites) >= 1 && length(unknown) == 0,
  "引用したキーがすべて文献ファイルにある",
  if (length(unknown)) paste0("文献ファイルにないキー: ", paste(unknown, collapse = ", "),
    "。綴りを references.bib と同じにするか、文献を加えてください（メールアドレス以外の @ は引用とみなされます）。"))

xr <- if (is.null(q)) character() else q$crossrefs
r108_item(any(startsWith(xr, "fig-")) && any(startsWith(xr, "tbl-")),
  "本文で図を @fig-…、表を @tbl-… で参照している",
  "本文に「@fig-scatter に示すように」「@tbl-year は」のように、チャンクのラベルを @ を付けて書きます。")

badx <- setdiff(xr[grepl("^(fig|tbl)-", xr)], if (is.null(q)) character() else q$labels)
r108_item(length(xr) >= 1 && length(badx) == 0,
  "参照している図表のラベルが qmd の中にある",
  if (length(badx)) paste0("見つからないラベル: ", paste(badx, collapse = ", "),
    "。チャンクの #| label: と同じ綴りにしてください。"))

quarto <- r108_find_quarto()
r108_item(!is.null(quarto),
  "Quarto が見つかる",
  "RStudio を最新版にするか、https://quarto.org/docs/get-started/ から Quarto を入れ、RStudio（Positron）を開き直してください。")

rend <- list(ok = FALSE, output = NA_character_, log = "")
if (!is.null(q) && !is.null(quarto)) {
  cat("\n  paper.qmd を Word（docx）にレンダリングしています（数十秒かかることがあります）…\n")
  rend <- r108_render(qmd, to = "docx")
}
r108_item(rend$ok,
  "paper.qmd を Word（docx）にレンダリングできる",
  if (nzchar(rend$log)) paste0("RStudio の Render ボタン（Positron は Preview）で試し、エラーの行を直してください。Quarto の出力:\n        ", r108_log_hint(rend$log))
  else "上の ✗ の項目を先に直してください。")

if (rend$ok) {
  txt <- tryCatch(r108_docx_text(rend$output), error = function(e) "")
  xml <- tryCatch(r108_docx_text(rend$output, xml = TRUE), error = function(e) "")
  unres_x <- unique(unlist(regmatches(txt, gregexpr("\\?@[A-Za-z0-9_:-]+", txt))))
  r108_item(nzchar(txt) && length(unres_x) == 0,
    "Word の中で図表の相互参照が解決している（「?@fig-…」が残っていない）",
    paste0("解決していない参照: ", paste(unres_x, collapse = ", "),
      "。ラベルが fig- や tbl- で始まり、キャプション（fig-cap・tbl-cap）があるか確かめてください。"))
  unres_c <- cites[vapply(cites, function(k) grepl(paste0(k, "?"), txt, fixed = TRUE), logical(1))]
  r108_item(nzchar(txt) && length(unres_c) == 0,
    "Word の中で文献の引用が解決している（「キー?」が残っていない）",
    paste0("解決していない引用: ", paste(unres_c, collapse = ", "), "。キーの綴りを references.bib と比べてください。"))
  nbib <- length(gregexpr("w:val=\"Bibliography\"", xml, fixed = TRUE)[[1]])
  if (!grepl("w:val=\"Bibliography\"", xml, fixed = TRUE)) nbib <- 0L
  r108_item(nbib >= 3,
    paste0("Word の末尾に文献リストが3件以上ある（いまは ", nbib, " 件）"),
    "引用が3件以上あれば、文献リストは自動で作られます。::: {#refs} の位置を決めているなら、::: を閉じ忘れていないか確かめてください。")
}

r108_finish("052", c(120L, 27L, 26L, 18L, 7L, 26L, 31L, 24L, 7L, 30L, 105L, 18L, 111L))
