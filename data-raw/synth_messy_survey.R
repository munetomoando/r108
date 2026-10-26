# そらまめマーケットの来店客アンケート（500件）を「わざと汚く」作る。第12ステップの掃除の練習用。
#   店頭の紙のアンケートを、複数の担当者が表計算ソフトに手入力した、という設定
#   出力: public/data/messy_survey.csv
#   実行: Rscript data-raw/synth_messy_survey.R
#
# 汚し方
#   - 全角数字が混じる（"３０代"、"４"、"３５００"）
#   - 性別の表記ゆれ: 男 / 男性 / M / Ｍ、女 / 女性 / F / Ｆ、その他
#   - 欠損の表記がばらばら: "-"、"不明"、空欄
#   - 単位つき・桁区切りつき: "4回"、"3,500円"
#   - 回答日は Excel の日付シリアル値（例: 45762 = 2025-04-15）。一部空欄
#   列名は日本語（回答ID, 年代, 性別, 来店回数, 購入金額, 回答日）
#   来店回数は1か月の来店回数、購入金額は1回の買い物の金額（円）
suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

n <- 500
zen <- function(x) chartr("0123456789", "０１２３４５６７８９", x)
maybe_zen <- function(x, p) ifelse(runif(length(x)) < p, zen(x), x)
put_missing <- function(x, p) {
  u <- runif(length(x))
  ifelse(u < p / 3, "-", ifelse(u < 2 * p / 3, "不明", ifelse(u < p, NA, x)))
}

# 真の値
age_group <- sample(seq(20, 70, by = 10), n, replace = TRUE, prob = c(0.10, 0.17, 0.21, 0.20, 0.17, 0.15))
sex <- sample(c("男性", "女性", "その他"), n, replace = TRUE, prob = c(0.38, 0.59, 0.03))
visits <- pmin(20, pmax(1, round(rlnorm(n, log(5), 0.6))))                    # 回/月
spend <- round(pmax(500, rlnorm(n, log(3000), 0.45)), -2)                     # 円/回
answer_date <- as.Date("2025-04-07") + sample(0:30, n, replace = TRUE)

# 汚す
age_txt <- sample(c("代", "歳代", "代以上"), n, replace = TRUE, prob = c(0.6, 0.35, 0.05))
age_txt[age_group != 70] <- sub("以上", "", age_txt[age_group != 70])
age_s <- maybe_zen(paste0(age_group, age_txt), 0.3)
age_s <- put_missing(age_s, 0.02)

male_v <- sample(c("男", "男性", "M", "Ｍ"), n, replace = TRUE, prob = c(0.35, 0.40, 0.20, 0.05))
female_v <- sample(c("女", "女性", "F", "Ｆ"), n, replace = TRUE, prob = c(0.35, 0.40, 0.20, 0.05))
sex_s <- ifelse(sex == "男性", male_v, ifelse(sex == "女性", female_v, "その他"))
sex_s <- put_missing(sex_s, 0.05)

visits_s <- as.character(visits)
visits_s <- ifelse(runif(n) < 0.25, paste0(visits_s, "回"), visits_s)
visits_s <- maybe_zen(visits_s, 0.2)
visits_s <- put_missing(visits_s, 0.06)

spend_s <- ifelse(runif(n) < 0.25,
                  paste0(formatC(spend, format = "d", big.mark = ","), "円"),
                  as.character(spend))
spend_s <- maybe_zen(spend_s, 0.15)
spend_s <- put_missing(spend_s, 0.08)

serial <- as.character(as.integer(answer_date - as.Date("1899-12-30")))
serial[runif(n) < 0.02] <- NA

messy <- tibble(回答ID = sprintf("R%03d", seq_len(n)), 年代 = age_s, 性別 = sex_s,
                来店回数 = visits_s, 購入金額 = spend_s, 回答日 = serial)

write_csv(messy, "public/data/messy_survey.csv", na = "")
cat("messy_survey:", nrow(messy), "行（性別の表記", length(unique(na.omit(sex_s))), "通り）\n")
