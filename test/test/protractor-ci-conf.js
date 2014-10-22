require('coffee-script/register');
var os    = require('os');
var creds = {};

try {
  creds = require('./test/config/sauce.json');
} catch (ex) {
  creds = process.env;
}

if (!creds.SAUCE_USERNAME) {
  throw "@-->ERROR: SAUCE_USERNAME not found in test/config/sauce.json or ENV.";
}

if (!creds.SAUCE_ACCESS_KEY) {
  throw "@-->ERROR: SAUCE_ACCESS_KEY not found in test/config/sauce.json or ENV.";
}

if (!process.env.CAPABILITIES) {
  throw "@-->ERROR: CAPABILITIES not found in ENV.";
}

exports.config = {
  sauceUser: creds.SAUCE_USERNAME,
  sauceKey:  creds.SAUCE_ACCESS_KEY,
  framework: 'jasmine',

  specs: [
    'e2e/ng-token-auth/*.coffee'
  ],

  capabilities: JSON.parse(process.env.CAPABILITIES),

  baseUrl: 'http://localhost:8888',

  getPageTimeout: 50000,
  allScriptsTimeout: 50000,

  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 50000
  }
};
