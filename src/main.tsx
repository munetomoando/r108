import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { startR } from './runtime/webr';
import './styles.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

// 目次を読んでいる間に R を先に起動しておく（初回は数十秒かかるため）
startR().catch(() => undefined);
