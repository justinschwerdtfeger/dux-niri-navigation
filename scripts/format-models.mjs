import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import prettier from 'prettier';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const write = process.argv.includes('--write');
const config = await prettier.resolveConfig(path.join(root, 'shared/WindowModel.js'));
const entries = (
    await Promise.all(
        ['shared', 'plugins'].map((dir) =>
            fs.readdir(path.join(root, dir), { recursive: true, withFileTypes: true }),
        ),
    )
).flat();
for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith('.js')) continue;
    const file = path.join(entry.parentPath, entry.name);
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
        console.error(`${path.relative(root, file)}: run make format`);
        process.exitCode = 1;
    }
}
