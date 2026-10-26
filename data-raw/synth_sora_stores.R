# sora_stores.csv を作る。架空の企業「そらまめマーケット」が運営する食品スーパー50店舗の年次データ。
# 第1部（ステップ3〜9）で使う。
#
# 仕込んだ「答え」（tests/r/test_synth.R で確かめる）
#   - 客単価（円）= 2,000 + 地域の上乗せ + 立地の上乗せ + 誤差
#       地域: 関東 +300、近畿 +150、中部 0、北海道・東北 −100、中国・四国 −150、九州・沖縄 −200
#       立地: 郊外 +400（まとめ買い）、商業施設 +100、駅前 −200
#   - 今年の売上の伸び（前年比）= +3% + 誤差。ただし中国・四国は −4%、2005年以前に開いた店は −2% を上乗せ
#     → 前年割れは十数店で、中国・四国に偏る
#   - 郊外店は売場が広く客単価が高いが、売場1m²あたり売上（売場効率）は駅前店より低い
#   - 大型店ほど客数が多いので、全社の客単価（売上合計 ÷ 客数合計）は店舗の客単価の単純平均より高い
#
#   Rscript data-raw/synth_sora_stores.R

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
})
set.seed(108)

stores <- tribble(
  ~region,        ~pref,      ~area,
  "北海道・東北", "北海道",   c("札幌北口", "旭川", "函館"),
  "北海道・東北", "宮城県",   c("仙台駅前", "名取"),
  "北海道・東北", "福島県",   c("郡山"),
  "関東",         "東京都",   c("新宿西口", "池袋", "町田", "立川", "吉祥寺"),
  "関東",         "神奈川県", c("横浜駅前", "川崎", "藤沢", "相模原"),
  "関東",         "埼玉県",   c("大宮", "川越", "越谷"),
  "関東",         "千葉県",   c("船橋", "柏"),
  "中部",         "愛知県",   c("名古屋栄", "豊橋", "岡崎", "一宮"),
  "中部",         "静岡県",   c("静岡駅前", "浜松"),
  "中部",         "新潟県",   c("新潟"),
  "中部",         "長野県",   c("松本"),
  "中部",         "石川県",   c("金沢"),
  "近畿",         "大阪府",   c("梅田", "難波", "堺", "枚方"),
  "近畿",         "京都府",   c("京都四条", "宇治"),
  "近畿",         "兵庫県",   c("三宮", "姫路", "西宮"),
  "中国・四国",   "広島県",   c("広島紙屋町", "福山"),
  "中国・四国",   "岡山県",   c("岡山"),
  "中国・四国",   "山口県",   c("下関"),
  "中国・四国",   "香川県",   c("高松"),
  "中国・四国",   "愛媛県",   c("松山"),
  "九州・沖縄",   "福岡県",   c("天神", "博多", "北九州"),
  "九州・沖縄",   "熊本県",   c("熊本"),
  "九州・沖縄",   "鹿児島県", c("鹿児島"),
  "九州・沖縄",   "沖縄県",   c("那覇")
) |>
  tidyr::unnest(area)
stopifnot(nrow(stores) == 50)

n <- nrow(stores)
location <- sample(c("駅前", "郊外", "商業施設"), n, replace = TRUE, prob = c(0.35, 0.40, 0.25))
# 名前に「駅前」「口」が付く店は駅前に揃える
location[grepl("駅前|口$", stores$area)] <- "駅前"

floor_m2 <- round(case_when(
  location == "駅前" ~ runif(n, 500, 1100),
  location == "郊外" ~ runif(n, 1500, 3000),
  TRUE ~ runif(n, 800, 1500)
), -1)
open_year <- sample(1995:2022, n, replace = TRUE)
staff <- round(floor_m2 / 45 + rnorm(n, 0, 3))

region_eff <- c("関東" = 300, "近畿" = 150, "中部" = 0, "北海道・東北" = -100,
                "中国・四国" = -150, "九州・沖縄" = -200)
loc_eff <- c("郊外" = 400, "商業施設" = 100, "駅前" = -200)
spend <- 2000 + region_eff[stores$region] + loc_eff[location] + rnorm(n, 0, 120)

# 客数（人/年）: 駅前は面積の割に客が多いが、郊外の大型店は店あたりの客数が最も多い
cust_per_m2 <- c("駅前" = 480, "郊外" = 280, "商業施設" = 330)[location]
customers <- round(floor_m2 * cust_per_m2 * exp(rnorm(n, 0, 0.12)), -2)
sales <- round(customers * spend / 10000)               # 万円

growth <- 0.03 + rnorm(n, 0, 0.03) -
  0.04 * (stores$region == "中国・四国") -
  0.02 * (open_year <= 2005)
sales_last <- round(sales / (1 + growth))

sora_stores <- tibble(
  store_id = sprintf("S%02d", seq_len(n)),
  store_name = paste0(stores$area, "店"),
  region = stores$region,
  pref = stores$pref,
  location = location,
  open_year = open_year,
  floor_m2 = floor_m2,
  staff = as.integer(staff),
  customers = as.integer(customers),
  sales = as.integer(sales),
  sales_last = as.integer(sales_last)
)

write_csv(sora_stores, "public/data/sora_stores.csv")
cat("sora_stores:", nrow(sora_stores), "行、前年割れ",
    sum(sora_stores$sales < sora_stores$sales_last), "店\n")
