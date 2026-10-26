# min_wage_pref.csv を作る（47都道府県×2002〜2025年度の地域別最低賃金）。
#   出力: public/data/min_wage_pref.csv（列: pref_code, fiscal_year, min_wage（円/時）, effective_date）
#   実行: Rscript data-raw/fetch_min_wage_pref.R   （プロジェクトのルートで。通信はしない）
#   出所: 厚生労働省「平成14年度から令和８年度までの地域別最低賃金改定状況」（Excel）
#         https://www.mhlw.go.jp/content/11200000/001756130.xlsx （2026-10-23 取得）
#         照合用に、1年前の版「平成14年度から令和７年度まで…」（001571219.xlsx）と
#         「令和７年度地域別最低賃金全国一覧」（001571192.pdf）も保存してある。
#         詳細は data-raw/raw/min_wage_pref/SOURCES.md
#   加工: 横持ち（年度ごとに「改定額」「発効年月日」の2列）を縦持ちにし、2002〜2025年度だけを残す。
#         発効年月日は、平成30年度までが Excel の日付シリアル値（1900年方式）、令和元年度以降が日付型で
#         入っているので、どちらも Date に直す。改定が無かった年度（例: 2003年度の多くの県、
#         2020年度の東京など）は、元資料どおり前年度と同じ額・同じ発効日が入る。
#         都道府県は元資料の行順（JIS順）で 1〜47 を振り、県名で照合して確かめる。
#   値は元資料から機械的に読むだけで、手入力・推測による補完はしない。
suppressPackageStartupMessages({
  library(readxl)
  library(dplyr)
})

raw_dir   <- "data-raw/raw/min_wage_pref"
main_xlsx <- file.path(raw_dir, "mhlw_001756130_H14-R8_kaitei.xlsx")  # 主資料（H14〜R8）
prev_xlsx <- file.path(raw_dir, "mhlw_001571219_H14-R7_kaitei.xlsx")  # 照合用（H14〜R7）
years     <- 2002:2025

pref_names <- c("北海道", "青森", "岩手", "宮城", "秋田", "山形", "福島", "茨城", "栃木", "群馬",
                "埼玉", "千葉", "東京", "神奈川", "新潟", "富山", "石川", "福井", "山梨", "長野",
                "岐阜", "静岡", "愛知", "三重", "滋賀", "京都", "大阪", "兵庫", "奈良", "和歌山",
                "鳥取", "島根", "岡山", "広島", "山口", "徳島", "香川", "愛媛", "高知", "福岡",
                "佐賀", "長崎", "熊本", "大分", "宮崎", "鹿児島", "沖縄")

# 1セルを Date に直す（Excel シリアル値 or POSIXct）
cell_to_date <- function(x) {
  if (inherits(x, "POSIXct")) return(as.Date(format(x, "%Y-%m-%d")))
  if (is.numeric(x)) return(as.Date(x, origin = "1899-12-30"))
  stop("発効年月日として読めないセルがあります: ", format(x), call. = FALSE)
}

# 改定状況の Excel を縦持ちの data.frame にする
read_kaitei <- function(path) {
  if (!file.exists(path)) stop("元資料がありません: ", path, call. = FALSE)
  x <- read_excel(path, sheet = 1, col_names = FALSE, col_types = "list", .name_repair = "minimal")
  hdr <- vapply(x[1, ], function(v) if (is.null(v) || all(is.na(v))) NA_character_ else as.character(v), "")
  # 年度見出し（"平成14年度" "令和元年度" など）を西暦に直す
  to_year <- function(s) {
    s <- chartr("０１２３４５６７８９", "0123456789", s)
    era <- substr(s, 1, 2)
    n <- sub("^..(元|[0-9]+)年度$", "\\1", s)
    n <- ifelse(n == "元", "1", n)
    ifelse(era == "平成", 1988L, ifelse(era == "令和", 2018L, NA_integer_)) + suppressWarnings(as.integer(n))
  }
  yr_cols <- which(!is.na(hdr) & grepl("年度$", hdr) & hdr != "年度")
  yr_of   <- to_year(hdr[yr_cols])
  if (anyNA(yr_of)) stop("年度見出しを読めません: ", path, call. = FALSE)

  # 都道府県の行（3行目〜49行目）。県名の空白を除いて照合する
  rows <- 3:49
  nm <- gsub("[[:space:]　]", "", vapply(x[[1]][rows], as.character, ""))
  if (!identical(nm, pref_names)) stop("都道府県の並びが想定（JIS順）と違います: ", path, call. = FALSE)

  out <- lapply(seq_along(yr_cols), function(k) {
    j <- yr_cols[k]
    amt <- x[[j]][rows]; eff <- x[[j + 1]][rows]
    data.frame(pref_code   = 1:47,
               fiscal_year = yr_of[k],
               min_wage    = vapply(amt, function(v) as.numeric(v), 0),
               effective_date = do.call(c, lapply(eff, cell_to_date)))
  })
  avg <- vapply(yr_cols, function(j) as.numeric(x[[j]][[50]]), 0)  # 全国加重平均額（50行目）
  stopifnot(grepl("全国加重平均", as.character(x[[1]][[50]])))
  list(data = bind_rows(out), wavg = setNames(avg, yr_of))
}

main <- read_kaitei(main_xlsx)
prev <- read_kaitei(prev_xlsx)

min_wage_pref <- main$data |>
  filter(fiscal_year %in% years) |>
  arrange(pref_code, fiscal_year) |>
  mutate(pref_code = as.integer(pref_code), fiscal_year = as.integer(fiscal_year),
         min_wage = as.integer(min_wage))

# ---- 検算 ----
stopifnot(nrow(min_wage_pref) == 47 * length(years),
          !anyNA(min_wage_pref),
          all(min_wage_pref$min_wage == main$data$min_wage[match(
            paste(min_wage_pref$pref_code, min_wage_pref$fiscal_year),
            paste(main$data$pref_code, main$data$fiscal_year))]))
mono <- min_wage_pref |> group_by(pref_code) |>
  summarise(ok_wage = all(diff(min_wage) >= 0), ok_date = all(diff(effective_date) >= 0))
if (!all(mono$ok_wage)) stop("年度とともに額が下がる県があります", call. = FALSE)
if (!all(mono$ok_date)) stop("年度とともに発効日が戻る県があります", call. = FALSE)

# 1年前の版（H14〜R7）と 2002〜2025年度の全セルが一致するか
chk <- inner_join(min_wage_pref, prev$data, by = c("pref_code", "fiscal_year"), suffix = c("", ".prev"))
stopifnot(nrow(chk) == nrow(min_wage_pref))
if (any(chk$min_wage != chk$min_wage.prev) || any(chk$effective_date != chk$effective_date.prev)) {
  print(filter(chk, min_wage != min_wage.prev | effective_date != effective_date.prev))
  stop("新旧の改定状況の表で値が食い違います", call. = FALSE)
}

# 全国加重平均額（公表値）が、県の額の範囲に収まるか（ウエイトが無いので厳密な再計算はしない）
rng <- min_wage_pref |> group_by(fiscal_year) |>
  summarise(lo = min(min_wage), hi = max(min_wage), mean = mean(min_wage))
rng$wavg <- main$wavg[as.character(rng$fiscal_year)]
stopifnot(all(rng$wavg > rng$lo & rng$wavg < rng$hi))
stopifnot(round(rng$wavg[rng$fiscal_year == 2023]) == 1004,
          round(rng$wavg[rng$fiscal_year == 2024]) == 1055,
          round(rng$wavg[rng$fiscal_year == 2025]) == 1121)

min_wage_pref$effective_date <- format(min_wage_pref$effective_date, "%Y-%m-%d")
readr::write_csv(min_wage_pref, file.path("public", "data", "min_wage_pref.csv"))
message("min_wage_pref.csv: ", nrow(min_wage_pref), " 行を書き出しました")
