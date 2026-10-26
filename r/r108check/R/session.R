# ステップ内の実行環境を管理する。
# webR（ブラウザ）と tests/r/run_solutions.R（通常のR）の両方から同じ関数を呼ぶ。

.r108 <- new.env(parent = emptyenv())

#' ステップを開いたときに呼ぶ。学生用と正解用の環境を作り、setup を実行する
#' @export
session_start <- function(setup = "") {
  .r108$stu <- new.env(parent = globalenv())
  .r108$sol <- new.env(parent = globalenv())
  .r108$sol_values <- list()
  .r108$sol_plots <- list()
  .r108$stu_value <- NULL
  .r108$stu_plot <- NULL
  .r108$status <- "ok"
  .r108$code <- ""
  .r108$output <- ""
  if (nzchar(setup)) {
    exprs <- parse(text = setup, keep.source = FALSE)
    for (e in exprs) eval(e, .r108$stu)
    for (e in exprs) eval(e, .r108$sol)
  }
  reset_last_plot()
  invisible(TRUE)
}

#' 正解コードを正解用の環境で実行し、最後の値と図を記録する（表示はしない）
#' @export
run_solution <- function(id, code) {
  reset_last_plot()
  value <- NULL
  if (nzchar(code)) {
    exprs <- parse(text = code, keep.source = FALSE)
    for (e in exprs) {
      res <- withVisible(eval(e, .r108$sol))
      if (res$visible) value <- res$value
    }
  }
  .r108$sol_values[id] <- list(value)
  .r108$sol_plots[id] <- list(current_last_plot())
  reset_last_plot()
  invisible(TRUE)
}

#' 学生のコードを学生用の環境で1式ずつ実行し、見える値は表示する
#'
#' 結果は .r108$status に "ok" または "error\t<メッセージ>" として残す。
#' @export
run_student <- function(code) {
  reset_last_plot()
  .r108$stu_value <- NULL
  .r108$stu_plot <- NULL
  .r108$status <- "ok"
  exprs <- tryCatch(parse(text = code, keep.source = FALSE), error = function(e) e)
  if (inherits(exprs, "error")) {
    .r108$status <- paste0("parse\t", conditionMessage(exprs))
    return(invisible(FALSE))
  }
  ok <- tryCatch({
    for (e in exprs) {
      res <- withVisible(eval(e, .r108$stu))
      if (res$visible) {
        .r108$stu_value <- res$value
        print(res$value)
      }
    }
    TRUE
  }, error = function(err) {
    call <- conditionCall(err)
    .r108$status <- paste0(
      "error\t", conditionMessage(err),
      "\t", if (is.null(call)) "" else paste(deparse(call, nlines = 1), collapse = "")
    )
    FALSE
  })
  .r108$stu_plot <- current_last_plot()
  invisible(ok)
}

#' 直前の run_student の結果。webR側から読む
#' @export
run_status <- function() .r108$status

#' 判定を実行する。戻り値は "ok"、"fail\t<メッセージ>"、"error\t<メッセージ>" のいずれか
#' @export
check_exercise <- function(id, check, code = "", output = "") {
  .r108$code <- code
  .r108$output <- output
  ce <- new.env(parent = .r108$stu)
  ce$.sol <- .r108$sol
  ce$.code <- code
  ce$.output <- output
  ce$.value <- .r108$stu_value
  ce$.sol_value <- .r108$sol_values[[id]]
  ce$.plot <- .r108$stu_plot
  ce$.sol_plot <- .r108$sol_plots[[id]]
  tryCatch({
    eval(parse(text = check, keep.source = FALSE), ce)
    "ok"
  },
  r108_failure = function(e) paste0("fail\t", conditionMessage(e)),
  error = function(e) {
    msg <- conditionMessage(e)
    m <- regmatches(msg, regexec("object '([^']+)' not found", msg))[[1]]
    if (length(m) == 2) {
      return(paste0("fail\t", m[2], " がまだ作られていません。指示どおりの名前で代入したか確認しましょう。"))
    }
    paste0("error\t", msg)
  })
}

reset_last_plot <- function() {
  if (isNamespaceLoaded("ggplot2")) {
    ggplot2::set_last_plot(NULL)
  }
}

current_last_plot <- function() {
  if (isNamespaceLoaded("ggplot2")) ggplot2::last_plot() else NULL
}
