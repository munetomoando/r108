import { HashRouter, NavLink, Route, Routes } from 'react-router-dom';
import Toc from './pages/Toc';
import Step from './pages/Step';
import Progress from './pages/Progress';
import Playground from './pages/Playground';
import PkgCheck from './pages/PkgCheck';
import RuntimeStatus from './components/RuntimeStatus';
import { doneCount, useProgress } from './store/progress';
import { TOTAL_STEPS } from './content/loader';

// GitHub Pages ではサーバー側の書き換えができないため、ハッシュ方式のルーティングを使う（#/step/013）
export default function App() {
  const p = useProgress();
  return (
    <HashRouter>
      <a className="skip-link" href="#main">本文へ移動</a>
      <header className="site-header no-print">
        <NavLink to="/" className="brand">
          <span className="brand-mark" aria-hidden="true">R</span>
          <span>Rデータ分析 108ステップ</span>
        </NavLink>
        <nav className="site-nav" aria-label="サイト">
          <NavLink to="/" end>目次</NavLink>
          <NavLink to="/progress">進捗 {doneCount(p)}/{TOTAL_STEPS}</NavLink>
          <NavLink to="/playground">自由に試す</NavLink>
        </nav>
        <RuntimeStatus />
      </header>
      <main id="main">
        <Routes>
          <Route path="/" element={<Toc />} />
          <Route path="/step/:id" element={<Step />} />
          <Route path="/progress" element={<Progress />} />
          <Route path="/playground" element={<Playground />} />
          <Route path="/pkgcheck" element={<PkgCheck />} />
          <Route path="*" element={<Toc />} />
        </Routes>
      </main>
      <footer className="site-footer no-print">
        <p>
          著者：安藤至大（日本大学経済学部）・ 本文とデータは CC BY 4.0、コードは MIT ライセンス
        </p>
      </footer>
    </HashRouter>
  );
}
