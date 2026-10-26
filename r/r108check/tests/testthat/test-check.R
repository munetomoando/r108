result <- function(check, code = "", id = "a", output = "") {
  run_student(code)
  check_exercise(id, check, code, output)
}

test_that("正解・不正解・エラーを区別できる", {
  session_start("x0 <- 1:10")
  run_solution("a", "y <- mean(x0)")
  expect_equal(result("expect_value(y, .sol$y)", "y <- mean(x0)"), "ok")
  expect_match(result("expect_value(y, .sol$y)", "y <- sum(x0)"), "^fail\t.*値が違います")
  run_student("y <- undefined_object + 1")
  expect_match(run_status(), "^error\tobject 'undefined_object' not found")
  run_student("y <- (1 + ")
  expect_match(run_status(), "^parse\t")
})

test_that("未作成のオブジェクトは日本語の失敗になる", {
  session_start()
  run_solution("a", "z <- 3")
  expect_match(result("expect_value(z, .sol$z)", "1 + 1"), "^fail\tz がまだ作られていません")
  expect_match(result('expect_object("z")', "1 + 1"), "^fail\tz がまだ")
})

test_that(".value は最後に表示された値", {
  session_start()
  run_solution("a", "round(1.2345, 2)")
  expect_equal(result("expect_value(.value, .sol_value)", "round(1.2345, 2)"), "ok")
  expect_match(result("expect_value(.value, .sol_value)", "round(1.2345, 1)"), "^fail")
})

test_that("expect_df_equal は違いの場所を返す", {
  session_start("df0 <- data.frame(a = 1:3, b = c('x', 'y', 'z'))")
  run_solution("a", "d <- df0[df0$a > 1, ]")
  expect_equal(result("expect_df_equal(d, .sol$d)", "d <- df0[df0$a > 1, ]"), "ok")
  expect_match(result("expect_df_equal(d, .sol$d)", "d <- df0"), "行数が違います")
  expect_match(result("expect_df_equal(d, .sol$d)", "d <- df0[df0$a > 1, 'a', drop = FALSE]"),
               "足りない列: b")
  expect_equal(result("expect_df_equal(d, .sol$d, ignore_row_order = TRUE)",
                      "d <- df0[c(3, 2), ]"), "ok")
  expect_match(result("expect_df_equal(d, .sol$d)", "d <- df0[c(3, 2), ]"), "列 a の値が違います")
})

test_that("expect_uses は構文解析で関数の使用を確かめる", {
  session_start("v <- c(3, 9, 12)")
  run_solution("a", "n <- sum(v > 8)")
  chk <- 'expect_uses("sum"); expect_value(n, .sol$n)'
  expect_equal(result(chk, "n <- sum(v > 8)"), "ok")
  expect_match(result(chk, "n <- length(v[v > 8])"), "sum\\(\\) を使って")
  expect_true("|>" %in% called_functions("x |> sum()"))
  expect_true("%/%" %in% called_functions("7 %/% 2"))
  expect_false("sum" %in% called_functions("# sum(x)\nmean(x)"))
})

test_that("expect_text は記述式の回答を確かめる", {
  session_start()
  expect_equal(check_exercise("a", 'expect_text("高齢化")', "", "東北で高齢化が進む"), "ok")
  expect_match(check_exercise("a", 'expect_text(c("高齢化", "人口"))', "", "高齢化"), "^fail")
  expect_match(check_exercise("a", "expect_min_chars(20)", "", "短い"), "もう少し詳しく")
})

test_that("expect_model と expect_coef", {
  session_start("d <- data.frame(x = 1:20, y = (1:20) * 2 + sin(1:20))")
  run_solution("a", "m <- lm(y ~ x, data = d)")
  chk <- "expect_model(m, like = .sol$m)"
  expect_equal(result(chk, "m <- lm(y ~ x, data = d)"), "ok")
  expect_match(result(chk, "m <- lm(y ~ 1, data = d)"), "足りない項: x")
  expect_match(result(chk, "m <- lm(y ~ x, data = d[1:10, ])"), "観測数")
  expect_match(result(chk, "m <- glm(y ~ x, data = d)"), "推定方法")
  expect_equal(result('expect_coef(m, "x", coef(.sol$m)[["x"]])', "m <- lm(y ~ x, data = d)"), "ok")
})

test_that("expect_ggplot は層と aes を確かめる", {
  skip_if_not_installed("ggplot2")
  session_start("library(ggplot2); d <- data.frame(x = 1:3, y = 3:1, g = c('a', 'b', 'a'))")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  ok <- result('expect_ggplot(geom = "point", x = "x", y = "y", colour = "g")',
               "ggplot(d, aes(x, y, colour = g)) + geom_point()")
  expect_equal(ok, "ok")
  expect_match(result('expect_ggplot(geom = "line")', "ggplot(d, aes(x, y)) + geom_point()"),
               "geom_line\\(\\) の層がありません")
  expect_match(result('expect_ggplot(colour = "g")', "ggplot(d, aes(x, y)) + geom_point()"),
               "色に g")
  expect_match(result('expect_ggplot(geom = "point")', "1 + 1"), "図が見つかりません")
  expect_equal(result('expect_ggplot(facet = "g")',
                      "ggplot(d, aes(x, y)) + geom_point() + facet_wrap(~ g)"), "ok")
})

test_that("expect_ggplot は geom_histogram の層を見分ける", {
  library(ggplot2)
  p <- ggplot(data.frame(x = 1:10), aes(x)) + geom_histogram(bins = 3)
  expect_true(expect_ggplot(p, geom = "histogram", x = "x"))
  expect_true(expect_ggplot(p, geom = "bar"))
  p2 <- ggplot(data.frame(x = c("a", "b")), aes(x)) + geom_bar()
  expect_error(expect_ggplot(p2, geom = "histogram"))
})

test_that("expect_model は交差項の書く順を区別しない", {
  d <- data.frame(y = c(1, 3, 2, 5, 4, 6), x = c(0, 1, 0, 1, 0, 1), z = c(1, 2, 3, 4, 5, 7))
  like <- lm(y ~ x * z, data = d)
  expect_silent(expect_model(lm(y ~ z * x, data = d), like = like))
  expect_silent(expect_coef(lm(y ~ z * x, data = d), "x:z", coef(like)[["x:z"]]))
})
