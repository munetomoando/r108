# ステップ108: 修了課題「自分の問いを立て、分析し、報告する」
# 確かめること（ネットワークにはつながない。git は読むだけで、リポジトリを書き換えない）:
# [報告書] final.qmd があり、題名と自分の名前、format が html（レポート）か dashboard（ダッシュボード）。
#   レポートなら最初の見出しが「要約」（結論）で、「問い」の節がある。
#   モデルを1つ以上推定して表にし（lm・glm・feols など）、図を描くチャンクが3つ以上。
#   setwd() や絶対パスを使わない。HTML にレンダリングでき、HTML に図3つ以上・表1つ以上がある。
# [README] README.md に「問い」「データ」「結論」の見出しと、200字以上の説明がある。
# [Git・GitHub] リポジトリの一番上で、final.qmd と README.md をコミットし、コミットが5つ以上。
#   data/ と .Renviron を .gitignore で除外し、過去のどのコミットにも入っていない。トークンらしい文字列がない。
#   リモートが設定され（URL にトークンがない）、最新のコミットまで push してある。コミットしていない変更がない。

cat("R108 ステップ108「修了課題」の確認を始めます。\n")
cat("作業フォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

qmd <- "final.qmd"
out_name <- "final.html"
known <- c("report.qmd", "dashboard.qmd", "paper.qmd", "mini_thesis.qmd")
others <- setdiff(list.files(".", pattern = "\\.qmd$"), qmd)

# ---- Git の状態は、レンダリングで HTML が書き換わる前に読んでおく ----
git <- r108_git_find()
ver <- if (!is.null(git)) r108_git("--version", git) else list(ok = FALSE, out = "")
git_ok <- !is.null(git) && ver$ok
tl <- if (git_ok) r108_git_toplevel(git) else list(is_repo = FALSE, at_top = FALSE, top = NA_character_)
repo <- git_ok && tl$at_top
if (repo) {
  tracked <- r108_git_tracked(git)
  n_commits <- r108_git_n_commits(git)
  dirty <- r108_git_dirty(git)
  if (!anyNA(dirty)) {
    dfiles <- sub("^.* -> ", "", sub("^.. ", "", dirty))
    dfiles <- gsub("^\"|\"$", "", dfiles)
    # レンダリングの出力（HTML、*_files/、.quarto/）は数えない
    dirty <- dirty[!grepl("\\.html$|_files/|(^|/)\\.quarto/", dfiles)]
  }
}

cat("【報告書】\n")
r108_item(file.exists(qmd),
  "作業フォルダに final.qmd がある",
  if (length(setdiff(others, known))) paste0(paste(setdiff(others, known), collapse = ", "), " はありますが、修了課題の報告書の名前を final.qmd にしてください。")
  else "アプリから雛形 final.qmd をダウンロードし、修了課題のプロジェクトのフォルダ（.Rproj と同じ場所）に置いてください。")

q <- if (file.exists(qmd)) tryCatch(r108_read_qmd(qmd), error = function(e) NULL) else NULL
# コメントの行（# で始まる行）を除いたチャンクのコード
chunk_code <- function(ch) paste(ch$code[!grepl("^\\s*#", ch$code)], collapse = "\n")
chunks <- if (is.null(q)) list() else q$chunks
code <- paste(vapply(chunks, chunk_code, ""), collapse = "\n")

# ---- YAML ヘッダ ----
yaml_str <- function(x) if (is.character(x) && length(x) >= 1) paste(x, collapse = " ") else ""
title <- yaml_str(q$yaml$title)
author <- yaml_str(unlist(q$yaml$author))
r108_item(nzchar(trimws(title)) && !grepl("（題名）|ここに", title) &&
            nzchar(trimws(author)) && !grepl("^\\s*氏名\\s*$", author),
  "YAML ヘッダに題名（title）と自分の名前（author）を書いている",
  "雛形の title: \"（題名）\" と author: \"氏名\" を、自分の報告書の題名と自分の名前に書き換えます。")

fmt <- q$yaml$format
fmt_names <- if (is.list(fmt)) names(fmt) else as.character(fmt)
to <- if ("dashboard" %in% fmt_names) "dashboard" else if ("html" %in% fmt_names) "html" else NA_character_
r108_item(!is.na(to),
  paste0("YAML ヘッダの format が html（レポート）か dashboard（ダッシュボード）",
         if (!is.na(to)) paste0("：", if (to == "html") "レポート" else "ダッシュボード") else ""),
  "YAML ヘッダの format: を html（ステップ100のレポート）か dashboard（ステップ101のダッシュボード）にします。")

# ---- 構成（レポートのときだけ。ダッシュボードは README で問いと結論を確かめる） ----
summary_pat <- "要約|結論|サマリー|[Ss]ummary"
if (identical(to, "html")) {
  first_h <- if (is.null(q) || !nrow(q$headings)) "" else q$headings$text[1]
  has_q <- !is.null(q) && any(grepl("問い", q$headings$text))
  r108_item(grepl(summary_pat, first_h, perl = TRUE) && has_q,
    paste0("最初の見出しが「要約」で、「問い」の見出しがある（いまの最初の見出し: ", if (nzchar(first_h)) first_h else "なし", "）"),
    if (!grepl(summary_pat, first_h, perl = TRUE)) "結論が先です。setup のチャンクのすぐ下に「## 要約」の見出しを置き、問いへの答えを数値入りで2〜3行書きます（ステップ100・107）。"
    else "「## 問い」の見出しを置き、何を明らかにしたいかを1文の疑問文で書きます。")
}

# ---- モデル ----
est_pat <- "\\b(lm|glm|feols|feglm|fepois|lm_robust|plm|ivreg|linear_reg|logistic_reg|decision_tree|rand_forest|randomForest|rpart)\\s*\\("
tab_pat <- "\\b(modelsummary|msummary|etable|tidy|kable|gt|tbl_regression|coeftable|collect_metrics|tt)\\s*\\("
est_used <- unique(gsub("\\s*\\($", "", unlist(regmatches(code, gregexpr(est_pat, code, perl = TRUE)))))
r108_item(length(est_used) >= 1 && grepl(tab_pat, code, perl = TRUE),
  paste0("モデルを1つ以上推定し、結果を表にしている",
         if (length(est_used)) paste0("（", paste0(est_used, "()", collapse = ", "), "）") else ""),
  if (!length(est_used)) "問いに答えるモデルを lm()・glm()・feols() などで推定します（ステップ37〜44、65〜72、93〜99）。"
  else "推定したモデルを modelsummary() や broom::tidy() と knitr::kable() で表にして、報告書に載せます。")

# ---- 図 ----
plot_pat <- "\\b(ggplot|plot|hist|barplot|autoplot|ggplotly|plot_ly|qplot)\\s*\\("
n_fig <- sum(vapply(chunks, function(ch) {
  !identical(ch$options$content, "valuebox") && grepl(plot_pat, chunk_code(ch), perl = TRUE)
}, logical(1)))
r108_item(n_fig >= 3,
  paste0("図を描くチャンクが3つ以上ある（いまは ", n_fig, " 個）"),
  "1つのチャンクに1つの図を描きます。問いに答える根拠になる図を、ラベル（#| label: fig-…）と説明（fig-cap または title）を付けて3つ以上作ります。")

# ---- 再現できる書き方 ----
bad_path <- "(?:[\"'])(?:[A-Za-z]:[/\\\\]|/Users/|/home/|~/|\\\\\\\\)"
uses_setwd <- grepl("\\bsetwd\\s*\\(", code, perl = TRUE)
uses_abs <- grepl(bad_path, code, perl = TRUE)
r108_item(!is.null(q) && !uses_setwd && !uses_abs,
  "setwd() や絶対パス（C:/… や /Users/…）を使わず、プロジェクトのフォルダからの相対パスでデータを読んでいる",
  "read_csv(\"data/ファイル名.csv\") のように、プロジェクトのフォルダからの位置で書きます。setwd() の行は消します（ステップ50・53）。")

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
if (!is.null(q) && !is.null(quarto) && !is.na(to)) {
  cat("\n  final.qmd を HTML にレンダリングしています（1分ほどかかることがあります）…\n")
  rend <- r108_render(qmd, to = to)
}
r108_item(rend$ok,
  "final.qmd を HTML（final.html）にレンダリングできる",
  if (nzchar(rend$log)) paste0("R を再起動（RStudio は「Session」→「Restart R」）してから Render（Positron は Preview）で試し、エラーの行を直してください。Quarto の出力:\n        ", r108_log_hint(rend$log))
  else "上の ✗ の項目を先に直してください。")

if (rend$ok) {
  h <- tryCatch(r108_read_html(rend$output), error = function(e) NULL)
  hf <- if (is.null(h)) 0L else h$n_img + h$n_widget
  ht <- if (is.null(h)) 0L else h$n_table
  r108_item(hf >= 3 && ht >= 1,
    paste0("HTML の中に図が3つ以上と表が1つ以上ある（図 ", hf, " 個、表 ", ht, " 個）"),
    if (hf < 3) "図のチャンクの最後の行が ggplot() の図になっているか確かめます（途中で代入しただけの図は表示されません）。"
    else "モデルの表のチャンクの最後の行が、modelsummary() や knitr::kable() の表になっているか確かめます。")
  if (identical(to, "html")) {
    stext <- if (is.null(h)) "" else r108_html_section(h, summary_pat)
    r108_item(grepl("[0-9]", stext) && !grepl("`r ", stext, fixed = TRUE),
      "HTML の要約に、計算した数値が入っている",
      "要約の数値は `r 式` のインラインコードで埋め込みます（`r と式の間に空白を1つ）。")
  }
}

# ---- README ----
cat("\n【README】\n")
rd <- if (file.exists("README.md")) enc2utf8(readLines("README.md", encoding = "UTF-8", warn = FALSE)) else character()
r108_item(length(rd) > 0, "README.md がある",
  "プロジェクトのフォルダの一番上に README.md を作ります（ステップ105）。")
rh <- trimws(sub("^#{1,6}\\s+", "", rd[grepl("^#{1,6}\\s+\\S", rd)]))
need_h <- c("問い" = "問い", "データ" = "データ", "結論" = "結論|分かったこと|わかったこと|結果|答え")
miss_h <- names(need_h)[!vapply(need_h, function(p) any(grepl(p, rh)), logical(1))]
r108_item(length(rd) > 0 && length(miss_h) == 0,
  "README に「問い」「データ」「結論」の見出しがある",
  paste0("README.md に ", paste0("「## ", miss_h, "」", collapse = ""), " の見出しを足し、その下に書きます。"))
n_chars <- nchar(gsub("[[:space:]　]", "", paste(rd[!grepl("^#{1,6}\\s", rd)], collapse = "")))
r108_item(n_chars >= 200,
  paste0("README の説明が200字以上ある（見出しを除いて ", n_chars, " 字）"),
  "問い（1文の疑問文）、使ったデータと入手方法、分かったこと（数値入り）、報告書の作り方（Render の手順）を書きます。")

# ---- Git・GitHub ----
cat("\n【Git・GitHub】\n")
r108_item(git_ok, paste0("git が使える", if (git_ok) paste0("（", sub("^git version ", "", ver$out[1]), "）") else ""),
  r108_git_install_hint())
if (git_ok) {
  r108_item(tl$at_top, "このフォルダが Git のリポジトリである",
    if (tl$is_repo) paste0("リポジトリの一番上が ", tl$top, " になっています。修了課題のプロジェクトのフォルダで git init します（ステップ104）。")
    else "修了課題のプロジェクトのフォルダで git init を実行します（ステップ104）。")
}

if (!repo) {
  cat("\nリポジトリが見つからないので、Git の確認はここまでです。\n")
  r108_item(FALSE, "コミットが5つ以上ある", "先にリポジトリを作りましょう。")
} else {
  not_tr <- setdiff(c(qmd, "README.md"), tracked)
  r108_item(length(not_tr) == 0, "final.qmd と README.md をコミットしている",
    paste0("git add ", paste(not_tr, collapse = " "), " と git commit で記録します。"))

  r108_item(n_commits >= 5, paste0("コミットが5つ以上ある（", n_commits, "個）"),
    "作業のひとまとまり（データを読む、図を足す、モデルを足す、要約を書く、README を書く など）ごとにコミットします。git log --oneline で数を確かめられます。")

  ign_data <- r108_git_ignored("data/r108_check.csv", git)
  ign_renv <- r108_git_ignored(".Renviron", git)
  r108_item(".gitignore" %in% tracked && ign_data && ign_renv,
    "data/ フォルダと .Renviron を .gitignore で除外し、.gitignore をコミットしている",
    if (!(ign_data && ign_renv)) paste0(".gitignore に ", paste(c(if (!ign_data) "data/", if (!ign_renv) ".Renviron"), collapse = " と "), " の行を足し、コミットします。")
    else "git add .gitignore と git commit で .gitignore もコミットします。")

  hist <- r108_git_history_files(git)
  leaked <- hist[grepl(r108_secret_pattern, hist)]
  r108_item(length(leaked) == 0, "data/ の中のファイルや .Renviron が、どのコミットにも入っていない",
    c(paste0("コミットに入っています: ", paste(utils::head(leaked, 5), collapse = ", ")),
      "まだ push していなければ .git フォルダを消して作り直し、送ってしまったなら本文の「間違えて送ってしまったら」（ステップ105）に沿って対処します。"))

  gg <- r108_git(c("grep", "-I", "-l", "-E", "-e", paste(r108_token_patterns, collapse = "|"), "HEAD", "--"), git)
  hits <- if (gg$ok) sub("^HEAD:", "", gg$out[nzchar(gg$out)]) else character()
  r108_item(gg$status %in% c(0L, 1L) && length(hits) == 0,
    "コミットしたファイルに、トークンや API キーらしい文字列がない",
    if (length(hits)) c(paste0("あやしい文字列があるファイル: ", paste(utils::head(hits, 5), collapse = ", ")),
      "キーは .Renviron に書いて Sys.getenv() で読みます。送ってしまったキーは、発行元のサイトで無効にして作り直します。")
    else paste(gg$out, collapse = " "))

  remotes <- r108_git("remote", git)$out
  remotes <- remotes[nzchar(remotes)]
  remote <- if ("origin" %in% remotes) "origin" else if (length(remotes)) remotes[1] else NA_character_
  url <- if (!is.na(remote)) r108_git(c("remote", "get-url", remote), git)$out[1] else NA_character_
  token_in_url <- !is.na(url) && grepl("^https?://[^/]*@", url)
  url_ok <- !is.na(url) && grepl("^(https://|ssh://|git@)", url) && !token_in_url
  r108_item(url_ok,
    paste0("GitHub のリモートが設定され、URL にトークンが入っていない",
           if (!is.na(url)) paste0("（", remote, " = ", sub("//[^/@]*@", "//***@", url), "）") else ""),
    if (is.na(url)) "GitHub で非公開（Private）のリポジトリを作り、git remote add origin https://github.com/あなたのID/リポジトリ名.git を実行します（ステップ105）。"
    else if (token_in_url) "git remote set-url origin https://github.com/あなたのID/リポジトリ名.git で書き直し、URL に入れたトークンは GitHub で削除（Revoke）します。"
    else "リモートの URL は https://github.com/... の形にします（git remote set-url origin <URL>）。")

  up <- r108_git(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"), git)
  has_up <- up$ok && length(up$out) && nzchar(up$out[1])
  branch <- r108_git(c("rev-parse", "--abbrev-ref", "HEAD"), git)$out[1]
  ahead <- if (has_up) suppressWarnings(as.integer(r108_git(c("rev-list", "--count", "@{u}..HEAD"), git)$out[1])) else NA_integer_
  r108_item(has_up && !is.na(ahead) && ahead == 0,
    paste0("最新のコミットまで GitHub に push してある", if (has_up) paste0("（", branch, " → ", up$out[1], "）") else ""),
    if (!has_up) paste0("git push -u origin ", if (!is.na(branch) && nzchar(branch) && branch != "HEAD") branch else "main", " で送ります。")
    else paste0("まだ送っていないコミットが ", ahead, " 個あります。git push で送ります。"))

  r108_item(!anyNA(dirty) && length(dirty) == 0, "コミットしていない変更がない（check_108.R とレンダリングの出力は除く）",
    c(paste0("git status の結果: ", paste(utils::head(dirty, 5), collapse = " / ")),
      "残す変更は git add と git commit で記録して push し、記録しないファイルは .gitignore に書きます。"))
}

r108_finish("108", c(120L, 27L, 26L, 18L, 7L, 27L, 26L, 18L, 7L, 26L, 19L, 110L, 24L))
