require('coffee-script/register');
var os = require('os');

exports.config = {
  //allScriptsTimeout: 30000,
  sauceUser: process.env.SAUCE_USERNAME,
  sauceKey: process.env.SAUCE_KEY,
  framework: 'jasmine',

  specs: [
    'e2e/ng-token-auth/*.coffee'
  ],

  //chromeOnly: true,

  capabilities: {
    'browserName': 'chrome',
    'name': 'ngTokenAuth e2e',
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER,
    'build': process.env.TRAVIS_BUILD_NUMBER
  },

  baseUrl: 'http://localhost:8888',

  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 30000
  }
};
