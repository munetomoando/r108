# 見本のリポジトリを作る（tests/r/test_local.R がコピー後に実行する）
g <- function(...) {
  out <- suppressWarnings(system2("git", shQuote(c(...)), stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status"))) stop(paste(c(...), collapse = " "), ": ", paste(out, collapse = "\n"))
  invisible(out)
}
final <- readLines("final.qmd", encoding = "UTF-8")
# 偽のトークン（GitHub の push protection に止められないよう、ここでつなぎ合わせて入れる）
final <- sub("FAKE_TOKEN_PLACEHOLDER", paste0("ghp", "_A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"), final, fixed = TRUE)
readme <- readLines("README.md", encoding = "UTF-8")
file.remove("README.md")
g("init", "-q", "-b", "main")
g("config", "user.name", "Sorano Hanako")
g("config", "user.email", "hanako@example.com")
# 1. プロジェクトと .gitignore
g("add", ".gitignore", "r108_final.Rproj")
g("commit", "-q", "-m", "プロジェクトと .gitignore を作る")
# 2〜4. 報告書を少しずつ書く（見出しの位置で切る）
cut_at <- function(h) { i <- grep(h, final, fixed = TRUE)[1]; final[seq_len(i - 1L)] }
writeLines(cut_at("## 分析"), "final.qmd", useBytes = TRUE)
g("add", "final.qmd")
g("commit", "-q", "-m", "データを読み、経路別の図を描く")
writeLines(cut_at("## 結論と次の一手"), "final.qmd", useBytes = TRUE)
g("commit", "-q", "-a", "-m", "年齢の図と回帰表を足す")
writeLines(final, "final.qmd", useBytes = TRUE)
g("commit", "-q", "-a", "-m", "要約と結論を書く")
# 5. README
writeLines(readme, "README.md", useBytes = TRUE)
g("add", "README.md")
g("commit", "-q", "-m", "README を書く")
# GitHub に push したのと同じ状態を、ネットワークを使わずに作る
g("remote", "add", "origin", "https://github.com/sorano-hanako/r108_final.git")
g("update-ref", "refs/remotes/origin/main", "HEAD")
g("branch", "-q", "--set-upstream-to=origin/main", "main")
