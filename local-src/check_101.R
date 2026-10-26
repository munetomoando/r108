# ステップ101: Quarto ダッシュボード
# 確かめること: dashboard.qmd が ec_orders・ec_products を読み、format: dashboard で、
# 数値カード（valuebox）3つ以上と図2つ以上を、見出しで分けた2つ以上の行（または列）に並べていること。
# ダッシュボード（HTML）にレンダリングでき、HTML の中に数値カード3つ以上と図2つ以上があること。

cat("R108 ステップ101「Quartoダッシュボード」の確認を始めます。\n")
cat("作業フォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

qmd <- "dashboard.qmd"
others <- setdiff(list.files(".", pattern = "\\.qmd$"), c(qmd, "paper.qmd", "mini_thesis.qmd", "report.qmd"))
r108_item(file.exists(qmd),
  "作業フォルダに dashboard.qmd がある",
  if (length(others)) paste0(paste(others, collapse = ", "), " はありますが、ダッシュボードの名前を dashboard.qmd にしてください。")
  else "アプリから雛形 dashboard.qmd をダウンロードし、プロジェクトのフォルダに置いてください。")

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
r108_item("dashboard" %in% fmt_names,
  "YAML ヘッダが format: dashboard になっている",
  "YAML ヘッダの format: を dashboard にします（html のままだと普通の文書になります）。")

# ---- 数値カード・図・配置 ----
vb_chunks <- if (is.null(q)) 0L else sum(vapply(q$chunks, function(ch) identical(ch$options$content, "valuebox"), logical(1)))
vb_divs <- if (is.null(q)) 0L else sum(grepl("^\\s*:{3,}\\s*\\{[^}]*\\.valuebox", q$body))
n_vb <- vb_chunks + vb_divs
r108_item(n_vb >= 3,
  paste0("数値カード（#| content: valuebox のチャンク）が3つ以上ある（いまは ", n_vb, " 個）"),
  "雛形の「売上（万円）」のチャンクをまねて、#| content: valuebox と #| title: \"客数（人）\" を書き、list(icon = …, color = …, value = …) を返すチャンクを加えます。")

plot_pat <- "\\b(ggplot|plot|hist|barplot|autoplot|ggplotly|plot_ly)\\s*\\("
n_fig <- if (is.null(q)) 0L else sum(vapply(q$chunks, function(ch) {
  !identical(ch$options$content, "valuebox") && grepl(plot_pat, paste(ch$code, collapse = "\n"))
}, logical(1)))
r108_item(n_fig >= 2,
  paste0("図を描くチャンクが2つ以上ある（いまは ", n_fig, " 個）"),
  "雛形の「月別の売上」のチャンクをまねて、#| title: \"…\" を付けた ggplot() の図のチャンクを加えます。")

n_rows <- if (is.null(q)) 0L else sum(q$headings$level == 2)
r108_item(n_rows >= 2,
  paste0("見出し（## Row など）で2つ以上の行（または列）に分けている（いまは ", n_rows, " 個）"),
  "「## Row {height=\"25%\"}」のように、行の先頭に ## と空白を置いた見出しで、数値カードの行と図の行を分けます。")

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
if (!is.null(q) && !is.null(quarto) && "dashboard" %in% fmt_names) {
  cat("\n  dashboard.qmd をダッシュボード（HTML）にレンダリングしています（数十秒かかることがあります）…\n")
  rend <- r108_render(qmd, to = "dashboard")
}
r108_item(rend$ok,
  "dashboard.qmd をダッシュボード（dashboard.html）にレンダリングできる",
  if (nzchar(rend$log)) paste0("RStudio の Render ボタン（Positron は Preview）で試し、エラーの行を直してください。Quarto の出力:\n        ", r108_log_hint(rend$log))
  else "上の ✗ の項目を先に直してください。")

if (rend$ok) {
  h <- tryCatch(r108_read_html(rend$output), error = function(e) NULL)
  hv <- if (is.null(h)) 0L else h$n_valuebox
  hf <- if (is.null(h)) 0L else h$n_img + h$n_widget
  r108_item(hv >= 3,
    paste0("ダッシュボードに数値カードが3つ以上ある（いまは ", hv, " 個）"),
    "valuebox のチャンクが list(value = …) を返しているか、#| content: valuebox の綴りを確かめます。")
  r108_item(hf >= 2,
    paste0("ダッシュボードに図が2つ以上ある（いまは ", hf, " 個）"),
    "図のチャンクの最後の行が ggplot() の図になっているか確かめます。")
}

r108_finish("101", c(120L, 27L, 26L, 18L, 7L, 27L, 26L, 27L, 7L, 24L, 107L, 108L, 25L))
