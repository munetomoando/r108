# 見本のリポジトリを作る（tests/r/test_local.R がコピー後に実行する）
g <- function(...) {
  out <- suppressWarnings(system2("git", shQuote(c(...)), stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(out, "status"))) stop(paste(c(...), collapse = " "), ": ", paste(out, collapse = "\n"))
  invisible(out)
}
app <- readLines("app.R", encoding = "UTF-8")
g("init", "-q", "-b", "main")
g("config", "user.name", "Sora Taro")
g("config", "user.email", "sora.taro@example.com")
# 1. 最初の版（表なし）
v1 <- app[!grepl("tableOutput", app)]
v1 <- sub("plotOutput(\"sales_plot\"),", "plotOutput(\"sales_plot\")", v1, fixed = TRUE)
writeLines(v1, "app.R", useBytes = TRUE)
g("add", ".gitignore", "sora_app.Rproj", "app.R")
g("commit", "-q", "-m", "地域を選ぶと月別売上の図が変わるアプリ")
# 2. 店舗別の表を足す（見本の app.R に戻す）
writeLines(app, "app.R", useBytes = TRUE)
g("add", "app.R")
g("commit", "-q", "-m", "店舗別の2025年の売上の表を足す")
# 3. 既定の地域を変える
writeLines(sub("selected = \"関東\"", "selected = \"中部\"", app), "app.R", useBytes = TRUE)
g("commit", "-q", "-a", "-m", "最初に表示する地域を中部にする")
# 4. README を足す（ステップ105）
g("add", "README.md")
g("commit", "-q", "-m", "README を書く")
# API キーをスクリプトに直接書いてコミットしてしまった
writeLines(c("# 生成AIで図の説明文を作る（試し）", paste0("api_key <- \"sk-", "proj-Xy7Qw3Er5Ty8Ui2Op4As6Df9Gh1Jk3Lz\"")), "ai_comment.R")
g("add", "ai_comment.R")
g("commit", "-q", "-m", "図の説明文を作るスクリプト")
# GitHub に push したのと同じ状態を、ネットワークを使わずに作る
g("remote", "add", "origin", "https://github.com/sora-taro/sora_app.git")
g("update-ref", "refs/remotes/origin/main", "HEAD")
g("branch", "-q", "--set-upstream-to=origin/main", "main")
