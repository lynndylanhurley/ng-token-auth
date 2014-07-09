process.env.NODE_CONFIG_DIR = './test/config'
require('coffee-script/register');
require('config');

exports.config = {
  allScriptsTimeout: 11000,
  sauceUser: process.env.SAUCE_USERNAME,
  sauceKey: process.env.SAUCE_ACCESS_KEY,

  specs: [
    'e2e/*.coffee'
  ],

  capabilities: {
    'browserName': 'chrome',
    'name': 'ng e2e',
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER,
    'build': process.env.TRAVIS_BUILD_NUMBER
  },

  baseUrl: 'http://localhost:7777/',

  framework: 'jasmine',

  jasmineNodeOpts: {
    defaultTimeoutInterval: 30000
  }
};
