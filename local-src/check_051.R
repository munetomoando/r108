# ステップ51: Quarto で論文を書く
# 確かめること: paper.qmd の YAML ヘッダ（docx 出力）、見出し4つ以上、
# 図（fig-）と表（tbl-）のチャンクとキャプション、Word へのレンダリング。

cat("R108 ステップ51「Quartoで論文を書く」の確認を始めます。\n")
cat("作業フォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

qmd <- "paper.qmd"
others <- setdiff(list.files(".", pattern = "\\.qmd$"), qmd)
r108_item(file.exists(qmd),
  "作業フォルダに paper.qmd がある",
  if (length(others)) paste0(paste(others, collapse = ", "), " はありますが、名前を paper.qmd にしてください。")
  else "アプリから paper.qmd をダウンロードし、プロジェクトのフォルダに置いてください。")

q <- if (file.exists(qmd)) tryCatch(r108_read_qmd(qmd), error = function(e) NULL) else NULL

r108_item(!is.null(q$yaml) && is.character(q$yaml$title) && nzchar(q$yaml$title),
  "YAML ヘッダに title（題名）がある",
  "ファイルの先頭を --- で始め、title: \"題名\" を書いて、--- で閉じます。")

fmt <- q$yaml$format
fmt_names <- if (is.list(fmt)) names(fmt) else as.character(fmt)
r108_item("docx" %in% fmt_names,
  "YAML ヘッダの format に docx（Word）がある",
  "YAML ヘッダに format: docx と書きます（ほかの形式と並べるときは format: の下に docx: default）。")

r108_item(file.exists(file.path("data", "pref_panel.csv")) &&
            any(grepl("pref_panel\\.csv", unlist(lapply(q$chunks, `[[`, "code")))),
  "data/pref_panel.csv があり、チャンクの中で読み込んでいる",
  "アプリから pref_panel.csv をダウンロードして data フォルダに置き、read_csv(\"data/pref_panel.csv\") で読みます。")

nh <- if (is.null(q)) 0L else nrow(q$headings)
r108_item(nh >= 4,
  paste0("見出し（# や ## で始まる行）が4つ以上ある（いまは ", nh, " 個）"),
  "「## はじめに」「## データ」「## 結果」「## おわりに」のように、行の先頭に ## と空白を置きます。チャンクの中の # は数えません。")

has_cap <- function(prefix, cap) {
  for (ch in q$chunks) {
    lab <- ch$options$label
    if (!is.null(lab) && startsWith(lab, prefix) && !is.null(ch$options[[cap]]) && nzchar(ch$options[[cap]])) return(TRUE)
  }
  # 本文の ![キャプション](画像){#fig-...} や : キャプション {#tbl-...}
  any(grepl(paste0("\\{#", prefix), q$body))
}
caption_of <- function(prefix, cap) {
  for (ch in q$chunks) {
    lab <- ch$options$label
    if (!is.null(lab) && startsWith(lab, prefix) && !is.null(ch$options[[cap]])) return(ch$options[[cap]])
  }
  NA_character_
}

r108_item(!is.null(q) && has_cap("fig-", "fig-cap"),
  "図のチャンクがあり、ラベルが fig- で始まり、fig-cap（キャプション）がある",
  "図を描くチャンクの先頭に #| label: fig-scatter と #| fig-cap: \"図の説明\" を書きます。")

r108_item(!is.null(q) && has_cap("tbl-", "tbl-cap"),
  "表のチャンクがあり、ラベルが tbl- で始まり、tbl-cap（キャプション）がある",
  "表を作るチャンクの先頭に #| label: tbl-year と #| tbl-cap: \"表の説明\" を書き、knitr::kable() で表にします。")

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
  cat("\n  paper.qmd を Word（docx）にレンダリングしています（数十秒かかることがあります）…\n")
  rend <- r108_render(qmd, to = "docx")
}
r108_item(rend$ok,
  "paper.qmd を Word（docx）にレンダリングできる",
  if (nzchar(rend$log)) paste0("RStudio の Render ボタン（Positron は Preview）で試し、エラーの行を直してください。Quarto の出力:\n        ", r108_log_hint(rend$log))
  else "上の ✗ の項目を先に直してください。")

if (rend$ok) {
  files <- r108_docx_files(rend$output)
  txt <- tryCatch(r108_docx_text(rend$output), error = function(e) "")
  fig_cap <- caption_of("fig-", "fig-cap")
  tbl_cap <- caption_of("tbl-", "tbl-cap")
  r108_item(any(grepl("^word/media/", files)) && (is.na(fig_cap) || grepl(fig_cap, txt, fixed = TRUE)),
    "Word の中に図とそのキャプションがある",
    "図のチャンクで ggplot() の図を表示しているか（最後の行が図になっているか）確かめてください。")
  r108_item(!is.na(tbl_cap) && grepl(tbl_cap, txt, fixed = TRUE) && grepl("<w:tbl>", r108_docx_text(rend$output, xml = TRUE), fixed = TRUE),
    "Word の中に表とそのキャプションがある",
    "表のチャンクの最後の行で knitr::kable() の結果を表示しているか確かめてください。")
}

r108_finish("051", c(120L, 27L, 26L, 18L, 7L, 26L, 31L, 27L, 7L, 104L, 24L, 110L, 19L))
