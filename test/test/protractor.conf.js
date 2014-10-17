require('coffee-script/register');
var os = require('os');

exports.config = {
  framework: 'jasmine',

  specs: [
    'e2e/ng-token-auth/*.coffee'
  ],

  chromeOnly: true,

  baseUrl: 'http://localhost:8888',

  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 30000
  }
};
