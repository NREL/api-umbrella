const path = require('path');
const CleanWebpackPlugin = require('clean-webpack-plugin');
const ExtractTextPlugin = require('extract-text-webpack-plugin');

const extractStylesheet = new ExtractTextPlugin({
  filename: './assets/login.css',
});

module.exports = {
  entry: {
    'login': './assets/login.scss',
  },
  output: {
    path: path.resolve(__dirname, './assets/dist'),
    filename: '[name]-[hash].css',
  },
  module: {
    rules: [
      {
        test: /\.woff2?$|\.ttf$|\.eot$|\.svg$/,
        loader: 'file-loader?name=[name]-[hash].[ext]',
      },
      {
        test: /\.scss$/,
        use: ExtractTextPlugin.extract({
          use: [
            {
              loader: 'css-loader',
            },
            {
              loader: 'sass-loader',
              options: {
                outputStyle: 'compressed',
                // Increase sass number precision for bootstrap-sass.
                precision: 8,
              },
            },
          ],
        }),
      },
    ]
  },
  plugins: [
    new CleanWebpackPlugin(['./assets/dist']),
    new ExtractTextPlugin('[name]-[hash].css'),
  ]
};
