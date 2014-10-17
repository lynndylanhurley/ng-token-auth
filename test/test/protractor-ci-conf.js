require('coffee-script/register');
var os    = require('os');
var creds = require('../config/sauce.json') || process.env;

console.log('@-->sauce username', creds.SAUCE_USERNAME);
console.log('@-->capabilities', process.env.CAPABILITIES);

exports.config = {
  sauceUser: creds.SAUCE_USERNAME,
  sauceKey:  creds.SAUCE_ACCESS_KEY,
  framework: 'jasmine',

  specs: [
    'e2e/ng-token-auth/*.coffee'
  ],

  //chromeOnly: true,

  capabilities: JSON.parse(process.env.CAPABILITIES),

  //multiCapabilities: [{
    //browserName:         'chrome',
    //build:               process.env.TRAVIS_BUILD_NUMBER,
    //'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  //}, {
    //browserName:         'firefox',
    //build:               process.env.TRAVIS_BUILD_NUMBER,
    //'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  //}, {
    //browserName:         'safari',
    //build:               process.env.TRAVIS_BUILD_NUMBER,
    //'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  //}, {
    //browserName:         'internet explorer',
    //version:             11,
    //build:               process.env.TRAVIS_BUILD_NUMBER,
    //'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  //}, {
    //browserName:         'internet explorer',
    //version:             10,
    //maxInstances:        1,
    //build:               process.env.TRAVIS_BUILD_NUMBER,
    //'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  //}, {
    //browserName:         'internet explorer',
    //version:             9,
    //maxInstances:        1,
    //build:               process.env.TRAVIS_BUILD_NUMBER,
    //'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  //}, {
    //browserName:         'internet explorer',
    //version:             8,
    //maxInstances:        1,
    //build:               process.env.TRAVIS_BUILD_NUMBER,
    //'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER
  //}],

  baseUrl: 'http://localhost:8888',

  jasmineNodeOpts: {
    showColors: true,
    defaultTimeoutInterval: 300000
  }
};
