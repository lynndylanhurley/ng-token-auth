require('coffee-script/register');
var os = require('os');

exports.config = {
  allScriptsTimeout: 11000,
  sauceUser: process.env.SAUCE_USERNAME,
  sauceKey: process.env.SAUCE_ACCESS_KEY,

  specs: [
    'e2e/*.coffee'
  ],

  capabilities: {
    'browserName': 'chrome'
  },

  baseUrl: 'http://'+os.hostname()+':7777/',

  framework: 'jasmine',

  jasmineNodeOpts: {
    defaultTimeoutInterval: 30000
  }
};
