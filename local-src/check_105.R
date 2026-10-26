# ステップ105「GitHubで共有する」の確認（ネットワークにはつながない。手元の記録だけを見る）
# 1. git が使え、このフォルダが Git のリポジトリ（の一番上）である
# 2. README.md があり、コミットされている。見出しと説明（空白を除いて100字以上）がある
# 3. リモート（origin）が設定され、URL にトークンやパスワードが書き込まれていない
# 4. push 済み：いまのブランチに追跡ブランチ（origin/main など）があり、最新のコミットまで送ってある
# 5. data/ の中のファイルや .Renviron が、過去のどのコミットにも入っていない
# 6. 追跡しているファイルに、トークンや API キーらしい文字列がない
# git は読むだけ（--no-optional-locks）。学生のリポジトリを書き換えない。

# Git の確認に使う関数（r108_git_find など）は _common.R にある（ステップ104・105・108 で共通）。

# ---- ここからステップ105の確認 ----

cat("ステップ105「GitHubで共有する」の確認\n")
cat("プロジェクトのフォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

git <- r108_git_find()
ver <- if (!is.null(git)) r108_git("--version", git) else list(ok = FALSE, out = "")
git_ok <- !is.null(git) && ver$ok
r108_item(git_ok, paste0("git が使える", if (git_ok) paste0("（", sub("^git version ", "", ver$out[1]), "）") else ""),
  r108_git_install_hint())

tl <- if (git_ok) r108_git_toplevel(git) else list(is_repo = FALSE, at_top = FALSE)
if (git_ok) {
  r108_item(tl$at_top, "このフォルダが Git のリポジトリである",
    if (tl$is_repo) paste0("リポジトリの一番上が ", tl$top, " になっています。ステップ104で作ったプロジェクトのフォルダで実行しましょう。")
    else "ステップ104で Git のリポジトリにしたプロジェクトのフォルダに check_105.R を置いて実行しましょう。")
}

if (!tl$is_repo) {
  cat("\nリポジトリが見つからないので、ここで確認を終えます。\n")
} else {
  tracked <- r108_git_tracked(git)

  # ---- 2. README ----
  readme <- tracked[grepl("^README\\.(md|Rmd|qmd)$", tracked, ignore.case = TRUE)]
  r108_item(length(readme) >= 1, "README.md があり、コミットされている",
    if (file.exists("README.md")) "git add README.md と git commit で README.md をコミットしましょう。"
    else "プロジェクトのフォルダの一番上に README.md を作り、何のための分析・アプリか、動かし方、データの入手方法を書きましょう。")
  rd <- if (length(readme) && file.exists(readme[1])) enc2utf8(readLines(readme[1], encoding = "UTF-8", warn = FALSE)) else character()
  has_heading <- any(grepl("^#{1,6}\\s+\\S", rd))
  n_chars <- nchar(gsub("[[:space:]]", "", paste(rd[!grepl("^#{1,6}\\s", rd)], collapse = "")))
  r108_item(has_heading && n_chars >= 100,
    paste0("README に見出しと説明がある（見出しを除いて ", n_chars, " 字）"),
    "README.md の1行目に「# アプリの名前」の見出しを書き、その下に、何ができるか・動かし方・データを含めていない理由などを100字以上で書きましょう。")

  # ---- 3. リモート ----
  remotes <- r108_git("remote", git)$out
  remotes <- remotes[nzchar(remotes)]
  remote <- if ("origin" %in% remotes) "origin" else if (length(remotes)) remotes[1] else NA_character_
  url <- if (!is.na(remote)) r108_git(c("remote", "get-url", remote), git)$out[1] else NA_character_
  url_ok <- !is.na(url) && grepl("^(https://|ssh://|git@)", url)
  r108_item(url_ok, paste0("リモートが設定されている", if (!is.na(url)) paste0("（", remote, " = ", sub("//[^/@]*@", "//***@", url), "）") else ""),
    if (is.na(url)) "GitHub でリポジトリを作り、git remote add origin https://github.com/あなたのID/sora_app.git を実行しましょう。"
    else "リモートの URL は https://github.com/... の形にしましょう（git remote set-url origin <URL>）。")
  token_in_url <- !is.na(url) && grepl("^https?://[^/]*@", url)
  r108_item(!is.na(url) && !token_in_url, "リモートの URL にトークンやパスワードが書き込まれていない",
    if (token_in_url) "URL に「名前:トークン@」が入っていると、トークンがパソコンの設定ファイルに平文で残ります。git remote set-url origin https://github.com/あなたのID/sora_app.git で書き直し、そのトークンは GitHub で削除（Revoke）しましょう。"
    else "先にリモートを設定しましょう。")

  # ---- 4. push 済み ----
  up <- r108_git(c("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"), git)
  has_up <- up$ok && length(up$out) && nzchar(up$out[1])
  branch <- r108_git(c("rev-parse", "--abbrev-ref", "HEAD"), git)$out[1]
  r108_item(has_up, paste0("GitHub に push してある", if (has_up) paste0("（", branch, " → ", up$out[1], "）") else ""),
    paste0("git push -u origin ", if (!is.na(branch) && nzchar(branch) && branch != "HEAD") branch else "main",
           " で送りましょう。-u を付けると、次からは git push だけで送れます。"))
  ahead <- if (has_up) suppressWarnings(as.integer(r108_git(c("rev-list", "--count", "@{u}..HEAD"), git)$out[1])) else NA_integer_
  r108_item(has_up && !is.na(ahead) && ahead == 0,
    "最新のコミットまで push してある",
    if (has_up) paste0("まだ送っていないコミットが ", ahead, " 個あります。git push で送りましょう。")
    else "先に push しましょう。")

  # ---- 5. 機密ファイル ----
  hist <- r108_git_history_files(git)
  leaked <- hist[grepl(r108_secret_pattern, hist)]
  r108_item(length(leaked) == 0, "data/ の中のファイルや .Renviron が、どのコミットにも入っていない",
    c(paste0("コミットに入っています: ", paste(utils::head(leaked, 5), collapse = ", ")),
      "GitHub に送ったものは、ファイルを消しても履歴から読めます。リポジトリを Private のまま、本文の「間違えて送ってしまったら」に沿って対処しましょう。"))

  # ---- 6. トークンらしい文字列 ----
  pats <- r108_token_patterns
  gg <- r108_git(c("grep", "-I", "-l", "-E", "-e", paste(pats, collapse = "|"), "HEAD", "--"), git)
  hits <- if (gg$ok) sub("^HEAD:", "", gg$out[nzchar(gg$out)]) else character()
  r108_item(gg$status %in% c(0L, 1L) && length(hits) == 0,
    "コミットしたファイルに、トークンや API キーらしい文字列がない",
    if (length(hits)) c(paste0("あやしい文字列があるファイル: ", paste(utils::head(hits, 5), collapse = ", ")),
      "キーは .Renviron に書いて Sys.getenv() で読みます。送ってしまったキーは、発行元のサイトで無効にして作り直しましょう。")
    else paste(gg$out, collapse = " "))
}

r108_finish(105, c(120L, 27L, 26L, 18L, 7L, 27L, 26L, 31L, 7L, 108L, 19L, 29L, 27L))
