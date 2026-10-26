# 全ステップ（または指定したステップ）の正解コードを通常のRで実行し、判定が通ることを確かめる。
#   Rscript tests/r/run_solutions.R          # 全ステップ
#   Rscript tests/r/run_solutions.R 3 4 5    # 指定したステップ
# 確かめること:
#   1. 各小課題の solution を順に実行すると check が "ok" になる
#   2. fill/fix の starter と tests.fail のコードは "ok" にならない
#   3. 選択式の answer が choices の範囲内
#   4. solution で使う関数が、そのステップまでの learn（累積）と allow に含まれる（警告のみ）

suppressPackageStartupMessages({
  library(yaml)
})

args <- commandArgs(trailingOnly = FALSE)
script_dir <- dirname(normalizePath(sub("^--file=", "", args[grep("^--file=", args)])))
root <- normalizePath(file.path(script_dir, "..", ".."))
targets <- commandArgs(trailingOnly = TRUE)

# r108check をソースから読み込む（インストール不要）
r108 <- new.env()
for (f in list.files(file.path(root, "r", "r108check", "R"), full.names = TRUE)) sys.source(f, r108)
attach(r108, name = "r108check", warn.conflicts = FALSE)

# 1行目から使ってよい関数（演算子・基本の構文）
base_allow <- c("<-", "=", "(", "{", "[", "[[", "$", "+", "-", "*", "/", "^", "!", "|>",
                "==", "!=", ">", "<", ">=", "<=", "&", "|", "&&", "||", ":", "%/%", "%%", "%in%",
                "library", "print", "c", "function", "if", "for", "return", "invisible", "list",
                "TRUE", "FALSE")

step_dirs <- sort(list.dirs(file.path(root, "content", "steps"), recursive = FALSE))
# step.yaml のないフォルダ（執筆中）は飛ばす
step_dirs <- step_dirs[file.exists(file.path(step_dirs, "step.yaml"))]
all_steps <- lapply(step_dirs, function(d) yaml::read_yaml(file.path(d, "step.yaml")))
names(all_steps) <- basename(step_dirs)
if (length(targets) > 0) {
  targets <- sprintf("%03d", as.integer(targets))
} else {
  targets <- names(all_steps)
}

cumulative_learn <- function(id) {
  ids <- names(all_steps)[names(all_steps) <= id]
  unique(unlist(lapply(all_steps[ids], function(s) c(s$learn, s$allow))))
}

n_fail <- 0
n_warn <- 0
report <- function(kind, step, ex, msg) {
  cat(sprintf("  [%s] %s-%s: %s\n", kind, step, ex, msg))
}

old_wd <- getwd()
setwd(file.path(root, "public"))   # アプリと同じく data/xxx.csv で読めるようにする
grDevices::pdf(NULL)

for (id in targets) {
  s <- all_steps[[id]]
  if (is.null(s)) { cat("ステップ", id, "がありません\n"); n_fail <- n_fail + 1; next }
  cat(sprintf("%s %s\n", id, s$title))
  if (identical(s$mode, "local")) { cat("  （ローカル実行ステップ：スキップ）\n"); next }
  setup <- if (is.null(s$setup)) "" else s$setup
  ok_setup <- tryCatch({ session_start(setup); TRUE }, error = function(e) {
    report("NG", id, "setup", conditionMessage(e)); FALSE
  })
  if (!ok_setup) { n_fail <- n_fail + 1; next }

  exercises <- s$exercises
  code_ex <- Filter(function(e) !is.null(e$solution), exercises)
  for (e in code_ex) {
    if (isTRUE(e$free)) next
    tryCatch(run_solution(e$id, e$solution), error = function(err) {
      report("NG", id, e$id, paste("solution の実行でエラー:", conditionMessage(err)))
      n_fail <<- n_fail + 1
    })
  }
  allowed <- cumulative_learn(id)
  for (e in exercises) {
    if (!is.null(e$choices)) {
      if (is.null(e$answer) || e$answer < 0 || e$answer >= length(e$choices)) {
        report("NG", id, e$id, "answer が choices の範囲外"); n_fail <- n_fail + 1
      }
      next
    }
    run_one <- function(code) {
      if (isTRUE(e$free)) return(check_exercise(e$id, e$check, "", code))
      out <- paste(utils::capture.output(run_student(code)), collapse = "\n")
      st <- run_status()
      if (st != "ok") return(paste0("runerror\t", st))
      check_exercise(e$id, e$check, code, out)
    }
    # 不正解になるべきコードは、正解を実行する前に試す（環境を汚さないよう後で正解を流し直す）
    wrongs <- c(if (e$type %in% c("fill", "fix") && !is.null(e$starter)) e$starter, e$tests$fail)
    for (w in wrongs) {
      r <- run_one(w)
      if (identical(r, "ok")) {
        report("NG", id, e$id, paste("不正解のはずのコードが正解と判定された:\n", w)); n_fail <- n_fail + 1
      }
    }
    r <- run_one(e$solution)
    if (!identical(r, "ok")) {
      report("NG", id, e$id, paste("正解コードが通らない:", r)); n_fail <- n_fail + 1
    } else {
      report("ok", id, e$id, e$type)
    }
    if (!isTRUE(e$free)) {
      used <- called_functions(e$solution)
      extra <- setdiff(used, c(base_allow, allowed))
      if (length(extra) > 0) {
        report("警告", id, e$id, paste("learn にない関数:", paste(extra, collapse = ", ")))
        n_warn <- n_warn + 1
      }
    }
    if (is.null(e$hints) || length(e$hints) != 3) {
      report("NG", id, e$id, "ヒントは3段階必要"); n_fail <- n_fail + 1
    }
  }
}
setwd(old_wd)
cat(sprintf("\n失敗 %d 件、警告 %d 件\n", n_fail, n_warn))
if (n_fail > 0) quit(status = 1)
