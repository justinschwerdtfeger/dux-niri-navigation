const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

// Execute the same library files QML imports, including relative .imports.
function loadModel(name) {
    const root = path.resolve(__dirname, '..');
    const filename = name.includes('/')
        ? path.resolve(root, name)
        : path.resolve(root, name === 'SidebarModel.js' ? 'plugins/window-tabs' : 'shared', name);
    const context = vm.createContext({});
    const source = fs
        .readFileSync(filename, 'utf8')
        .replace(/^\.pragma library[^\n]*$/m, '')
        .replace(/^\.import "([^"]+)" as (\w+)[^\n]*$/gm, (_, file, alias) => {
            context[alias] = loadModel(
                path.relative(
                    path.resolve(__dirname, '..'),
                    path.resolve(path.dirname(filename), file),
                ),
            );
            return '';
        });
    vm.runInContext(source, context, { filename });
    return context;
}

const plain = (value) => JSON.parse(JSON.stringify(value));

module.exports = { loadModel, plain };
