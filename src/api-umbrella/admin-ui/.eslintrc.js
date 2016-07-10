module.exports = {
  extends: './node_modules/ember-cli-eslint/coding-standard/ember-application.js',
  rules: {
    'comma-dangle': ['error', 'always-multiline'],
    'no-var': 'error',
    'object-shorthand': ['error', 'methods'],
    'no-duplicate-imports': 'error',
  },
  globals: {
    '$': true,
    'CommonValidations': true,
    'I18n': true,
    'PNotify': true,
    '_': true,
    'bootbox': true,
    'inflection': true,
    'moment': true,
  },
};
