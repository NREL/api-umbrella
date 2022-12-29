module.exports = {
  extends: 'airbnb-base',
  env: {
    browser: true,
  },
  overrides: [
    // node files
    {
      files: [
        '.eslintrc.js',
        'webpack.config.js',
      ],
      parserOptions: {
        sourceType: 'script',
        ecmaVersion: 2015,
      },
      env: {
        browser: false,
        node: true,
      },
    },
  ],
};
