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

# 最後の変更をコミットし忘れた
writeLines(sub("売上（百万円）", "売上（百万円、税込み）", app), "app.R", useBytes = TRUE)
