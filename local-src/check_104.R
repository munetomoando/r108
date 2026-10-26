# ステップ104「Gitで履歴を残す」の確認
# 1. git が使える
# 2. user.name と user.email が設定されている
# 3. このフォルダが Git のリポジトリ（の一番上）である
# 4. コミットが3つ以上ある
# 5. .gitignore があり、コミットされている
# 6. data/ フォルダと .Renviron が .gitignore で除外されている
# 7. data/ の中のファイルや .Renviron が、過去のどのコミットにも入っていない
# 8. RStudio の作業用ファイル（.Rproj.user/・.Rhistory・.RData）がコミットされていない
# 9. コミットしていない変更がない（check_1XX.R は除く）
# git は読むだけ（--no-optional-locks）。学生のリポジトリを書き換えない。

# Git の確認に使う関数（r108_git_find など）は _common.R にある（ステップ104・105・108 で共通）。

# ---- ここからステップ104の確認 ----

cat("ステップ104「Gitで履歴を残す」の確認\n")
cat("プロジェクトのフォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

git <- r108_git_find()
ver <- if (!is.null(git)) r108_git("--version", git) else list(ok = FALSE, out = "")
git_ok <- !is.null(git) && ver$ok
r108_item(git_ok, paste0("git が使える", if (git_ok) paste0("（", sub("^git version ", "", ver$out[1]), "）") else ""),
  r108_git_install_hint())

if (!git_ok) {
  cat("\ngit が見つからないので、ここで確認を終えます。\n")
} else {
  # ---- 2. ユーザー名とメールアドレス ----
  uname <- r108_git(c("config", "--get", "user.name"), git)
  umail <- r108_git(c("config", "--get", "user.email"), git)
  r108_item(uname$ok && nzchar(uname$out[1]) && umail$ok && grepl("@", umail$out[1]),
    "user.name と user.email が設定されている",
    "ターミナルで git config --global user.name \"Taro Sorayama\" と git config --global user.email \"you@example.com\" を実行しましょう（名前とメールは自分のものに）。")

  # ---- 3. リポジトリ ----
  tl <- r108_git_toplevel(git)
  r108_item(tl$at_top, "このフォルダが Git のリポジトリである",
    if (tl$is_repo) paste0("リポジトリの一番上が ", tl$top, " になっています。上のフォルダで誤って git init していないか確かめ、",
                           "このプロジェクトのフォルダでリポジトリを作りましょう。")
    else "プロジェクトのフォルダで git init を実行するか、RStudio の「Tools」→「Version Control」→「Project Setup...」で Git を選びましょう。")

  if (tl$is_repo) {
    # ---- 4. コミット数 ----
    n <- r108_git_n_commits(git)
    r108_item(n >= 3, paste0("コミットが3つ以上ある（", n, "個）"),
      "変更をひとまとまりごとに git add と git commit -m \"説明\" で記録しましょう。git log --oneline で数を確かめられます。")

    tracked <- r108_git_tracked(git)
    # ---- 5. .gitignore ----
    r108_item(".gitignore" %in% tracked, ".gitignore があり、コミットされている",
      if (file.exists(".gitignore")) "git add .gitignore と git commit で .gitignore もコミットしましょう。"
      else "プロジェクトのフォルダに .gitignore を作り、除外するファイルを1行に1つずつ書きましょう。")

    # ---- 6. data/ と .Renviron を除外 ----
    ign_data <- r108_git_ignored("data/r108_check.csv", git)
    ign_renv <- r108_git_ignored(".Renviron", git)
    r108_item(ign_data && ign_renv, "data/ フォルダと .Renviron が .gitignore で除外されている",
      paste0(".gitignore に ", paste(c(if (!ign_data) "data/", if (!ign_renv) ".Renviron"), collapse = " と "),
             " の行を足しましょう。"))

    # ---- 7. 過去のコミットに機密ファイルがない ----
    hist <- r108_git_history_files(git)
    leaked <- hist[grepl(r108_secret_pattern, hist)]
    r108_item(length(leaked) == 0, "data/ の中のファイルや .Renviron が、どのコミットにも入っていない",
      c(paste0("コミットに入っています: ", paste(utils::head(leaked, 5), collapse = ", ")),
        "後から .gitignore に書いても、過去のコミットには残ります。まだ GitHub に送っていないなら、.git フォルダを消してリポジトリを作り直すのが確実です（本文の「間違えてコミットしたら」）。"))

    # ---- 8. RStudio の作業用ファイル ----
    junk <- tracked[grepl("^\\.Rproj\\.user/|(^|/)\\.Rhistory$|(^|/)\\.RData$", tracked)]
    r108_item(length(junk) == 0, "RStudio の作業用ファイル（.Rproj.user/・.Rhistory・.RData）をコミットしていない",
      c(paste0("コミットに入っています: ", paste(utils::head(junk, 3), collapse = ", ")),
        "git rm -r --cached .Rproj.user（.Rhistory なども同様）で追跡をやめ、.gitignore に書いてからコミットしましょう。"))

    # ---- 9. 未コミットの変更 ----
    dirty <- r108_git_dirty(git)
    r108_item(!anyNA(dirty) && length(dirty) == 0, "コミットしていない変更がない（check_104.R は除く）",
      c(paste0("git status の結果: ", paste(utils::head(dirty, 5), collapse = " / ")),
        "残す変更は git add と git commit で記録し、記録しないファイルは .gitignore に書きましょう。"))
  } else {
    msg <- "先にリポジトリを作りましょう。"
    for (lab in c("コミットが3つ以上ある", ".gitignore があり、コミットされている",
                  "data/ フォルダと .Renviron が .gitignore で除外されている",
                  "data/ の中のファイルや .Renviron が、どのコミットにも入っていない"))
      r108_item(FALSE, lab, msg)
  }
}

r108_finish(104, c(120L, 27L, 26L, 18L, 7L, 27L, 26L, 30L, 7L, 25L, 27L, 105L, 107L))
