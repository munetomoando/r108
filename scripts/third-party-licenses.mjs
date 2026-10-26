// ビルドに同梱した npm パッケージの著作権表示とライセンス文を dist/THIRD_PARTY_LICENSES.txt に書き出す
// （MIT・ISC などの「著作権表示と許諾文を残す」条件を満たすため）
import fs from 'node:fs';
import path from 'node:path';

const LICENSE_FILES = /^(licen[cs]e|copying|notice)([-.][a-z0-9]+)*$/i;

/** モジュールのパスから、それを含む node_modules 直下のパッケージのフォルダを返す */
function packageDir(id) {
  const file = id.replace(/^\0/, '').split('?')[0];
  const i = file.lastIndexOf('/node_modules/');
  if (i < 0) return null;
  const rest = file.slice(i + '/node_modules/'.length).split('/');
  const name = rest[0].startsWith('@') ? rest.slice(0, 2).join('/') : rest[0];
  return file.slice(0, i) + '/node_modules/' + name;
}

export default function thirdPartyLicenses() {
  return {
    name: 'r108-third-party-licenses',
    apply: 'build',
    generateBundle() {
      const dirs = new Set();
      for (const id of this.getModuleIds()) {
        const d = packageDir(id);
        if (d && fs.existsSync(path.join(d, 'package.json'))) dirs.add(d);
      }
      const entries = [...dirs]
        .map((d) => {
          const pkg = JSON.parse(fs.readFileSync(path.join(d, 'package.json'), 'utf8'));
          const lic = fs.readdirSync(d).filter((f) => LICENSE_FILES.test(f)).sort();
          const text = lic.map((f) => fs.readFileSync(path.join(d, f), 'utf8').trim()).join('\n\n');
          return { name: pkg.name, version: pkg.version, license: pkg.license ?? '(不明)', text };
        })
        .sort((a, b) => a.name.localeCompare(b.name));
      const header = [
        'Rデータ分析 108ステップ（r108）に同梱しているサードパーティのソフトウェア',
        '',
        'このサイトは次のソフトウェアを含みます。各ソフトウェアの著作権表示とライセンス文を、配布元のファイルのまま載せます。',
        'R 本体と R のパッケージ（webR）は、このサイトには含まれず、学習者のブラウザが webr.r-wasm.org と repo.r-wasm.org から直接読み込みます。',
        '',
      ];
      const body = entries.map((e) =>
        [`${'='.repeat(72)}`, `${e.name} ${e.version}（${e.license}）`, `${'='.repeat(72)}`, e.text || '（パッケージにライセンス文のファイルがありません）', ''].join('\n'),
      );
      this.emitFile({ type: 'asset', fileName: 'THIRD_PARTY_LICENSES.txt', source: header.concat(body).join('\n') });
    },
  };
}
