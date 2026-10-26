// M4 パッケージ検証：第2〜12部で使うパッケージと、webR で動くかを確かめる最小の試し方。
// test は最後の式が長さ1の文字列になるように書く（"ok" 以外はその内容を表示する）。
export type PkgCase = {
  pkg: string;
  steps: string;
  /** 公式リポジトリに無いときに試す r-universe の持ち主 */
  universe?: string;
  /** 試す前に置くデータ */
  data?: string[];
  test: string;
};

export const WEBR_REPO = 'https://repo.r-wasm.org';
export const universeRepo = (owner: string) => `https://${owner}.r-universe.dev`;

export const PKG_CASES: PkgCase[] = [
  { pkg: 'readr', steps: '3〜, 10, 11', test: `d <- readr::read_csv(I("a,b\\n1,2"), show_col_types = FALSE); stopifnot(nrow(d) == 1); "ok"` },
  { pkg: 'dplyr', steps: '4〜', test: `stopifnot(nrow(dplyr::filter(mtcars, cyl == 4)) == 11); "ok"` },
  { pkg: 'tidyr', steps: '13', test: `d <- tidyr::pivot_longer(data.frame(id = 1, a = 1, b = 2), -id); stopifnot(nrow(d) == 2); "ok"` },
  { pkg: 'ggplot2', steps: '19〜27 ほか', test: `p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point(); invisible(ggplot2::ggplot_build(p)); "ok"` },
  { pkg: 'lubridate', steps: '15, 73〜', test: `stopifnot(lubridate::wday(lubridate::ymd("2025-01-01")) == 4); "ok"` },
  { pkg: 'stringr', steps: '12', test: `stopifnot(stringr::str_detect("男性", "男")); "ok"` },
  { pkg: 'forcats', steps: '22', test: `f <- forcats::fct_reorder(c("a", "b"), c(2, 1)); stopifnot(levels(f)[1] == "b"); "ok"` },
  { pkg: 'readxl', steps: '10', data: ['ec_products.xlsx'], test: `d <- readxl::read_excel("data/ec_products.xlsx", sheet = "商品一覧"); stopifnot(nrow(d) == 200); "ok"` },
  { pkg: 'janitor', steps: '11, 12', test: `d <- janitor::clean_names(data.frame(check.names = FALSE, "A B" = 1)); stopifnot(names(d) == "a_b", janitor::excel_numeric_to_date(45658) == as.Date("2025-01-01")); "ok"` },
  { pkg: 'stringi', steps: '12', test: `stopifnot(stringi::stri_trans_nfkc("１２３ＡＢ") == "123AB"); "ok"` },
  { pkg: 'jsonlite', steps: '17', test: `stopifnot(jsonlite::fromJSON('{"a": [1, 2]}')$a[2] == 2); "ok"` },
  { pkg: 'gapminder', steps: '19', test: `stopifnot(nrow(gapminder::gapminder) == 1704); "ok"` },
  { pkg: 'viridisLite', steps: '25', test: `stopifnot(length(viridisLite::viridis(3)) == 3); "ok"` },
  { pkg: 'broom', steps: '37〜', test: `stopifnot(nrow(broom::tidy(lm(mpg ~ wt, mtcars))) == 2); "ok"` },
  { pkg: 'fixest', steps: '43, 44, 65〜72', universe: 'lrberge', test: `m <- fixest::feols(mpg ~ wt | cyl, mtcars, vcov = "hetero"); stopifnot(length(coef(m)) == 1); invisible(fixest::etable(m)); "ok"` },
  { pkg: 'modelsummary', steps: '44, 49', universe: 'vincentarelbundock', test: `t1 <- modelsummary::modelsummary(list(lm(mpg ~ wt, mtcars)), output = "data.frame"); t2 <- modelsummary::datasummary_skim(mtcars[, 1:3], output = "data.frame"); stopifnot(nrow(t1) > 0, nrow(t2) > 0); "ok"` },
  { pkg: 'wooldridge', steps: '45', universe: 'justinmshea', test: `stopifnot(nrow(wooldridge::wage1) == 526); "ok"` },
  { pkg: 'causaldata', steps: '47〜49, 62, 68, 69, 71', universe: 'nickch-k', test: `stopifnot(nrow(causaldata::Mroz) == 753, nrow(causaldata::close_college) == 3010, all(c("organ_donations", "gov_transfers", "nsw_mixtape", "cps_mixtape") %in% data(package = "causaldata")$results[, "Item"])); "ok"` },
  { pkg: 'MatchIt', steps: '60, 63', universe: 'kosukeimai', test: `m <- MatchIt::matchit(am ~ wt + hp, data = mtcars); stopifnot(nrow(MatchIt::match.data(m)) > 0); "ok"` },
  { pkg: 'rsample', steps: '92〜99', universe: 'tidymodels', test: `s <- rsample::initial_split(mtcars, prop = 0.75); stopifnot(nrow(rsample::training(s)) == 24); "ok"` },
  { pkg: 'recipes', steps: '93〜', universe: 'tidymodels', test: `r <- recipes::prep(recipes::step_normalize(recipes::recipe(mpg ~ wt, mtcars), wt)); stopifnot(nrow(recipes::bake(r, NULL)) == 32); "ok"` },
  { pkg: 'parsnip', steps: '93〜', universe: 'tidymodels', test: `f <- parsnip::fit(parsnip::linear_reg(), mpg ~ wt, data = mtcars); stopifnot(nrow(predict(f, mtcars)) == 32); "ok"` },
  { pkg: 'workflows', steps: '93〜', universe: 'tidymodels', test: `wf <- workflows::add_formula(workflows::add_model(workflows::workflow(), parsnip::linear_reg()), mpg ~ wt); f <- parsnip::fit(wf, mtcars); stopifnot(nrow(predict(f, mtcars)) == 32); "ok"` },
  { pkg: 'yardstick', steps: '94〜99', universe: 'tidymodels', test: `d <- data.frame(truth = factor(c("y", "n", "y"), levels = c("y", "n")), p = c(.9, .2, .6)); a <- yardstick::roc_auc(d, truth, p); stopifnot(a$.estimate == 1); "ok"` },
  { pkg: 'tune', steps: '94, 99', universe: 'tidymodels', test: `wf <- workflows::add_formula(workflows::add_model(workflows::workflow(), parsnip::linear_reg()), mpg ~ wt); r <- tune::fit_resamples(wf, rsample::vfold_cv(mtcars, v = 3)); stopifnot(nrow(tune::collect_metrics(r)) == 2); "ok"` },
  { pkg: 'tidymodels', steps: '93〜99', universe: 'tidymodels', test: `suppressPackageStartupMessages(library(tidymodels)); "ok"` },
  { pkg: 'rpart', steps: '97', test: `f <- parsnip::fit(parsnip::set_mode(parsnip::set_engine(parsnip::decision_tree(), "rpart"), "regression"), mpg ~ wt + hp, data = mtcars); stopifnot(nrow(predict(f, mtcars)) == 32); "ok"` },
  { pkg: 'ranger', steps: '98, 99（予定）', test: `m <- ranger::ranger(mpg ~ wt + hp, data = mtcars, num.threads = 1, num.trees = 20); "ok"` },
  { pkg: 'randomForest', steps: '98, 99（ranger の代替）', test: `f <- parsnip::fit(parsnip::set_mode(parsnip::set_engine(parsnip::rand_forest(trees = 50), "randomForest"), "classification"), am ~ wt + hp, data = transform(mtcars, am = factor(am))); p <- predict(f, mtcars, type = "prob"); imp <- randomForest::importance(f$fit); stopifnot(nrow(p) == 32, nrow(imp) == 2); "ok"` },
  { pkg: 'DBI', steps: '103', test: `stopifnot(is.function(DBI::dbConnect)); "ok"` },
  { pkg: 'duckdb', steps: '103', universe: 'duckdb', test: `con <- DBI::dbConnect(duckdb::duckdb()); DBI::dbWriteTable(con, "m", mtcars); n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM m WHERE cyl = 4")$n; DBI::dbDisconnect(con); stopifnot(n == 11); "ok"` },
  // RSQLite は webR の公式リポジトリに無く、入れようとすると後続のパッケージの読込も壊れることがあるので最後に試す
  { pkg: 'dbplyr', steps: '103', test: `con <- DBI::dbConnect(duckdb::duckdb()); DBI::dbWriteTable(con, "m", mtcars); q <- dplyr::filter(dplyr::tbl(con, "m"), cyl == 4); s <- paste(capture.output(dplyr::show_query(q)), collapse = " "); DBI::dbDisconnect(con); stopifnot(grepl("WHERE", s)); "ok"` },
  { pkg: 'testthat', steps: '106', test: `testthat::expect_equal(1 + 1, 2); "ok"` },
  { pkg: 'RSQLite', steps: '103（duckdb の代替候補）', test: `"ok"` },
];

/** 日本語の図：軸・見出し・凡例・注記が文字化けしないか（画像を目で確かめる） */
export const JA_PLOT = `library(ggplot2)
d <- data.frame(地域 = c("北海道・東北", "関東", "中部", "近畿", "中国・四国", "九州・沖縄"),
                売上 = c(52, 98, 61, 74, 40, 47))
ggplot(d, aes(reorder(地域, 売上), 売上, fill = 地域)) +
  geom_col() + coord_flip() +
  annotate("text", x = 1.5, y = 85, label = "注記：架空のデータ") +
  labs(title = "地域別の売上（億円）", x = NULL, y = "売上（億円）", caption = "出所：そらまめマーケット") +
  theme_minimal()`;
