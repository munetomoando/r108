# jp_tile.csv を作る（47都道府県をタイル地図に並べるための位置表）。
#   出力: public/data/jp_tile.csv（列: pref_code, pref, row, col）
#   実行: Rscript data-raw/make_jp_tile.R（どのディレクトリからでもよい。通信しない）
#   入力: public/data/pref_basic.csv（県コードと県名の照合に使う。先に fetch_pref_basic.R を実行しておく）
#
# 配置は手作業で決めた（1県1マス、12列×11行）。
#   row … 上から何行目か（1始まり）。図にするときは scale_y_reverse() で上から並べる
#   col … 左から何列目か（1始まり）
# 北海道を右上、沖縄を左下に置き、隣り合う県がなるべく上下左右（少なくとも斜め）に接するようにした。
#
#        1    2    3    4    5    6    7    8    9   10   11   12
#   1                                                          北海道
#   2                                                          青森
#   3                                                     秋田 岩手
#   4                                                     山形 宮城
#   5                                       福井 石川 富山 新潟 福島
#   6                    島根 鳥取 兵庫 京都 滋賀 岐阜 長野 群馬 栃木
#   7               山口 広島 岡山 大阪 奈良 三重 愛知 山梨 埼玉 茨城
#   8          佐賀 福岡 愛媛 香川 和歌山          静岡 神奈川 東京 千葉
#   9     長崎 熊本 大分 高知 徳島
#  10          鹿児島 宮崎
#  11     沖縄
#
# 最後に、47県がそろっていること・県名が pref_basic と一致すること・同じマスに2県が無いことを確かめる。
suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tibble)
})

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
root <- if (length(file_arg)) normalizePath(file.path(dirname(sub("^--file=", "", file_arg)), "..")) else getwd()
dd <- function(f) file.path(root, "public", "data", f)

tile <- tribble(
  ~pref_code, ~pref,       ~row, ~col,
   1L,        "北海道",     1L,  12L,
   2L,        "青森県",     2L,  12L,
   3L,        "岩手県",     3L,  12L,
   4L,        "宮城県",     4L,  12L,
   5L,        "秋田県",     3L,  11L,
   6L,        "山形県",     4L,  11L,
   7L,        "福島県",     5L,  12L,
   8L,        "茨城県",     7L,  12L,
   9L,        "栃木県",     6L,  12L,
  10L,        "群馬県",     6L,  11L,
  11L,        "埼玉県",     7L,  11L,
  12L,        "千葉県",     8L,  12L,
  13L,        "東京都",     8L,  11L,
  14L,        "神奈川県",   8L,  10L,
  15L,        "新潟県",     5L,  11L,
  16L,        "富山県",     5L,  10L,
  17L,        "石川県",     5L,   9L,
  18L,        "福井県",     5L,   8L,
  19L,        "山梨県",     7L,  10L,
  20L,        "長野県",     6L,  10L,
  21L,        "岐阜県",     6L,   9L,
  22L,        "静岡県",     8L,   9L,
  23L,        "愛知県",     7L,   9L,
  24L,        "三重県",     7L,   8L,
  25L,        "滋賀県",     6L,   8L,
  26L,        "京都府",     6L,   7L,
  27L,        "大阪府",     7L,   6L,
  28L,        "兵庫県",     6L,   6L,
  29L,        "奈良県",     7L,   7L,
  30L,        "和歌山県",   8L,   6L,
  31L,        "鳥取県",     6L,   5L,
  32L,        "島根県",     6L,   4L,
  33L,        "岡山県",     7L,   5L,
  34L,        "広島県",     7L,   4L,
  35L,        "山口県",     7L,   3L,
  36L,        "徳島県",     9L,   5L,
  37L,        "香川県",     8L,   5L,
  38L,        "愛媛県",     8L,   4L,
  39L,        "高知県",     9L,   4L,
  40L,        "福岡県",     8L,   3L,
  41L,        "佐賀県",     8L,   2L,
  42L,        "長崎県",     9L,   1L,
  43L,        "熊本県",     9L,   2L,
  44L,        "大分県",     9L,   3L,
  45L,        "宮崎県",    10L,   3L,
  46L,        "鹿児島県",  10L,   2L,
  47L,        "沖縄県",    11L,   1L
)

# ---- 確認 ----
basic <- read_csv(dd("pref_basic.csv"), show_col_types = FALSE) |> select(pref_code, pref)
stopifnot(
  nrow(tile) == 47,
  setequal(tile$pref_code, 1:47),
  !anyDuplicated(paste(tile$row, tile$col))            # 同じマスに2県が無い
)
chk <- full_join(tile, basic, by = "pref_code", suffix = c("", "_basic"))
bad <- filter(chk, is.na(pref) | is.na(pref_basic) | pref != pref_basic)
if (nrow(bad) > 0) {
  print(bad)
  stop("県名が pref_basic.csv と一致しません")
}

tile <- arrange(tile, pref_code)
write_csv(tile, dd("jp_tile.csv"))
cat("public/data/jp_tile.csv に", nrow(tile), "行を書き出しました\n")
