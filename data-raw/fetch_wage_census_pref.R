# wage_census_pref.csv を、保存済みの e-Stat 公表ファイル（Excel）から作る。通信はしない。
#   出力: public/data/wage_census_pref.csv
#         列: pref_code, year, sex（"男女計" / "男" / "女"）, scheduled_wage（千円/月）, hours（時間/月）
#         47都道府県 × 3（男女計・男・女）× 2019〜2025年 = 987行
#   実行: Rscript data-raw/fetch_wage_census_pref.R（プロジェクトのルートで。readxl, readr を使う）
#   出所: 厚生労働省「賃金構造基本統計調査」（e-Stat 掲載ファイル）。
#         元ファイルと表番号・URL・取得日は data-raw/raw/wage_census_pref/SOURCES.md
#   対象: 一般労働者、企業規模計（10人以上）、産業計、学歴計、年齢計。各年6月分の賃金・労働時間
#
# 年ごとの元ファイル
#   2020〜2025年: 都道府県別 参考表1「性、都道府県別きまって支給する現金給与額、所定内給与額及び
#                 年間賞与その他特別給与額（47都道府県一覧）」（sanko1_YYYY.xls(x)。シート「男女計」「男女別」）
#   2019年      : 【参考掲載】令和２年調査と同じ推計方法を用いた過去分の集計 の
#                 都道府県別第1表（2019_recomputed_table1/ の24ファイル。各県の「産業計」シートの
#                 企業規模計（10人以上）・年齢計の行）。2020年以降と同じ推計方法の値を使う
#   参考        : 2019年の旧推計方法による参考表1（sanko1_2019_old_method.xls）は CSV に使わず、
#                 新旧の差を表示するだけに読む
#
# 値は元ファイルの数値をそのまま使う（所定内給与額は0.1千円単位、所定内実労働時間数は1時間単位）。

library(readxl)

raw_dir <- file.path("data-raw", "raw", "wage_census_pref")
out_file <- file.path("public", "data", "wage_census_pref.csv")

# JIS X 0401 の順。元ファイルの表記（「青　森」「北海道」「東京都」など）は空白と末尾の都府県を落として照合する
pref_names <- c("北海道", "青森", "岩手", "宮城", "秋田", "山形", "福島", "茨城", "栃木", "群馬",
                "埼玉", "千葉", "東京", "神奈川", "新潟", "富山", "石川", "福井", "山梨", "長野",
                "岐阜", "静岡", "愛知", "三重", "滋賀", "京都", "大阪", "兵庫", "奈良", "和歌山",
                "鳥取", "島根", "岡山", "広島", "山口", "徳島", "香川", "愛媛", "高知", "福岡",
                "佐賀", "長崎", "熊本", "大分", "宮崎", "鹿児島", "沖縄")

clean <- function(x) gsub("[[:space:]　\r\n]", "", x)
short_pref <- function(x) {
  x <- clean(x)
  # 「京都」「東京」のように県名がもともと都・府で終わる表記は削らない
  ifelse(x %in% pref_names, x, sub("(都|府|県)$", "", x))
}
num <- function(x) as.numeric(clean(x))

read_text <- function(path, sheet) {
  d <- read_excel(path, sheet = sheet, col_names = FALSE, col_types = "text", .name_repair = "minimal")
  d <- as.data.frame(d, stringsAsFactors = FALSE)
  names(d) <- paste0("c", seq_len(ncol(d)))
  d
}

# 見出しのセルが想定どおりか確かめる（列の位置がずれていたら止める）
expect_header <- function(d, row, col, pattern, what) {
  v <- clean(d[row, col])
  if (is.na(v) || !grepl(pattern, v)) {
    stop(what, ": ", row, "行", col, "列が「", pattern, "」ではありません（", v, "）", call. = FALSE)
  }
}

# ---- 2020〜2025年: 参考表1（47都道府県一覧） ----------------------------------------------
# シート「男女計」: 4列目=年齢 … 7列目=所定内実労働時間数, 10列目=所定内給与額
# シート「男女別」: 男 7列目・10列目、女 15列目・18列目
read_sanko1 <- function(path, year) {
  what <- basename(path)
  pick <- function(d, hours_col, wage_col, sex) {
    expect_header(d, 1, 5, paste0(c("令和２年", "令和３年", "令和４年", "令和５年", "令和６年", "令和７年")[year - 2019],
                                  "賃金構造基本統計調査"), what)
    expect_header(d, 7, hours_col, "^所定内実労働時間数$", what)
    expect_header(d, 9, wage_col, "^所定内給与額$", what)
    expect_header(d, 11, hours_col, "^時間$", what)
    expect_header(d, 11, wage_col, "^千円$", what)
    rows <- which(short_pref(d$c3) %in% pref_names)
    data.frame(pref_code = match(short_pref(d$c3[rows]), pref_names), year = year, sex = sex,
               scheduled_wage = num(d[rows, wage_col]), hours = num(d[rows, hours_col]))
  }
  total <- read_text(path, "男女計")
  bysex <- read_text(path, "男女別")
  expect_header(total, 6, 5, "^男女計$", what)
  expect_header(bysex, 6, 5, "^男$", what)
  expect_header(bysex, 6, 13, "^女$", what)
  rbind(pick(total, 7, 10, "男女計"), pick(bysex, 7, 10, "男"), pick(bysex, 15, 18, "女"))
}

# 全国の行（検算用）
read_sanko1_national <- function(path) {
  total <- read_text(path, "男女計")
  bysex <- read_text(path, "男女別")
  r1 <- which(clean(total$c3) == "全国")
  r2 <- which(clean(bysex$c3) == "全国")
  data.frame(sex = c("男女計", "男", "女"),
             national_wage = c(num(total[r1, 10]), num(bysex[r2, 10]), num(bysex[r2, 18])),
             national_hours = c(num(total[r1, 7]), num(bysex[r2, 7]), num(bysex[r2, 15])))
}

# ---- 2019年: 令和２年と同じ推計方法による集計（都道府県別第1表） ---------------------------
# 各県の「NN-01<県名>産業計」シート。3列目=年齢, 5列目=所定内実労働時間数, 8列目=所定内給与額
# （企業規模計（10人以上）の列）。行は「男女計」「男」「女」の年齢計
read_recomputed_2019 <- function(dir) {
  files <- sort(list.files(dir, pattern = "^table1_2019_recomputed_.*\\.xlsx$", full.names = TRUE))
  if (length(files) != 24) stop(dir, " のファイルが24個ではありません（", length(files), "個）", call. = FALSE)
  out <- list()
  for (f in files) {
    sheets <- grep("^[0-9]{2}-01.*産業計$", excel_sheets(f), value = TRUE)
    for (s in sheets) {
      code <- as.integer(substr(s, 1, 2))
      d <- read_text(f, s)
      what <- paste(basename(f), s)
      expect_header(d, 1, 3, "^令和元年賃金構造基本統計調査【令和２年調査と同じ推計方法による集計】$", what)
      expect_header(d, 6, 3, "^産業計$", what)
      expect_header(d, 8, 3, "^企業規模計（10人以上）$", what)
      expect_header(d, 9, 5, "^所定内実労働時間数$", what)
      expect_header(d, 10, 8, "^所定内給与額$", what)
      if (short_pref(d[5, 3]) != pref_names[code]) stop(what, ": 県名が一致しません", call. = FALSE)
      lab <- clean(d$c2)
      rows <- c(男女計 = which(lab == "男女計")[1], 男 = which(lab == "男")[1], 女 = which(lab == "女")[1])
      if (anyNA(rows)) stop(what, ": 男女計・男・女の行が見つかりません", call. = FALSE)
      out[[length(out) + 1]] <- data.frame(pref_code = code, year = 2019L, sex = names(rows),
                                           scheduled_wage = num(d[rows, 8]), hours = num(d[rows, 5]))
    }
  }
  do.call(rbind, out)
}

# ---- 組み立て ----------------------------------------------------------------------------------
sanko1_files <- c(`2020` = "sanko1_2020.xls", `2021` = "sanko1_2021.xlsx", `2022` = "sanko1_2022.xlsx",
                  `2023` = "sanko1_2023.xlsx", `2024` = "sanko1_2024.xlsx", `2025` = "sanko1_2025.xlsx")

parts <- list(read_recomputed_2019(file.path(raw_dir, "2019_recomputed_table1")))
for (y in names(sanko1_files)) {
  parts[[y]] <- read_sanko1(file.path(raw_dir, sanko1_files[[y]]), as.integer(y))
}
wage_census_pref <- do.call(rbind, parts)
wage_census_pref$year <- as.integer(wage_census_pref$year)
wage_census_pref$pref_code <- as.integer(wage_census_pref$pref_code)
wage_census_pref$hours <- as.integer(wage_census_pref$hours)
wage_census_pref$sex <- factor(wage_census_pref$sex, levels = c("男女計", "男", "女"))
wage_census_pref <- wage_census_pref[order(wage_census_pref$year, wage_census_pref$pref_code, wage_census_pref$sex), ]
wage_census_pref$sex <- as.character(wage_census_pref$sex)
rownames(wage_census_pref) <- NULL

# ---- 検算 --------------------------------------------------------------------------------------
years <- 2019:2025
stopifnot(
  nrow(wage_census_pref) == 47 * 3 * length(years),
  !anyNA(wage_census_pref),
  !anyDuplicated(wage_census_pref[c("pref_code", "year", "sex")]),
  all(table(wage_census_pref$year, wage_census_pref$sex) == 47),
  setequal(wage_census_pref$pref_code, 1:47),
  all(wage_census_pref$scheduled_wage > 150 & wage_census_pref$scheduled_wage < 500),
  all(wage_census_pref$hours > 140 & wage_census_pref$hours < 185)
)
wide <- reshape(wage_census_pref[c("pref_code", "year", "sex", "scheduled_wage")],
                idvar = c("pref_code", "year"), timevar = "sex", direction = "wide")
# どの県・年でも 女 < 男女計 < 男
stopifnot(all(wide$scheduled_wage.女 < wide$scheduled_wage.男女計),
          all(wide$scheduled_wage.男女計 < wide$scheduled_wage.男))

# 全国値（公表値）と、47県の値の範囲・単純平均を並べる
# 2019年の全国値は、同じ【参考掲載】の第1表（産業計シート、民営事業所・企業規模計（10人以上）・学歴計）から読む
read_national_2019 <- function(path) {
  d <- read_text(path, "産業計")
  expect_header(d, 1, 3, "令和２年調査と同じ推計方法による集計", basename(path))
  expect_header(d, 8, 3, "^企業規模計（10人以上）$", basename(path))
  lab <- clean(d$c2)
  rows <- c(which(lab == "男女計学歴計")[1], which(lab == "男学歴計")[1], which(lab == "女学歴計")[1])
  data.frame(sex = c("男女計", "男", "女"), national_wage = num(d[rows, 8]), national_hours = num(d[rows, 5]))
}

cat("全国（公表値）と47都道府県の所定内給与額（千円）・所定内実労働時間数（男女計）\n")
for (y in c("2019", names(sanko1_files))) {
  nat <- if (y == "2019") read_national_2019(file.path(raw_dir, "national_2019_recomputed_table1.xlsx")) else
    read_sanko1_national(file.path(raw_dir, sanko1_files[[y]]))
  sub <- wage_census_pref[wage_census_pref$year == as.integer(y) & wage_census_pref$sex == "男女計", ]
  cat(sprintf("  %s年 全国 %.1f（男 %.1f, 女 %.1f）  47県 最小 %.1f 最大 %.1f 単純平均 %.1f  時間 全国 %d 県 %d〜%d\n",
              y, nat$national_wage[1], nat$national_wage[2], nat$national_wage[3],
              min(sub$scheduled_wage), max(sub$scheduled_wage), mean(sub$scheduled_wage),
              as.integer(nat$national_hours[1]), min(sub$hours), max(sub$hours)))
  stopifnot(min(sub$scheduled_wage) < nat$national_wage[1], nat$national_wage[1] < max(sub$scheduled_wage))
}

# 2019年: 旧推計方法の参考表1との差（参考表示のみ。CSVには新推計方法の値を使う）
old2019 <- read_text(file.path(raw_dir, "sanko1_2019_old_method.xls"), "男女計")
expect_header(old2019, 1, 5, "^令和元年賃金構造基本統計調査$", "sanko1_2019_old_method.xls")
old_rows <- which(short_pref(old2019$c3) %in% pref_names)
old_tot <- data.frame(pref_code = match(short_pref(old2019$c3[old_rows]), pref_names),
                      old = num(old2019[old_rows, 10]))
new_tot <- wage_census_pref[wage_census_pref$year == 2019 & wage_census_pref$sex == "男女計", ]
cmp <- merge(new_tot, old_tot, by = "pref_code")
cat(sprintf("2019年 男女計: 新推計 − 旧推計 の差 最小 %.1f 最大 %.1f 平均 %.2f 千円（旧推計の全国 %.1f）\n",
            min(cmp$scheduled_wage - cmp$old), max(cmp$scheduled_wage - cmp$old),
            mean(cmp$scheduled_wage - cmp$old), num(old2019[which(clean(old2019$c3) == "全国"), 10])))

readr::write_csv(wage_census_pref, out_file)
cat(out_file, "を書き出しました（", nrow(wage_census_pref), "行）\n")
