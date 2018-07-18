module.exports = {
  root: true,
  parserOptions: {
    ecmaVersion: 2017,
    sourceType: 'module'
  },
  plugins: [
    'ember'
  ],
  extends: [
    'eslint:recommended',
    'plugin:ember/recommended'
  ],
  env: {
    browser: true
  },
  rules: {
    'comma-dangle': ['error', 'always-multiline'],
    'no-var': 'error',
    'sort-imports': 'error',
    'object-shorthand': ['error', 'methods'],
    'no-duplicate-imports': 'error',
    'func-call-spacing': ['error', 'never'],
    'keyword-spacing': ['error', { 'before': true, 'after': true, 'overrides': {
      'if': { 'after': false },
      'for': { 'after': false },
      'while': { 'after': false },
      'catch': { 'after': false },
      'switch': { 'after': false },
    }}],
    'no-trailing-spaces': 'error',
  },
  globals: {
    'CommonValidations': true,
    'JsDiff': true,
    '_': true,
    'ace': true,
    'bootbox': true,
    'inflection': true,
    'marked': true,
  },
  overrides: [
    // node files
    {
      files: [
        'testem.js',
        'ember-cli-build.js',
        'config/**/*.js',
        'lib/*/index.js'
      ],
      parserOptions: {
        sourceType: 'script',
        ecmaVersion: 2015
      },
      env: {
        browser: false,
        node: true
      }
    },

    // test files
    {
      files: ['tests/**/*.js'],
      excludedFiles: ['tests/dummy/**/*.js'],
      env: {
        embertest: true
      }
    }
  ]
};
