require('coffee-script/register');
var os = require('os');

exports.config = {
  sauceUser: process.env.SAUCE_USERNAME,
  sauceKey:  process.env.SAUCE_ACCESS_KEY,
  framework: 'jasmine',

  specs: [
    'e2e/ng-token-auth/*.coffee'
  ],

  //chromeOnly: true,

  capabilities: {
    name:                'ngTokenAuth e2e',
    build:               process.env.TRAVIS_BUILD_NUMBER,
    browserName:         'chrome',
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  },

  baseUrl: 'http://localhost:8888',

  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 30000
  }
};
