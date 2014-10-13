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

  multiCapabilities: [{
    browserName:         'chrome',
    maxInstances:        1,
    build:               process.env.TRAVIS_BUILD_NUMBER,
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  }, {
    browserName:         'firefox',
    maxInstances:        1,
    build:               process.env.TRAVIS_BUILD_NUMBER,
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  }, {
    browserName:         'safari',
    maxInstances:        1,
    build:               process.env.TRAVIS_BUILD_NUMBER,
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  }, {
    browserName:         'internet explorer',
    version:             11,
    maxInstances:        1,
    build:               process.env.TRAVIS_BUILD_NUMBER,
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  }, {
    browserName:         'internet explorer',
    version:             10,
    maxInstances:        1,
    build:               process.env.TRAVIS_BUILD_NUMBER,
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  }, {
    browserName:         'internet explorer',
    version:             9,
    maxInstances:        1,
    build:               process.env.TRAVIS_BUILD_NUMBER,
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  }, {
    browserName:         'internet explorer',
    version:             8,
    maxInstances:        1,
    build:               process.env.TRAVIS_BUILD_NUMBER,
    'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  }],

  baseUrl: 'http://localhost:8888',

  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 30000
  }
};
