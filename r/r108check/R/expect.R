# 判定関数。失敗時は r108_fail() で日本語のメッセージを投げる。
# 正解の値をメッセージに出さない（自分で考える余地を残す）。

#' 判定の失敗を知らせる
#' @export
r108_fail <- function(message) {
  cond <- structure(
    class = c("r108_failure", "error", "condition"),
    list(message = message, call = NULL)
  )
  stop(cond)
}

#' 条件が TRUE でなければ失敗にする
#' @export
check_that <- function(condition, message) {
  if (!isTRUE(condition)) r108_fail(message)
  invisible(TRUE)
}

fmt <- function(x, n = 6) {
  if (is.null(x)) return("NULL")
  if (is.data.frame(x)) return(sprintf("%d行×%d列のデータフレーム", nrow(x), ncol(x)))
  if (length(x) == 0) return("長さ0のベクトル")
  if (is.numeric(x)) x <- signif(x, 6)
  s <- paste(utils::head(format(x, trim = TRUE), n), collapse = ", ")
  if (length(x) > n) s <- paste0(s, ", …（全", length(x), "個）")
  s
}

type_ja <- function(x) {
  if (is.data.frame(x)) return("データフレーム")
  if (is.factor(x)) return("因子（factor）")
  if (inherits(x, "Date")) return("日付（Date）")
  switch(typeof(x),
    double = "数値", integer = "整数", character = "文字",
    logical = "論理値（TRUE/FALSE）", list = "リスト", closure = "関数",
    typeof(x)
  )
}

#' オブジェクトが存在し、指定したクラスかを確かめる
#' @export
expect_object <- function(name, class = NULL) {
  env <- .r108$stu
  if (!exists(name, envir = env, inherits = FALSE)) {
    r108_fail(paste0(name, " がまだ作られていません。", name, " <- … の形で代入しましょう。"))
  }
  obj <- get(name, envir = env, inherits = FALSE)
  if (!is.null(class) && !inherits(obj, class)) {
    r108_fail(paste0(name, " の種類が違います。", type_ja(obj), "になっていますが、",
                     paste(class, collapse = "/"), " を作ってください。"))
  }
  invisible(TRUE)
}

#' 数値・文字・論理値が一致するかを確かめる
#' @export
expect_value <- function(x, expected, tol = 1e-6, label = "結果") {
  if (is.null(x)) {
    r108_fail(paste0(label, "が表示されていません。最後の行で値を表示するか、指示どおり代入しましょう。"))
  }
  if (is.data.frame(expected) || is.data.frame(x)) {
    return(expect_df_equal(x, expected, tol = tol))
  }
  if (is.factor(x)) x <- as.character(x)
  if (is.factor(expected)) expected <- as.character(expected)
  if (length(x) != length(expected)) {
    r108_fail(sprintf("%sの長さが違います（あなたの結果は%d個）。期待される個数は%d個です。",
                      label, length(x), length(expected)))
  }
  if (is.numeric(expected)) {
    if (!is.numeric(x) && !is.logical(x)) {
      r108_fail(paste0(label, "が数値ではなく", type_ja(x), "になっています。"))
    }
    x <- as.numeric(x); expected <- as.numeric(expected)
    if (any(is.na(x) != is.na(expected))) {
      r108_fail(paste0(label, "に NA が含まれています（または足りません）。na.rm = TRUE が必要かもしれません。"))
    }
    ok <- is.na(expected) | abs(x - expected) <= tol * pmax(1, abs(expected))
    if (!all(ok)) {
      r108_fail(paste0(label, "の値が違います。あなたの結果は ", fmt(x), " でした。"))
    }
  } else {
    if (typeof(x) != typeof(expected)) {
      r108_fail(paste0(label, "の型が違います。", type_ja(x), "ではなく", type_ja(expected), "になるはずです。"))
    }
    if (!identical(unname(as.vector(x)), unname(as.vector(expected)))) {
      r108_fail(paste0(label, "が違います。あなたの結果は ", fmt(x), " でした。"))
    }
  }
  invisible(TRUE)
}

#' 列名を確かめる（順序は問わない）
#' @export
expect_cols <- function(df, cols) {
  if (!is.data.frame(df)) r108_fail("データフレームになっていません。")
  missing <- setdiff(cols, names(df))
  if (length(missing) > 0) {
    r108_fail(paste0("列 ", paste(missing, collapse = ", "), " がありません。"))
  }
  invisible(TRUE)
}

#' 行数を確かめる
#' @export
expect_nrow <- function(df, n) {
  if (!is.data.frame(df)) r108_fail("データフレームになっていません。")
  if (nrow(df) != n) {
    r108_fail(sprintf("行数が違います（あなたの結果は%d行）。", nrow(df)))
  }
  invisible(TRUE)
}

#' データフレームが一致するかを確かめ、違うときはどこが違うかを返す
#' @export
expect_df_equal <- function(x, y, ignore_row_order = FALSE, ignore_col_order = TRUE,
                            tol = 1e-6) {
  if (!is.data.frame(x)) {
    r108_fail(paste0("データフレームになっていません（", type_ja(x), "になっています）。"))
  }
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  y <- as.data.frame(y, stringsAsFactors = FALSE)
  missing <- setdiff(names(y), names(x))
  extra <- setdiff(names(x), names(y))
  if (length(missing) > 0 || length(extra) > 0) {
    msg <- "列が違います。"
    if (length(missing) > 0) msg <- paste0(msg, "足りない列: ", paste(missing, collapse = ", "), "。")
    if (length(extra) > 0) msg <- paste0(msg, "余分な列: ", paste(extra, collapse = ", "), "。")
    r108_fail(msg)
  }
  if (ignore_col_order) {
    x <- x[names(y)]
  } else if (!identical(names(x), names(y))) {
    r108_fail(paste0("列の並び順が違います。期待される順: ", paste(names(y), collapse = ", ")))
  }
  if (nrow(x) != nrow(y)) {
    r108_fail(sprintf("行数が違います（あなたの結果は%d行、期待は%d行）。絞り込みや集計の条件を見直しましょう。",
                      nrow(x), nrow(y)))
  }
  for (nm in names(x)) {
    if (is.factor(x[[nm]])) x[[nm]] <- as.character(x[[nm]])
    if (is.factor(y[[nm]])) y[[nm]] <- as.character(y[[nm]])
  }
  if (ignore_row_order && nrow(x) > 1) {
    ox <- do.call(order, unname(lapply(x, function(v) if (is.numeric(v)) round(v, 6) else v)))
    oy <- do.call(order, unname(lapply(y, function(v) if (is.numeric(v)) round(v, 6) else v)))
    x <- x[ox, , drop = FALSE]
    y <- y[oy, , drop = FALSE]
  }
  for (nm in names(y)) {
    a <- x[[nm]]; b <- y[[nm]]
    if (is.numeric(b) && !is.numeric(a)) {
      r108_fail(paste0("列 ", nm, " が数値ではなく", type_ja(a), "になっています。"))
    }
    if (!is.numeric(b) && is.numeric(a)) {
      r108_fail(paste0("列 ", nm, " が", type_ja(b), "ではなく数値になっています。"))
    }
    if (is.numeric(b)) {
      bad <- (is.na(a) != is.na(b)) | (!is.na(b) & abs(a - b) > tol * pmax(1, abs(b)))
    } else {
      bad <- (is.na(a) != is.na(b)) | (!is.na(b) & as.character(a) != as.character(b))
    }
    bad[is.na(bad)] <- TRUE
    if (any(bad)) {
      i <- which(bad)[1]
      r108_fail(sprintf("列 %s の値が違います（%d行目など%d か所）。あなたの値: %s%s",
                        nm, i, sum(bad), fmt(a[i]),
                        if (ignore_row_order) "" else "。並び順も確認しましょう。"))
    }
  }
  invisible(TRUE)
}

#' 学生のコードがその関数を使っているか（構文解析で判定）
#' @export
expect_uses <- function(fn, message = NULL) {
  used <- called_functions(.r108$code)
  for (f in fn) {
    if (!f %in% used) {
      r108_fail(if (is.null(message)) paste0(f, "() を使って書いてみましょう。") else message)
    }
  }
  invisible(TRUE)
}

#' 学生のコードがその関数を使っていないか
#' @export
expect_not_uses <- function(fn, message = NULL) {
  used <- called_functions(.r108$code)
  hit <- intersect(fn, used)
  if (length(hit) > 0) {
    r108_fail(if (is.null(message)) paste0("この小課題では ", hit[1], "() を使わずに書きましょう。") else message)
  }
  invisible(TRUE)
}

#' コードの中で呼ばれている関数名（演算子を含む）
#' @export
called_functions <- function(code) {
  if (!nzchar(code)) return(character())
  pd <- tryCatch(utils::getParseData(parse(text = code, keep.source = TRUE)),
                 error = function(e) NULL)
  if (is.null(pd)) return(character())
  fns <- pd$text[pd$token %in% c("SYMBOL_FUNCTION_CALL", "SPECIAL")]
  ops <- pd$text[pd$token %in% c("PIPE", "LEFT_ASSIGN", "EQ_ASSIGN", "'+'", "'-'", "'*'", "'/'", "'^'",
                                 "EQ", "NE", "GT", "LT", "GE", "LE", "AND", "OR", "AND2", "OR2", "'!'", "'$'")]
  unique(c(fns, ops))
}

#' 出力（または記述式の回答）に特定の文字列が含まれるか
#' @export
expect_text <- function(pattern, message = NULL, ignore_case = TRUE) {
  out <- .r108$output
  for (p in pattern) {
    if (!grepl(p, out, perl = TRUE, ignore.case = ignore_case)) {
      r108_fail(if (is.null(message)) paste0("「", p, "」に当たる内容が見つかりません。") else message)
    }
  }
  invisible(TRUE)
}

#' 記述式の回答の長さを確かめる
#' @export
expect_min_chars <- function(n) {
  k <- nchar(gsub("\\s", "", .r108$output))
  if (k < n) r108_fail(sprintf("もう少し詳しく書きましょう（いま%d字、目安は%d字以上）。", k, n))
  invisible(TRUE)
}
