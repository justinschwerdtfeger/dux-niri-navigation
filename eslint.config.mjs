import js from '@eslint/js';

const qmlLibraries = {
    processors: {
        library: {
            // Blank the QML directives to retain the original diagnostic lines.
            preprocess: (source) => [source.replace(/^\.(?:pragma|import)[^\n]*/gm, '')],
            postprocess: (messages) => messages.flat(),
        },
    },
};

export default [
    {
        ignores: ['.local/**', 'tmp/**', '.agents/**', '.codex/**', '.aws/**', 'dist/**'],
    },
    js.configs.recommended,
    {
        files: ['**/*.js'],
        plugins: { qml: qmlLibraries },
        processor: 'qml/library',
        languageOptions: {
            sourceType: 'script',
            globals: { Windows: 'readonly' },
        },
        // Top-level functions/values are the QML library's public exports.
        rules: { 'no-unused-vars': ['error', { vars: 'local', argsIgnorePattern: '^_' }] },
    },
    {
        files: ['**/*.cjs'],
        languageOptions: {
            globals: {
                require: 'readonly',
                module: 'readonly',
                __dirname: 'readonly',
                process: 'readonly',
                console: 'readonly',
                setImmediate: 'readonly',
                structuredClone: 'readonly',
            },
        },
    },
    {
        files: ['**/*.mjs'],
        languageOptions: { globals: { console: 'readonly', process: 'readonly' } },
    },
];
