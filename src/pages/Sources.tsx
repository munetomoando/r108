// データの出典・利用条件とライセンスの一覧（政府標準利用規約の出典・加工表示、e-Stat API のクレジット）
const BASE = import.meta.env.BASE_URL;

type Row = { file: string; source: string; edit: string };

// 公的統計を加工したデータ。出典の詳細（統計表ID・取得日）は public/data/codebook/*.yaml
const official: Row[] = [
  { file: 'pref_basic.csv', source: '総務省統計局「令和2年国勢調査 人口等基本集計」、国土交通省国土地理院「全国都道府県市区町村別面積調」', edit: '都道府県別の人口・世帯数・65歳以上割合・面積を抜き出し、地方区分を付けた' },
  { file: 'pref_labor_wide.csv', source: '総務省統計局「国勢調査」時系列データ（2000〜2020年）', edit: '労働力状態の人口から就業率を計算し、年を列に並べた' },
  { file: 'wage_census_pref.csv', source: '厚生労働省「賃金構造基本統計調査」（2019〜2025年）', edit: '都道府県別の所定内給与額と労働時間を各年の表から抜き出して結合' },
  { file: 'min_wage_pref.csv', source: '厚生労働省「地域別最低賃金改定状況」', edit: '2002〜2025年度の都道府県別の値を縦長の表に整形' },
  { file: 'pref_panel.csv', source: '上の3つ（賃金構造基本統計調査、地域別最低賃金、国勢調査）', edit: '結合し、時給とカイツ指標を計算' },
  { file: 'kakei_raw_sjis.csv', source: '総務省統計局「家計調査 家計収支編」（2025年、二人以上の世帯）', edit: '生鮮4品目の支出金額だけを抜き出した' },
  { file: 'lfs_monthly.csv', source: '総務省統計局「労働力調査 基本集計」', edit: '完全失業率と就業者数の月次系列を抜き出した' },
  { file: 'cpi_monthly.csv', source: '総務省統計局「消費者物価指数（2025年基準）」', edit: '全国の総合と生鮮食品を除く総合の月次系列を抜き出した' },
  { file: 'gdp_quarterly.csv', source: '内閣府経済社会総合研究所「国民経済計算（GDP統計）」四半期別GDP速報', edit: '実質季節調整系列と前期比を抜き出した' },
  { file: 'iip_monthly.csv', source: '経済産業省「鉱工業生産・出荷・在庫指数」（2020年基準）', edit: '鉱工業総合の季節調整済指数と原指数を抜き出した' },
  { file: 'estat_sample.json', source: '総務省統計局「社会・人口統計体系 都道府県データ」（e-Stat API）', edit: 'API の応答をそのまま保存し、アプリケーションIDだけを伏せた' },
];

// R のパッケージから読み込むデータ（このサイトからは配布しない）
const packaged: Row[] = [
  { file: 'gapminder（第19・20ステップ）', source: 'gapminder パッケージ。Based on free material from GAPMINDER.ORG, CC-BY LICENSE', edit: 'パッケージのまま使用' },
  { file: 'wage1（第45ステップ）', source: 'wooldridge パッケージ。J. M. Wooldridge, Introductory Econometrics: A Modern Approach, 7th ed., Cengage, 2020（元データは 1976年の Current Population Survey）', edit: 'パッケージのまま使用' },
  { file: 'mroz（第47〜49ステップ）', source: 'wooldridge パッケージ。T. A. Mroz (1987) "The Sensitivity of an Empirical Model of Married Women\'s Hours of Work to Economic and Statistical Assumptions," Econometrica 55(4), 765–799', edit: 'パッケージのまま使用' },
  { file: 'nsw_mixtape・cps_mixtape（第62ステップ）', source: 'causaldata パッケージ。R. LaLonde (1986) American Economic Review 76(4); R. Dehejia and S. Wahba (1999) Journal of the American Statistical Association 94(448)', edit: 'パッケージのまま使用' },
  { file: 'organ_donations（第68・69ステップ）', source: 'causaldata パッケージ。J. B. Kessler and A. E. Roth (2014) NBER Working Paper No. 20378', edit: 'パッケージのまま使用' },
  { file: 'close_college（第69・70ステップ）', source: 'causaldata パッケージ。D. Card (1995) "Using Geographic Variation in College Proximity to Estimate the Return to Schooling"', edit: 'パッケージのまま使用' },
  { file: 'gov_transfers（第71ステップ）', source: 'causaldata パッケージ。M. Manacorda, E. Miguel and A. Vigorito (2011) American Economic Journal: Applied Economics 3(3)', edit: 'パッケージのまま使用' },
];

export default function Sources() {
  return (
    <div className="page">
      <div className="prose">
        <h1>データの出典とライセンス</h1>

        <h2>公的統計を加工して作成したデータ</h2>
        <p>
          次のデータは、各府省が公表した統計を、著者（安藤至大）が加工して作成したものです。加工後の数値は国が作成したものではありません。元の統計は政府標準利用規約（第2.0版）に従って利用しています。統計表の番号や取得日などの詳細は、各データのコードブック（
          <a href="https://github.com/munetomoando/r108/tree/main/public/data/codebook">public/data/codebook/</a>）にあります。
        </p>
        <table>
          <thead>
            <tr><th>データ</th><th>出典</th><th>加工の内容</th></tr>
          </thead>
          <tbody>
            {official.map((r) => (
              <tr key={r.file}><td><code>{r.file}</code></td><td>{r.source}を加工して作成</td><td>{r.edit}</td></tr>
            ))}
          </tbody>
        </table>
        <p className="note">
          このサービスは、政府統計総合窓口(e-Stat)のAPI機能を使用していますが、サービスの内容は国によって保証されたものではありません。
        </p>

        <h2>合成データ（架空のデータ）</h2>
        <p>
          「そらまめマーケット」の店舗・顧客・注文、職業訓練、奨学金、A/Bテストなどのデータは、著者が乱数で作った架空のデータです。実在の企業・人物・政策とは関係ありません。生成の式は公開リポジトリの <code>data-raw/synth_*.R</code> にあります。
        </p>

        <h2>R のパッケージから読み込むデータ</h2>
        <p>
          次のデータは、このサイトからは配布していません。学習者のブラウザが R のパッケージを読み込んで使います。利用条件は、各パッケージと元の著作者の定めに従います。
        </p>
        <table>
          <thead>
            <tr><th>データ</th><th>出典</th></tr>
          </thead>
          <tbody>
            {packaged.map((r) => (
              <tr key={r.file}><td>{r.file}</td><td>{r.source}</td></tr>
            ))}
          </tbody>
        </table>

        <h2>このサイトのライセンス</h2>
        <ul>
          <li>本文・課題・図、合成データ、コードブックの説明文：クリエイティブ・コモンズ 表示 4.0 国際（CC BY 4.0）。著者は安藤至大です。</li>
          <li>プログラム（アプリ、判定の仕組み、確認スクリプトなど）：MIT ライセンス。</li>
          <li>公的統計を加工したデータ：上の出典を表示して利用してください（政府標準利用規約（第2.0版）。CC BY 4.0 と互換です）。</li>
          <li>
            このサイトに同梱しているソフトウェアの著作権表示とライセンス文：
            <a href={`${BASE}THIRD_PARTY_LICENSES.txt`}>THIRD_PARTY_LICENSES.txt</a>
          </li>
        </ul>
        <p>
          R は R Foundation のプロジェクトで、RStudio と Positron は Posit PBC の製品です。このサイトは R Foundation や Posit とは関係ありません。R はブラウザ版の{' '}
          <a href="https://docs.r-wasm.org/webr/">webR</a> で動かしています。
        </p>
      </div>
    </div>
  );
}
