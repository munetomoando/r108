## 問い

そらまめマーケット（架空の会社）では、ネット通販の注文はすべて社内の**データベース**に記録されています。これまでは CSV に書き出したものをもらって分析してきましたが、実際の会社では何年分もの全データを毎回 CSV でもらうことはできません。データベースに**SQL**（エスキューエル。データベースに問い合わせる言語）で問い合わせて、必要な行と列だけを取り出します。このステップでは、R からデータベースにつなぎ、SQL の基本の4つの形を学びます。

## データベースにつなぐ

R からデータベースを使うときは、**DBI** パッケージの関数を使います。つなぐ先の種類（DuckDB、PostgreSQL など）が変わっても、使う関数は同じです。このステップでは、ブラウザの中でも動く **DuckDB** を使い、メモリ上に小さなデータベースを作ります。setup では次のことをしています。

```r
con <- dbConnect(duckdb())            # データベースを作ってつなぐ
dbWriteTable(con, "orders", orders)   # R の表をデータベースの表 orders として入れる
dbListTables(con)                     # データベースにある表の一覧
```

`con` は「接続」で、以後の問い合わせはすべて `con` を通して送ります。実際の職場では、`dbWriteTable()` で入れるのではなく、情報システムの担当者が用意したデータベースに接続します。初めて DuckDB を使うときは、パッケージの読み込みに数秒かかります。

## SELECT と WHERE：必要な列と行だけ取る

SQL は「SELECT 列 FROM 表 WHERE 条件」の順に書きます。SQL 文を文字列にして `dbGetQuery()` に渡すと、結果が R の data.frame で返ってきます。

```r
sql <- "
  SELECT order_id, order_date, qty, unit_price
  FROM orders
  WHERE order_date >= DATE '2025-12-01' AND qty >= 5
"
big <- dbGetQuery(con, sql)
```

SELECT は dplyr の `select()`、WHERE は `filter()` に当たります。R と違う点が3つあります。「等しい」は `==` ではなく `=` 1つで書きます。「かつ」は `AND`、「または」は `OR` です。文字列や日付は `' '`（一重引用符）で囲み、日付は `DATE '2025-12-01'` と書きます。SQL 文全体を `" "` で囲むので、中では `' '` を使うと覚えましょう。`SELECT *` と書くと全ての列を取り出しますが、大きな表では必要な列だけを書くのが作法です。

## GROUP BY：データベースの中で集計する

何十万行もの明細を R に取り込まなくても、集計はデータベースの中でできます。GROUP BY でグループに分け、SELECT に集計関数を書きます。

```r
sql <- "
  SELECT coupon, COUNT(*) AS n_lines, SUM(qty * unit_price) AS sales
  FROM orders
  GROUP BY coupon
"
dbGetQuery(con, sql)
```

GROUP BY は `group_by()` に、SELECT の集計は `summarise()` に当たります。`COUNT(*)` は行数（`n()`）、`COUNT(DISTINCT order_id)` は種類の数（`n_distinct()`）、`SUM()`・`AVG()` は合計・平均です。`AS` で結果の列に名前を付けます。並べ替えは `ORDER BY 列`（大きい順は `DESC` を付ける）で、`arrange()` に当たります。b では、2025年のクーポンなしの注文が26,484件、クーポンありが6,662件と分かります。

## JOIN：表をつなぐ

注文明細には商品のカテゴリがありません。商品マスタと `product_id` でつなぎます。

```r
sql <- "
  SELECT o.order_id, o.qty, p.category
  FROM orders AS o
  INNER JOIN products AS p ON o.product_id = p.product_id
"
```

`AS o` は表の短い別名です。両方の表に同じ名前の列があるので、`o.product_id`・`p.product_id` のように表の名前を付けて区別します。`INNER JOIN` は `inner_join()`、`LEFT JOIN` は `left_join()` に当たります。

## dplyr で書いて SQL を読む（dbplyr）

`tbl(con, "orders")` は、データベースの表を dplyr で扱える形にします。dplyr の関数をつなぐと、**dbplyr** が SQL に翻訳し、データベースで計算します。`show_query()` で翻訳された SQL を、`collect()` で結果を R の data.frame として取り込みます。

```r
q <- tbl(con, "orders") |>
  filter(coupon == 1) |>
  group_by(customer_id) |>
  summarise(sales = sum(qty * unit_price, na.rm = TRUE))
show_query(q)    # 翻訳された SQL を見る
collect(q)       # 結果を R に取り込む
```

SQL を直接書くか dplyr で書くかは、職場の習慣で選びます。dplyr で書いても、`show_query()` で SQL を読めると、データベースの担当者と同じ言葉で話せます。使い終わったら `dbDisconnect(con)` で接続を閉じます。

## 卒論・実務での使いどころ

大きなデータは、データベースの中で WHERE で絞り GROUP BY で集計してから、小さくなった結果だけを R に取り込んで分析します。
