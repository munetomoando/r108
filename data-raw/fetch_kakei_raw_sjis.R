# kakei_raw_sjis.csv を作る（家計調査。統計局の公式 Excel から、見出し・注記の体裁を残して Shift-JIS で保存）。
#   入力: data-raw/raw/kakei/a401_2025.xlsx
#         e-Stat「家計調査 家計収支編 二人以上の世帯 詳細結果表 年次 2025年」
#         第4-1表 都市階級・地方・都道府県庁所在市別１世帯当たり支出金額，購入数量及び平均価格
#         （statInfId=000040409546。取得方法と取得日は data-raw/raw/kakei/SOURCES.md）
#   出力: public/data/kakei_raw_sjis.csv（表題・注記つき、見出し行が複数。文字コードは CP932）
#   実行: Rscript data-raw/fetch_kakei_raw_sjis.R（ネットワーク不要。readxl を使う）
#   第11ステップで locale(encoding = "CP932") と skip を練習するため、表の体裁は元ファイルに合わせる。
#
# 加工の内容（値は一切変えない）
#   1. シート「二人・市別」だけを使う（全国・地方のシートは使わない）
#   2. 品目は 生鮮魚介(1.2.1)・生鮮肉(1.3.1)・生鮮野菜(1.5.1)・生鮮果物(1.6.1) の4行、
#      項目は「支出金額」の列だけを残す（購入頻度・購入数量・平均価格は捨てる）
#   3. 元表は「行＝品目、列＝都市×項目」なので、行と列を入れ替えて「行＝都市（52）、列＝品目」にする。
#      見出しは元表の「品目分類」「分類コード」「支出金額の単位」の3行をそのまま横向きに置き、
#      都市名は元の列見出し「01100 札幌市・支出金額」から「・支出金額」を除いた「01100 札幌市」とする
#   4. 先頭の表情報（統計名・統計表番号・表題・2025年計・二人以上の世帯）と末尾の注記 ※1〜※4 は
#      元ファイルの文言のまま残す。元ファイル先頭2行の列番号（1,2,3…）と空行は除く
#   5. 末尾に加工した旨の注記を1行足す

suppressPackageStartupMessages(library(readxl))

src   <- file.path("data-raw", "raw", "kakei", "a401_2025.xlsx")
sheet <- "二人・市別"
out   <- file.path("public", "data", "kakei_raw_sjis.csv")

d <- read_excel(src, sheet = sheet, col_names = FALSE, col_types = "text",
                .name_repair = "minimal")
d <- as.data.frame(d, stringsAsFactors = FALSE)

# 表の情報（元シートの8列目と10列目にある）
cell <- function(r, c) { v <- d[r, c]; if (is.na(v)) "" else v }
stopifnot(cell(4, 8) == "統計名：", cell(5, 8) == "統計表番号：", cell(6, 8) == "表題：",
          cell(10, 12) == "品目分類", cell(10, 11) == "分類コード", cell(10, 13) == "支出金額の単位")
meta <- list(
  c(cell(4, 8), cell(4, 10)),   # 統計名：, 家計調査 家計収支編
  c(cell(5, 8), cell(5, 10)),   # 統計表番号：, 第４－１表
  c(cell(6, 8), cell(6, 10)),   # 表題：, 都市階級・地方・…
  c(cell(7, 8)),                # 2025年計
  c(cell(8, 8))                 # 二人以上の世帯
)

# 生鮮4品目の行（分類コードと品目名の両方で確かめる）
items <- data.frame(code = c("1.2.1", "1.3.1", "1.5.1", "1.6.1"),
                    name = c("生鮮魚介", "生鮮肉", "生鮮野菜", "生鮮果物"))
rows <- vapply(seq_len(nrow(items)), function(k) {
  r <- which(d[[11]] == items$code[k] & d[[12]] == items$name[k])
  stopifnot(length(r) == 1)
  r
}, integer(1))
units <- d[rows, 13]
stopifnot(all(units == "円"))

# 都市の「支出金額」列
hdr  <- d[9, ]
cols <- which(grepl("・支出金額$", hdr))
city <- sub("・支出金額$", "", unlist(hdr[cols]))
stopifnot(length(cols) == 52, !anyDuplicated(city))

vals <- t(as.matrix(d[rows, cols]))           # 行＝都市、列＝品目（文字列のまま。値はいじらない）
stopifnot(all(grepl("^[0-9]+$", vals)))       # すべて整数の円であること

# 末尾の注記（元シートの最後の ※ 行）
notes <- d[grepl("^※", d[[8]]), 8]
stopifnot(length(notes) == 4)

csv_field <- function(x) ifelse(grepl("[,\"\n]", x), paste0("\"", gsub("\"", "\"\"", x), "\""), x)
line <- function(x) paste(csv_field(x), collapse = ",")

lines <- c(
  vapply(meta, line, character(1)),
  line(c(cell(10, 12), items$name)),        # 品目分類,生鮮魚介,…
  line(c(cell(10, 11), items$code)),        # 分類コード,1.2.1,…
  line(c(cell(10, 13), units)),             # 支出金額の単位,円,…
  vapply(seq_along(city), function(i) line(c(city[i], vals[i, ])), character(1)),
  notes,
  paste0("※ 教材用に加工：e-Stat 家計調査 第４－１表（2025年計）「", sheet,
         "」シートから生鮮4品目の支出金額だけを抜き出し，都市を行に並べた（値は元表のまま）")
)

con <- file(out, open = "w", encoding = "CP932")
writeLines(lines, con)
close(con)
cat(out, "を Shift-JIS（CP932）で書き出しました（", length(lines), "行、うち都市", length(city), "）\n")
