import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import prettier from 'prettier';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const write = process.argv.includes('--write');
const config = await prettier.resolveConfig(path.join(root, 'WindowModel.js'));
for (const name of (await fs.readdir(root)).filter((name) => name.endsWith('.js'))) {
    const file = path.join(root, name);
    const source = await fs.readFile(file, 'utf8');
    const directives = source.match(/^(?:\.(?:pragma|import)[^\n]*\n)+/)?.[0] ?? '';
    const formatted =
        directives +
        (await prettier.format(source.slice(directives.length), {
            ...config,
            parser: 'babel',
        }));
    if (formatted === source) continue;
    if (write) await fs.writeFile(file, formatted);
    else {
        console.error(`${name}: run make format`);
        process.exitCode = 1;
    }
}
