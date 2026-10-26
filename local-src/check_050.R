# ステップ50: 自分のPCにRを入れる
# 確かめること: R の版、主要パッケージ、RStudio プロジェクト（.Rproj）、
# data/wage_survey.csv、第45ステップの回帰を書いた step45.R が動くこと。

cat("R108 ステップ50「自分のPCにRを入れる」の確認を始めます。\n")
cat("作業フォルダ: ", normalizePath(getwd(), winslash = "/"), "\n\n", sep = "")

# 1. R の版
r108_item(getRversion() >= "4.4.0",
  paste0("R の版が 4.4.0 以上（いまは ", getRversion(), "）"),
  "https://cran.r-project.org/ から最新の R を入れ直し、RStudio（Positron）を開き直してください。")

# 2. 主要パッケージ
pkgs <- c("tidyverse", "modelsummary", "sandwich", "fixest", "wooldridge", "rmarkdown")
missing <- pkgs[!vapply(pkgs, function(p) nzchar(system.file(package = p)), logical(1))]
r108_item(length(missing) == 0,
  paste0("主要パッケージ（", paste(pkgs, collapse = ", "), "）が入っている"),
  if (length(missing)) paste0("足りないのは ", paste(missing, collapse = ", "),
    "。コンソールで install.packages(c(", paste0("\"", missing, "\"", collapse = ", "), ")) を実行してください。"))

# 3. RStudio プロジェクト
rproj <- list.files(".", pattern = "\\.Rproj$")
r108_item(length(rproj) >= 1,
  "作業フォルダに RStudio プロジェクト（.Rproj）がある",
  c("RStudio なら File > New Project... で r108 などの名前のプロジェクトを作り、そのプロジェクトを開いた状態で実行します。",
    "Positron なら、プロジェクトのフォルダを開いてから writeLines(\"Version: 1.0\", \"r108.Rproj\") を一度だけ実行します。"))

# 4. データ
csv <- file.path("data", "wage_survey.csv")
wage_ref <- tryCatch(utils::read.csv(csv, fileEncoding = "UTF-8"), error = function(e) NULL)
r108_item(!is.null(wage_ref) && nrow(wage_ref) == 3000 &&
            all(c("log_wage", "female", "educ_years", "exper", "tenure") %in% names(wage_ref)),
  "data/wage_survey.csv があり、3,000行の賃金データとして読める",
  "アプリから wage_survey.csv をダウンロードし、プロジェクトのフォルダの中に作った data フォルダに置いてください。")

# 5. 第45ステップのコード
r108_item(file.exists("step45.R"),
  "第45ステップのコードを書いた step45.R がある",
  "File > New File > R Script で新しいスクリプトを開き、本文のコードを書いて step45.R という名前でプロジェクトのフォルダに保存してください。")

env45 <- new.env(parent = globalenv())
err45 <- NULL
if (file.exists("step45.R")) {
  err45 <- tryCatch({
    utils::capture.output(suppressMessages(source("step45.R", local = env45, encoding = "UTF-8")))
    NULL
  }, error = function(e) conditionMessage(e))
}
r108_item(file.exists("step45.R") && is.null(err45),
  "step45.R を最初から最後までエラーなしで実行できる",
  if (!is.null(err45)) paste0("エラー: ", err45, "  （step45.R を開いて Source ボタンで実行し、止まる行を直してください）")
  else "step45.R を作ってください。")

m_jp <- get0("m_jp", envir = env45, inherits = FALSE)
ok_model <- FALSE
if (inherits(m_jp, "lm") && !is.null(wage_ref)) {
  ref <- stats::lm(log_wage ~ female * educ_years + exper + I(exper^2) + tenure + I(tenure^2), data = wage_ref)
  ok_model <- stats::nobs(m_jp) == 3000 && length(stats::coef(m_jp)) == length(stats::coef(ref)) &&
    isTRUE(max(abs(unname(stats::fitted(m_jp)) - unname(stats::fitted(ref)))) < 1e-6)
}
r108_item(ok_model,
  "m_jp が第45ステップ d と同じ回帰（log_wage ~ female * educ_years + exper + I(exper^2) + tenure + I(tenure^2)）になっている",
  "step45.R の中で m_jp <- lm(log_wage ~ female * educ_years + exper + I(exper^2) + tenure + I(tenure^2), data = wage) と推定しているか確かめてください。")

r108_item(exists("tab_cmp", envir = env45, inherits = FALSE),
  "回帰表 tab_cmp を modelsummary() で作っている",
  "第45ステップ d と同じく、modelsummary() の結果を tab_cmp に代入してください。")

r108_finish("050", c(120L, 27L, 26L, 18L, 7L, 26L, 31L, 26L, 7L, 29L, 108L, 25L, 107L))
