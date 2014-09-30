require('coffee-script/register');
var os = require('os');

exports.config = {
  allScriptsTimeout: 30000,
  sauceUser: process.env.SAUCE_USERNAME,
  sauceKey: process.env.SAUCE_ACCESS_KEY,

  specs: [
    'e2e/ng-token-auth/*.coffee'
  ],

  chromeOnly: true,

  capabilities: {
    'browserName': 'chrome',
    'name': 'ng e2e',
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER,
    'build': process.env.TRAVIS_BUILD_NUMBER,
    'chromeOptions': {
      'args': ['show-fps-counter=true']
    }
  },

  baseUrl: 'http://'+os.hostname()+':7777/',

  framework: 'jasmine',

  jasmineNodeOpts: {
    defaultTimeoutInterval: 30000
  }
};
