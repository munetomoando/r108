# 合成データに仕込んだ「答え」が推定で再現されるかを確かめる。
#   Rscript tests/r/test_synth.R
# 先に Rscript data-raw/build_all.R でデータを作っておくこと。失敗があれば終了コード1で終わる。
suppressPackageStartupMessages({
  library(testthat)
  library(dplyr)
  library(readr)
  library(lubridate)
})

args <- commandArgs(trailingOnly = FALSE)
script_dir <- dirname(normalizePath(sub("^--file=", "", args[grep("^--file=", args)])))
root <- normalizePath(file.path(script_dir, "..", ".."))
dd <- function(f) file.path(root, "public", "data", f)
rd <- function(f, ...) read_csv(dd(f), show_col_types = FALSE, progress = FALSE, ...)

results <- list()
check <- function(desc, code) {
  res <- tryCatch({ code; "ok" }, expectation_failure = function(e) conditionMessage(e),
                  error = function(e) paste("エラー:", conditionMessage(e)))
  results[[desc]] <<- res
  cat(if (identical(res, "ok")) "[ok]  " else "[NG]  ", desc,
      if (!identical(res, "ok")) paste0("\n      ", res) else "", "\n", sep = "")
}
show <- function(label, est, truth) cat(sprintf("      %s: 推定 %.4f（仕込んだ値 %s）\n", label, est, truth))

# ---- 行数 ----------------------------------------------------------------------
check("各ファイルの行数", {
  expected <- c(messy_survey = 500, ec_customers = 5000, ec_products = 200,
                ab_test = 20000, ab_test_srm = 20000, wage_survey = 3000,
                training_rct = 1000, training_obs = 4000, minwage_panel = 47 * 13,
                scholarship_rdd = 5000, store_sales_daily = 30 * 1096, churn = 5000,
                pref_basic = 47)
  for (nm in names(expected)) expect_equal(nrow(rd(paste0(nm, ".csv"))), expected[[nm]], label = nm)
  n_orders <- nrow(rd("ec_orders.csv"))
  expect_gt(n_orders, 55000); expect_lt(n_orders, 65000)
})

# ---- wage_survey ---------------------------------------------------------------
w <- rd("wage_survey.csv")
check("wage_survey: 生成式の係数と時給の中央値", {
  w$fs <- factor(w$firm_size, levels = c("〜29人", "30〜299人", "300〜999人", "1000人以上"))
  m <- lm(log_wage ~ educ_years + exper + I(exper^2) + tenure + female + fs + regular, data = w)
  b <- coef(m)
  show("educ_years", b["educ_years"], "0.07"); show("female", b["female"], "−0.12")
  show("exper", b["exper"], "0.035"); show("exper^2", b["I(exper^2)"], "−0.0006")
  show("1000人以上", b["fs1000人以上"], "0.18"); show("regular", b["regular"], "0.15")
  expect_equal(unname(b["educ_years"]), 0.07, tolerance = 0.01 / 0.07)
  expect_equal(unname(b["female"]), -0.12, tolerance = 0.03 / 0.12)
  expect_equal(unname(b["exper"]), 0.035, tolerance = 0.006 / 0.035)
  expect_equal(unname(b["I(exper^2)"]), -0.0006, tolerance = 0.00015 / 0.0006)
  expect_equal(unname(b["tenure"]), 0.01, tolerance = 0.004 / 0.01)
  expect_equal(unname(b["regular"]), 0.15, tolerance = 0.03 / 0.15)
  expect_equal(unname(b["fs1000人以上"]), 0.18, tolerance = 0.04 / 0.18)
  expect_equal(unname(b["fs300〜999人"]), 0.10, tolerance = 0.04 / 0.10)
  expect_equal(median(w$hourly_wage), 1900, tolerance = 20 / 1900)
  # 学歴の割合 35・20・40・5%
  sh <- prop.table(table(w$educ_years))
  expect_equal(as.numeric(sh), c(0.35, 0.20, 0.40, 0.05), tolerance = 0.03 / 0.2)
  # 不均一分散: 残差のばらつきが学歴とともに大きい
  sds <- tapply(resid(m), w$educ_years, sd)
  show("残差SD 12年", sds["12"], "0.25"); show("残差SD 18年", sds["18"], "0.37")
  expect_true(all(diff(sds) > 0))
  expect_equal(unname(sds["12"]), 0.25, tolerance = 0.03 / 0.25)
  expect_equal(unname(sds["18"]), 0.37, tolerance = 0.05 / 0.37)
  expect_true(all(w$exper >= 0), all(w$tenure <= w$exper))
})

# ---- training ------------------------------------------------------------------
check("training_rct: 処置効果 ≒ 30", {
  r <- rd("training_rct.csv")
  diff_mean <- mean(r$earn_post[r$treat == 1]) - mean(r$earn_post[r$treat == 0])
  adj <- coef(lm(earn_post ~ treat + prior_earn + educ_years + I((age - 35)^2) + female, data = r))["treat"]
  show("平均の差", diff_mean, "30"); show("共変量調整", adj, "30")
  expect_equal(diff_mean, 30, tolerance = 15 / 30)
  expect_equal(unname(adj), 30, tolerance = 10 / 30)
  expect_equal(sum(r$treat), 500)
})
check("training_obs: 単純比較は負、調整すると ≒ 30", {
  o <- rd("training_obs.csv")
  naive <- mean(o$earn_post[o$treat == 1]) - mean(o$earn_post[o$treat == 0])
  m <- lm(earn_post ~ treat + prior_earn + educ_years + I((age - 35)^2) + female, data = o)
  adj <- coef(m)["treat"]
  show("単純比較", naive, "負"); show("回帰で調整", adj, "30")
  expect_lt(naive, 0)
  expect_equal(unname(adj), 30, tolerance = 8 / 30)
  expect_equal(unname(coef(m)["prior_earn"]), 0.8, tolerance = 0.05 / 0.8)
  # 参加確率の式の係数
  ps <- coef(glm(treat ~ I(prior_earn - 250) + I(age - 35), family = binomial, data = o))
  show("logit 切片", ps[1], "−1"); show("logit 前年収入", ps[2], "−0.01")
  expect_equal(unname(ps[1]), -1, tolerance = 0.2)
  expect_equal(unname(ps[2]), -0.01, tolerance = 0.25)
  expect_equal(unname(ps[3]), -0.02, tolerance = 0.5)
})

# ---- minwage_panel -------------------------------------------------------------
p <- rd("minwage_panel.csv")
check("minwage_panel: 二元固定効果のDID（若年 ≒ −0.8±0.2、成人 ≒ 0）", {
  expect_equal(nrow(distinct(p, pref_code, year)), nrow(p))
  expect_equal(sum(p$treated[p$year == 2012]), 12)
  did_y <- coef(lm(youth_emp_rate ~ I(treated * post) + factor(pref_code) + factor(year), data = p))[2]
  did_a <- coef(lm(adult_emp_rate ~ I(treated * post) + factor(pref_code) + factor(year), data = p))[2]
  show("DID 若年", did_y, "−0.8±0.2（経過年の平均 −0.88）"); show("DID 成人（プラセボ）", did_a, "0")
  expect_gte(did_y, -1.0); expect_lte(did_y, -0.6)
  expect_lt(abs(did_a), 0.25)
  # イベントスタディ: 経過0年 −0.5、1年 −0.8、2年以降 −1.0、処置前は0
  p2 <- p |> mutate(rel = ifelse(treated == 1, year - 2019, -99))
  es <- coef(lm(youth_emp_rate ~ relevel(factor(rel), ref = "-1") + factor(pref_code) + factor(year),
                data = p2 |> mutate(rel = ifelse(rel == -99, -1, rel))))
  get <- function(k) unname(es[paste0('relevel(factor(rel), ref = "-1")', k)])
  show("経過0年", get(0), "−0.5"); show("経過1年", get(1), "−0.8"); show("経過5年", get(5), "−1.0")
  expect_equal(get(0), -0.5, tolerance = 0.5 / 0.5)
  expect_lt(mean(sapply(2:5, get)), -0.6)
  expect_lt(max(abs(sapply(-7:-2, get))), 0.6)
  # 2020年の全国一律の落ち込み（約 −2pt）
  ym <- tapply(p$youth_emp_rate[p$treated == 0], p$year[p$treated == 0], mean)
  expect_lt(ym["2020"] - (ym["2019"] + ym["2021"]) / 2, -1.5)
})

# ---- scholarship_rdd -----------------------------------------------------------
check("scholarship_rdd: GPA 3.0 での不連続 ≒ 25", {
  s <- rd("scholarship_rdd.csv")
  expect_true(all(s$scholarship == as.integer(s$gpa >= 3)))
  expect_true(all(s$gpa >= 0 & s$gpa <= 4))
  glob <- coef(lm(earn30 ~ I(gpa - 3) + scholarship, data = s))["scholarship"]
  loc <- coef(lm(earn30 ~ I(gpa - 3) * scholarship, data = filter(s, abs(gpa - 3) <= 0.5)))["scholarship"]
  show("全体の線形", glob, "25"); show("帯域0.5の局所線形", loc, "25")
  expect_equal(unname(glob), 25, tolerance = 10 / 25)
  expect_equal(unname(loc), 25, tolerance = 15 / 25)
})

# ---- A/B テスト ----------------------------------------------------------------
check("ab_test: 購入率 A 4.0%・B 5.2%、効果はスマホで大きい", {
  a <- rd("ab_test.csv")
  r <- tapply(a$converted, a$group, mean)
  show("A", r["A"], "0.040"); show("B", r["B"], "0.052")
  expect_equal(as.numeric(r), c(0.040, 0.052), tolerance = 0.002 / 0.04)
  expect_equal(as.numeric(table(a$group)), c(10000, 10000))
  lift <- with(a, tapply(converted, list(device, group), mean))
  expect_gt(lift["スマホ", "B"] - lift["スマホ", "A"], lift["PC", "B"] - lift["PC", "A"] + 0.005)
  # 売上は購入者だけ正、群で分布は同じ
  expect_true(all(a$revenue[a$converted == 0] == 0), all(a$revenue[a$converted == 1] > 0))
})
check("ab_test_srm: 51:49 の割当の崩れがカイ二乗検定で見つかる", {
  s <- rd("ab_test_srm.csv")
  tab <- table(s$group)
  expect_equal(as.numeric(tab), c(10200, 9800))
  expect_lt(chisq.test(tab, p = c(0.5, 0.5))$p.value, 0.01)
  expect_gt(chisq.test(table(rd("ab_test.csv")$group), p = c(0.5, 0.5))$p.value, 0.5)
})

# ---- EC --------------------------------------------------------------------------
orders <- rd("ec_orders.csv", col_types = cols(product_id = col_character()))
products <- rd("ec_products.csv", col_types = cols(product_id = col_character()))
customers <- rd("ec_customers.csv")
check("ec_products: 商品IDは先頭0の5桁。Excel版とread.csvでは数値になり0が消える", {
  expect_true(all(grepl("^0[0-9]{4}$", products$product_id)))
  expect_true(is.character(rd("ec_products.csv")$product_id))
  expect_true(is.numeric(utils::read.csv(dd("ec_products.csv"))$product_id))
  expect_equal(n_distinct(products$category), 8)
  expect_true(all(orders$product_id %in% products$product_id))
  x <- readxl::read_excel(dd("ec_products.xlsx"), sheet = "商品一覧")
  expect_equal(nrow(x), 200)
  expect_true(is.numeric(x$product_id))
  expect_equal(sprintf("%05d", as.integer(x$product_id)), products$product_id)
  expect_equal(readxl::excel_sheets(dd("ec_products.xlsx")), c("説明", "商品一覧"))
})
check("ec_orders: 顧客マスタにない注文が少数ある・pref_code は1〜47", {
  ghost <- anti_join(orders, customers, by = "customer_id")
  expect_gt(n_distinct(ghost$order_id), 0); expect_lt(n_distinct(ghost$order_id), 50)
  expect_true(all(customers$pref_code %in% 1:47))
  expect_true(all(orders$order_date >= as.Date("2024-01-01") & orders$order_date <= as.Date("2025-12-31")))
})
check("ec_orders: クーポンの価格弾力性 ≒ −1.5", {
  # 注文単位で無作為なので、クーポンあり・なしの平均数量の比から弾力性が出る
  agg <- orders |> group_by(product_id, coupon) |>
    summarise(q = mean(qty), p = mean(unit_price), n = n(), .groups = "drop")
  m <- lm(log(q) ~ log(p) + factor(product_id), data = agg, weights = n)
  el <- coef(m)["log(p)"]
  ratio <- log(mean(orders$qty[orders$coupon == 1]) / mean(orders$qty[orders$coupon == 0])) / log(0.8)
  show("弾力性（商品固定効果・対数-対数）", el, "−1.5"); show("弾力性（平均数量の比）", ratio, "−1.5")
  expect_equal(unname(el), -1.5, tolerance = 0.15 / 1.5)
  expect_equal(ratio, -1.5, tolerance = 0.2 / 1.5)
  cp <- orders |> distinct(order_id, coupon)
  expect_equal(mean(cp$coupon), 0.2, tolerance = 0.1)
  disc <- orders |> filter(coupon == 1) |> left_join(products, by = "product_id")
  expect_true(all(abs(disc$unit_price - disc$list_price * 0.8) <= 0.5))
})
check("ec_orders: 季節性（12月 +30%、8月 −10%）", {
  mo <- orders |> distinct(order_id, customer_id, order_date) |>
    semi_join(customers, by = "customer_id") |>
    count(m = floor_date(order_date, "month")) |>
    mutate(t = seq_along(m), mon = month(m))
  # 顧客数の増加（滑らかな趨勢）を3次式で除き、月の効果を見る
  fit <- lm(log(n) ~ poly(t, 3) + I(mon == 12) + I(mon == 8), data = mo)
  dec <- coef(fit)["I(mon == 12)TRUE"]; aug <- coef(fit)["I(mon == 8)TRUE"]
  show("12月 log", dec, sprintf("%.3f", log(1.3))); show("8月 log", aug, sprintf("%.3f", log(0.9)))
  expect_equal(unname(dec), log(1.3), tolerance = 0.08 / log(1.3))
  expect_equal(unname(aug), log(0.9), tolerance = 0.08 / abs(log(0.9)))
})
check("ec_orders: 2025年6月からのキャンペーン（10県、注文件数 +8%）", {
  camp <- c(4, 8, 9, 10, 22, 26, 28, 34, 40, 43)
  od <- orders |> distinct(order_id, customer_id, order_date) |>
    inner_join(customers |> select(customer_id, pref_code), by = "customer_id") |>
    mutate(treated = pref_code %in% camp, post = order_date >= as.Date("2025-06-01"),
           m = floor_date(order_date, "month")) |>
    count(treated, m, post)
  fit <- lm(log(n) ~ treated * post + factor(m), data = od)
  did <- coef(fit)["treatedTRUE:postTRUE"]
  show("DID（log 注文件数）", did, sprintf("%.3f", log(1.08)))
  expect_equal(unname(did), log(1.08), tolerance = 0.05 / log(1.08))
})
check("ec_customers: 年齢・流入経路で購買頻度が違う", {
  f <- orders |> count(customer_id, name = "k") |> right_join(customers, by = "customer_id")
  by_ch <- tapply(f$k, f$channel, mean)
  expect_gt(by_ch["紹介"], by_ch["広告"] * 1.2)
  by_age <- tapply(f$k, cut(f$age, c(0, 29, 49, 120)), mean)
  expect_gt(by_age[2], by_age[1])
})

# ---- churn -----------------------------------------------------------------------
check("churn: 解約率 ≒ 25%、ec_* の定義と一致", {
  ch <- rd("churn.csv")
  show("解約率", mean(ch$churned), "約0.25")
  expect_equal(mean(ch$churned), 0.25, tolerance = 0.03 / 0.25)
  q4 <- orders |> filter(order_date >= as.Date("2025-10-01")) |> distinct(customer_id)
  expect_equal(ch$churned, as.integer(!ch$customer_id %in% q4$customer_id))
  expect_true(all(ch$frequency >= 1), all(ch$recency >= 0))
  # 最近買っていない顧客ほど解約しやすい
  expect_gt(coef(glm(churned ~ recency + frequency, family = binomial, data = ch))["recency"], 0)
})

# ---- store_sales_daily ---------------------------------------------------------
check("store_sales_daily: 気温 +1%/℃、祝日 +15%、雨 −10%", {
  s <- rd("store_sales_daily.csv")
  m <- lm(log(sales) ~ temp + holiday + rain + factor(wday(date)) + factor(month(date)) +
            factor(year(date)) + store_id, data = s)
  b <- coef(m)
  show("temp", b["temp"], sprintf("%.4f", log(1.01)))
  show("holiday", b["holiday"], sprintf("%.4f", log(1.15)))
  show("rain", b["rain"], sprintf("%.4f", log(0.90)))
  expect_equal(unname(b["temp"]), log(1.01), tolerance = 0.002 / 0.01)
  expect_equal(unname(b["holiday"]), log(1.15), tolerance = 0.02 / 0.14)
  expect_equal(unname(b["rain"]), log(0.90), tolerance = 0.01 / 0.105)
  expect_equal(n_distinct(s$store_id), 30)
  expect_true(all(s$pref_code %in% 1:47))
  # 店舗は sora_stores の店。2025年の合計は sora_stores の今年の売上（万円）に一致する
  sora <- rd("sora_stores.csv")
  expect_true(all(s$store_id %in% sora$store_id))
  tot <- s |> filter(year(date) == 2025) |> group_by(store_id) |> summarise(y = sum(sales) / 10000) |>
    inner_join(sora, by = "store_id")
  expect_equal(tot$y, tot$sales, tolerance = 1e-4)
  last <- s |> filter(year(date) == 2024) |> group_by(store_id) |> summarise(y = sum(sales) / 10000) |>
    inner_join(sora, by = "store_id")
  show("2024年合計 / sales_last の最大のずれ", max(abs(last$y / last$sales_last - 1)), "小さい")
})

# ---- sora_stores ---------------------------------------------------------------
check("sora_stores: 客単価の地域差・立地差、前年割れは中国・四国に偏る、全社の客単価 > 単純平均", {
  d <- rd("sora_stores.csv") |>
    mutate(spend = sales * 10000 / customers, eff = sales / floor_m2, decline = sales < sales_last)
  expect_equal(nrow(d), 50)
  expect_equal(n_distinct(d$store_id), 50)
  by_region <- d |> group_by(region) |> summarise(spend = mean(spend), decline = mean(decline))
  expect_equal(by_region$region[which.max(by_region$spend)], "関東")
  expect_equal(by_region$region[which.max(by_region$decline)], "中国・四国")
  by_loc <- d |> group_by(location) |> summarise(spend = mean(spend), eff = mean(eff))
  expect_equal(by_loc$location[which.max(by_loc$spend)], "郊外")
  expect_equal(by_loc$location[which.max(by_loc$eff)], "駅前")
  expect_true(sum(d$decline) >= 10 && sum(d$decline) <= 20)
  company <- sum(d$sales) * 10000 / sum(d$customers)
  expect_gt(company - mean(d$spend), 20)
  m <- lm(spend ~ relevel(factor(region), "中部") + relevel(factor(location), "駅前"), data = d)
  show("郊外の上乗せ（対 駅前）", coef(m)[["relevel(factor(location), \"駅前\")郊外"]], "+600")
  show("関東の上乗せ（対 中部）", coef(m)[["relevel(factor(region), \"中部\")関東"]], "+300")
  show("全社の客単価 − 単純平均", company - mean(d$spend), "正")
  expect_equal(coef(m)[["relevel(factor(location), \"駅前\")郊外"]], 600, tolerance = 0.2)
  expect_equal(coef(m)[["relevel(factor(region), \"中部\")関東"]], 300, tolerance = 0.4)
})

# ---- messy_survey --------------------------------------------------------------
check("messy_survey: わざと汚い（全角・表記ゆれ・欠損表記・シリアル値）", {
  m <- read_csv(dd("messy_survey.csv"), col_types = cols(.default = col_character()))
  expect_equal(names(m), c("回答ID", "年代", "性別", "来店回数", "購入金額", "回答日"))
  expect_true(all(c("男", "男性", "M", "女", "女性", "F") %in% m$性別))
  expect_true(any(m$来店回数 %in% c("-", "不明")) && any(m$購入金額 %in% c("-", "不明")))
  expect_true(any(grepl("[０-９]", m$年代)) && any(grepl("[０-９]", m$購入金額)))
  expect_true(any(grepl("円$", m$購入金額)) && any(grepl("回$", m$来店回数)))
  d <- as.Date(as.numeric(m$回答日), origin = "1899-12-30")
  expect_true(all(is.na(d) | (d >= as.Date("2025-04-01") & d <= as.Date("2025-05-31"))))
  clean <- suppressWarnings(readr::parse_number(stringi::stri_trans_nfkc(m$購入金額)))
  expect_true(mean(clean, na.rm = TRUE) > 2500 && mean(clean, na.rm = TRUE) < 4000)
})

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- コードブック --------------------------------------------------------------
check("コードブック: 行数と列名がCSVと一致する", {
  for (f in list.files(dd("codebook"), pattern = "\\.yaml$", full.names = TRUE)) {
    cb <- yaml::read_yaml(f)
    nm <- sub("\\.yaml$", "", basename(f))
    if (identical(cb$format, "json")) {
      # API の応答をそのまま保存したファイル（estat_sample）：値の表を比べる
      x <- jsonlite::fromJSON(dd(cb$file))$GET_STATS_DATA$STATISTICAL_DATA$DATA_INF$VALUE
    } else if (grepl("^CP932", cb$encoding %||% "")) {
      # 公式の表の体裁を残したファイル（kakei_raw_sjis）：見出しの行（5行目の次）を列名にし、都市の行だけを比べる
      x <- suppressWarnings(read_csv(dd(paste0(nm, ".csv")), locale = locale(encoding = "CP932"), skip = 5,
                    col_types = cols(.default = col_character())))
      x <- x[grepl("^[0-9]{5} ", x[[1]]), ]
    } else {
      x <- read_csv(dd(paste0(nm, ".csv")), col_types = cols(.default = col_character()))
    }
    expect_equal(nrow(x), as.integer(cb$rows), label = paste(nm, "rows"))
    expect_equal(vapply(cb$columns, `[[`, "", "name"), names(x), label = paste(nm, "columns"))
    expect_true(all(vapply(cb$columns, function(z) nzchar(z$description) && nzchar(z$unit), TRUE)))
  }
})

# ---- 結果 ------------------------------------------------------------------------
n_ng <- sum(results != "ok")
cat(sprintf("\n%d件中 %d件 合格、%d件 不合格\n", length(results), length(results) - n_ng, n_ng))
if (n_ng > 0) quit(status = 1)
