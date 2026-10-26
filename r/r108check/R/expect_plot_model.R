# 図とモデルの判定

aes_label <- function(mapping, name) {
  if (is.null(mapping)) return(NULL)
  q <- mapping[[name]]
  if (is.null(q) && name == "colour") q <- mapping[["color"]]
  if (is.null(q)) return(NULL)
  rlang::as_label(q)
}

#' ggplot の層の種類と対応づけ（aes）を確かめる
#'
#' p を省略すると、学生のコードで最後に作られた図を使う。
#' @export
expect_ggplot <- function(p = NULL, geom = NULL, x = NULL, y = NULL, colour = NULL,
                          fill = NULL, facet = NULL) {
  if (is.null(p)) p <- .r108$stu_plot
  if (is.null(p) || !inherits(p, "ggplot")) {
    r108_fail("ggplot の図が見つかりません。ggplot() で図を作り、表示まで実行しましょう。")
  }
  layers <- p$layers
  geoms <- unname(vapply(layers, function(l) sub("^Geom", "", class(l$geom)[1]), ""))
  stats <- unname(vapply(layers, function(l) sub("^Stat", "", class(l$stat)[1]), ""))
  if (!is.null(geom)) {
    want <- gsub("_", "", tolower(sub("^geom_", "", geom)))
    # geom_histogram() の層は geom が bar・stat が bin になるので、名前を補って照合する
    have <- c(tolower(geoms), ifelse(tolower(geoms) == "bar" & tolower(stats) == "bin", "histogram", NA))
    for (g in want) {
      if (!g %in% have) {
        r108_fail(paste0("geom_", g, "() の層がありません（いまの層: ",
                         if (length(geoms)) paste0("geom_", tolower(geoms), collapse = ", ") else "なし", "）。"))
      }
    }
  }
  check_aes <- function(name, want, ja) {
    if (is.null(want)) return(invisible())
    found <- c(aes_label(p$mapping, name),
               unlist(lapply(layers, function(l) aes_label(l$mapping, name))))
    if (!want %in% found) {
      r108_fail(paste0(ja, "に ", want, " が対応づけられていません。aes(", name, " = ", want, ") を確認しましょう。"))
    }
  }
  check_aes("x", x, "横軸")
  check_aes("y", y, "縦軸")
  check_aes("colour", colour, "色")
  check_aes("fill", fill, "塗り")
  if (!is.null(facet)) {
    vars <- tryCatch(names(p$facet$params$facets %||% c(p$facet$params$rows, p$facet$params$cols)),
                     error = function(e) character())
    if (!facet %in% vars) {
      r108_fail(paste0(facet, " で図を分割していません。facet_wrap(~ ", facet, ") を使いましょう。"))
    }
  }
  invisible(TRUE)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

model_coefs <- function(m) {
  cf <- tryCatch(stats::coef(m), error = function(e) NULL)
  if (is.null(cf)) r108_fail("係数を取り出せるモデルではありません。")
  names(cf) <- norm_term(names(cf))
  cf
}

# 交差項は書く順で名前が変わる（a:b と b:a）ので、並べ替えて同じ名前にする
norm_term <- function(x) {
  vapply(strsplit(x, ":", fixed = TRUE), function(p) paste(sort(p), collapse = ":"), character(1))
}

#' 推定方法・式・係数が正解と一致するかを確かめる（lm、glm、fixest）
#' @export
expect_model <- function(m, like, tol = 1e-4) {
  if (is.null(m)) r108_fail("モデルが見つかりません。")
  if (class(m)[1] != class(like)[1]) {
    r108_fail(paste0("推定方法が違います（", class(m)[1], " ではなく ", class(like)[1], " を使います）。"))
  }
  if (inherits(m, "glm") && stats::family(m)$family != stats::family(like)$family) {
    r108_fail(paste0("glm の family が違います（", stats::family(like)$family, " を使います）。"))
  }
  a <- model_coefs(m); b <- model_coefs(like)
  missing <- setdiff(names(b), names(a))
  extra <- setdiff(names(a), names(b))
  if (length(missing) > 0 || length(extra) > 0) {
    msg <- "説明変数が違います。"
    if (length(missing)) msg <- paste0(msg, "足りない項: ", paste(missing, collapse = ", "), "。")
    if (length(extra)) msg <- paste0(msg, "余分な項: ", paste(extra, collapse = ", "), "。")
    r108_fail(msg)
  }
  if (stats::nobs(m) != stats::nobs(like)) {
    r108_fail(sprintf("推定に使った観測数が違います（あなたは%d件）。データの絞り込みを確認しましょう。",
                      stats::nobs(m)))
  }
  d <- abs(a[names(b)] - b) > tol * pmax(1, abs(b))
  if (any(d)) {
    r108_fail(paste0("係数 ", names(b)[which(d)[1]], " の値が違います。変数の作り方を確認しましょう。"))
  }
  invisible(TRUE)
}

#' 特定の係数の値を確かめる
#' @export
expect_coef <- function(m, term, value, tol = 1e-4) {
  cf <- model_coefs(m)
  term <- norm_term(term)
  if (!term %in% names(cf)) r108_fail(paste0("係数 ", term, " がモデルにありません。"))
  if (abs(cf[[term]] - value) > tol * max(1, abs(value))) {
    r108_fail(paste0("係数 ", term, " の値が違います（あなたの値: ", signif(cf[[term]], 6), "）。"))
  }
  invisible(TRUE)
}
