# pref_basic.csv を作る（2020年、47都道府県）。
#   出力: public/data/pref_basic.csv（列: pref_code, pref, region（8地方）, population, area_km2, aged65_share, households）
#   実行: Rscript data-raw/fetch_pref_basic.R（プロジェクトのルートで。通信しない）
#   入力: data-raw/raw/pref_basic/ に保存した公表ファイル（出所・取得日は同フォルダの SOURCES.md）
#     b01_01.xlsx       令和2年国勢調査 人口等基本集計 第1-1表（人口・世帯数。面積（参考）は検算に使う）
#     b02_03.xlsx       令和2年国勢調査 人口等基本集計 第2-3表（人口構成比［年齢別］の65歳以上）
#     R1_R5_mencho.csv  国土地理院「全国都道府県市区町村別面積調」令和元年〜令和5年（令和2年10月1日の列を使う）
#
# 列の定義
#   population   人口総数（第1-1表「人口 総数」）
#   households   世帯数 総数（一般世帯＋施設等の世帯。第1-1表「世帯数 総数」）
#   aged65_share 65歳以上人口の割合（％、小数1桁）。第2-3表の公表値「人口構成比［年齢別］ 65歳以上」
#                （年齢「不詳」を除いて算出）を四捨五入
#   area_km2     面積（km²、公表どおり小数2桁）。令和2年10月1日時点。境界未定部を含む県は国土地理院が
#                「参考値」とした概算値（国勢調査の第1-1表「面積（参考）」と同じ値）
#   pref_code / region は暫定版（data-raw/pref_basic_interim.R）と同じ付け方（JIS順、8地方区分）
suppressMessages(library(readxl))

raw_dir <- file.path("data-raw", "raw", "pref_basic")

region_of <- function(code) {
  rep(c("北海道", "東北", "関東", "中部", "近畿", "中国", "四国", "九州"),
      c(1, 6, 7, 9, 7, 5, 4, 8))[code]
}

# 四捨五入（R の round() は偶数丸めになる場合があるので使わない）
round_half_up <- function(x, digits = 1) floor(x * 10^digits + 0.5 + 1e-9) / 10^digits

# ---- 第1-1表: 人口・世帯数 ----
b01 <- suppressMessages(read_excel(file.path(raw_dir, "b01_01.xlsx"), col_names = FALSE, col_types = "text"))
hdr_row <- which(b01[[1]] == "地域識別コード")
h1 <- unlist(b01[10, ]); h4 <- unlist(b01[13, ])                     # 見出し（項目名・区分）
stopifnot(length(hdr_row) == 1)
col_of <- function(item, cls = NA) {
  j <- which(h1 == item & (if (is.na(cls)) TRUE else h4 == cls))
  stopifnot(length(j) == 1); j
}
body01 <- b01[(hdr_row + 1):nrow(b01), ]
code01 <- body01[[6]]                                                # 2020年_地域コード
is_pref01 <- grepl("^[0-9]{2}000$", code01) & code01 != "00000"
t01 <- data.frame(
  pref_code  = as.integer(substr(code01[is_pref01], 1, 2)),
  pref       = sub("^[0-9]+_", "", body01[[7]][is_pref01]),
  population = as.numeric(body01[[col_of("人口", "0_総数")]][is_pref01]),
  households = as.numeric(body01[[col_of("世帯数", "0_総数")]][is_pref01]),
  area_census = as.numeric(body01[[col_of("面積（参考）")]][is_pref01]),
  stringsAsFactors = FALSE
)
nat01 <- body01[code01 == "00000", ]
nat_pop <- as.numeric(nat01[[col_of("人口", "0_総数")]])
nat_hh  <- as.numeric(nat01[[col_of("世帯数", "0_総数")]])

# ---- 第2-3表: 65歳以上人口の割合 ----
b02 <- suppressMessages(read_excel(file.path(raw_dir, "b02_03.xlsx"), col_names = FALSE, col_types = "text"))
hdr2 <- which(b02[[1]] == "国籍総数か日本人")
g6 <- unlist(b02[6, ]); g9 <- unlist(b02[9, ])
j65 <- which(g6 == "人口構成比［年齢別］" & g9 == "3_65歳以上")
j65n <- which(g6 == "人口" & g9 == "R3_（再掲）65歳以上")
jtot <- which(g6 == "人口" & g9 == "00_総数")
junk <- which(g6 == "人口" & g9 == "24_年齢「不詳」")
stopifnot(length(hdr2) == 1, length(j65) == 1, length(j65n) == 1, length(jtot) == 1, length(junk) == 1)
body02 <- b02[(hdr2 + 1):nrow(b02), ]
sel02 <- body02[[1]] == "0_国籍総数" & body02[[2]] == "0_総数" & grepl("^[0-9]{2}000_", body02[[4]])
body02 <- body02[sel02, ]
code02 <- as.integer(substr(body02[[4]], 1, 2))
t02 <- data.frame(
  pref_code = code02[code02 != 0],
  share65   = as.numeric(body02[[j65]][code02 != 0]),
  pop65     = as.numeric(body02[[j65n]][code02 != 0]),
  pop_tot   = as.numeric(body02[[jtot]][code02 != 0]),
  pop_unk   = as.numeric(body02[[junk]][code02 != 0])
)
nat02 <- body02[code02 == 0, ]

# ---- 国土地理院 面積調（令和2年10月1日） ----
m <- read.csv(file.path(raw_dir, "R1_R5_mencho.csv"), header = FALSE, fileEncoding = "CP932",
              colClasses = "character", na.strings = "")
mh <- which(m[[1]] %in% "標準地域コード")
ja <- which(unlist(m[mh, ]) == "令和2年10月1日(k㎡)")
stopifnot(length(mh) == 1, length(ja) == 1)
mp <- m[grepl("^[0-9]{2}000$", m[[1]]), ]
area <- data.frame(pref_code = as.integer(substr(mp[[1]], 1, 2)), pref_gsi = mp[[2]],
                   area_km2 = as.numeric(mp[[ja]]), area_note = mp[[ja + 1]])
nat_area <- as.numeric(m[m[[1]] %in% "全国面積", ja])

# ---- 結合 ----
pref_basic <- merge(merge(t01, t02, by = "pref_code"), area, by = "pref_code")
pref_basic <- pref_basic[order(pref_basic$pref_code), ]
stopifnot(identical(pref_basic$pref, pref_basic$pref_gsi))

# 検算
stopifnot(nrow(pref_basic) == 47, identical(pref_basic$pref_code, 1:47))
stopifnot(sum(pref_basic$population) == nat_pop, sum(pref_basic$households) == nat_hh)
stopifnot(all(pref_basic$population == pref_basic$pop_tot))                       # 2表の人口が一致
stopifnot(all(abs(pref_basic$area_km2 - pref_basic$area_census) < 0.005))          # 国勢調査の面積（参考）と一致
stopifnot(abs(sum(pref_basic$area_km2) - nat_area) < 1)                            # 県の合計≒全国（丸め差のみ）
# 公表の割合は「65歳以上 ÷（総数 − 年齢不詳）」に一致する
stopifnot(max(abs(pref_basic$pop65 / (pref_basic$pop_tot - pref_basic$pop_unk) * 100 - pref_basic$share65)) < 1e-4)
stopifnot(all(pref_basic$share65 > 15 & pref_basic$share65 < 45))

out <- data.frame(
  pref_code    = pref_basic$pref_code,
  pref         = pref_basic$pref,
  region       = region_of(pref_basic$pref_code),
  population   = pref_basic$population,
  area_km2     = pref_basic$area_km2,
  aged65_share = round_half_up(pref_basic$share65, 1),
  households   = pref_basic$households
)
stopifnot(!anyNA(out))
cat("全国: 人口", format(nat_pop, big.mark = ","), "、世帯数", format(nat_hh, big.mark = ","),
    "、面積", nat_area, "km²（県の合計", sum(out$area_km2), "）、65歳以上割合",
    round_half_up(as.numeric(nat02[[j65]]), 1), "%\n")
cat("面積が国土地理院の参考値（境界未定部を含む概算）の県:",
    paste(pref_basic$pref[grepl("参考", pref_basic$area_note)], collapse = "、"), "\n")

write.csv(out, "public/data/pref_basic.csv", row.names = FALSE, fileEncoding = "UTF-8")
cat("public/data/pref_basic.csv を書き出しました（", nrow(out), "行）\n")
