## 問い

ステップ100の月次レポートは、上から順に読む文書でした。一方、経営会議の冒頭で「今月の数字はどうか」を一目で見せたいときは、売上・客数・客単価の数値と推移の図を **1画面** に並べた **ダッシュボード** が向いています。そらまめマーケット（架空の会社）のネット通販の指標で、Quarto のダッシュボードを作ります。

## ダッシュボードの作り

YAML ヘッダで `format: dashboard` にすると、Quarto は文書ではなく、画面いっぱいにカードを並べたページを作ります。並べ方の規則は3つです。

- **`##` の見出しが1つの行**：`## Row` のように書くたびに、新しい行（横一列）が始まります。`{height="25%"}` で画面に占める高さを決めます
- **チャンク1つがカード1枚**：同じ行のチャンクは横に並びます。`#| title: "…"` がカードの見出しになります
- **数値カード**：`#| content: valuebox` を付けたチャンクは、大きな数字を1つ見せるカード（バリューボックス）になります

数値カードのチャンクは、最後に次のような `list()` を返します。

```r
#| content: valuebox
#| title: "売上（万円）"
list(icon = "currency-yen", color = "primary", value = round(now$sales / 10000))
```

`value` が表示する数値、`icon` はカードの絵（Bootstrap Icons の名前。`people`・`cart`・`graph-up` など）、`color` は色（`primary`・`info`・`secondary`・`success`・`warning`・`danger` など）です。

## 雛形を出力する

1. プロジェクト `r108` を開き、`data` フォルダに [ec_orders.csv](data/ec_orders.csv) と [ec_products.csv](data/ec_products.csv) があることを確かめます（ステップ100でダウンロードしたもの）。
2. 雛形 [dashboard.qmd](local/dashboard.qmd) をダウンロードし、プロジェクトのフォルダに移して開きます。
3. RStudio は「Render」、Positron は「Preview」を押します。同じフォルダに `dashboard.html` と、図を入れた `dashboard_files` フォルダができます。
   - Windows：エクスプローラーで `dashboard.html` をダブルクリックし、ブラウザで開きます。
   - macOS：Finder で `dashboard.html` をダブルクリックします。

上の行に「売上（万円）」のカード（2025年12月は991）が1枚、下の行に月別の売上の図が1枚あります。ダッシュボードではコードは表示されないので、`echo: false` は要りません。

## カードと図を加える

上の行の `<!-- -->` のメモを消し、客数と客単価のカードを加えます。

````markdown
```{r}
#| content: valuebox
#| title: "客数（人）"
list(icon = "people", color = "info", value = now$buyers)
```

```{r}
#| content: valuebox
#| title: "客単価（円）"
list(icon = "cart", color = "secondary", value = round(now$spend))
```
````

下の行のメモの位置には、対象月のカテゴリ別の売上の図を加えます。

````markdown
```{r}
#| title: "カテゴリ別の売上（対象月、万円）"
ec |>
  filter(ym == m) |>
  group_by(category) |>
  summarise(sales = sum(sales) / 10000) |>
  ggplot(aes(x = fct_reorder(category, sales), y = sales)) +
  geom_col() +
  coord_flip() +
  labs(x = NULL, y = NULL)
```
````

Render し直すと、上に3枚のカード（売上991万円・客数2,374人・客単価4,174円）、下に2枚の図が並びます。2025年12月は、食品（約230万円）と衣料品（約193万円）が大きい順です。
## 何を載せるか

ダッシュボードは、載せる指標を絞るほど読みやすくなります。毎月必ず見る数値（KPI）はカードに、変化の理由を探す図は下の行に置き、細かい表は載せずに月次レポートへ回します。行ではなく縦の列で分けたいときは、YAML ヘッダを `format:` の下に `dashboard:`、その下に `orientation: columns` と書く形にし、見出しを `## Column {width="40%"}` のようにします。数値カードを3枚以上、図を2枚以上にしたら、確認スクリプトを実行します。

## 卒論・実務での使いどころ

ダッシュボードは「毎回同じ指標を同じ場所で見る」ためのもので、データを差し替えて Render するだけで最新の状態にでき、会議の冒頭で全員が同じ数字を見ることができます。
