os = require('os')

module.exports = (config) ->
  config.set
    basePath : '../../'

    preprocessors:
      'src/*.coffee': ['coverage']
      'test/test/**/*.coffee': ['coffee']

    files : [
      'test/app/bower_components/angular/angular.js'
      'test/app/bower_components/angular-cookies/angular-cookies.js'
      'test/app/bower_components/angular-mocks/angular-mocks.js'
      'src/*.coffee'
      'test/test/unit/test-helper.coffee'
      #'test/test/unit/ng-token-auth/**/*.coffee'
      'test/test/e2e/scenarios.coffee'
    ]


    baseUrl: 'http://'+os.hostname()+':7777/',
    capabilities: {
      'browserName': 'chrome',
      'name': 'ng e2e',
      'tunnel-identifier': process.env.TRAVIS_JOB_NUMBER,
      'build': process.env.TRAVIS_BUILD_NUMBER
    }

    autoWatch: true

    reporters: ['spec', 'coverage']

    frameworks: ['mocha', 'chai', 'sinon', 'chai-as-promised']

    browsers: ['Chrome']

    colors: true

    client:
      mocha:
        ui: 'tdd'

    coverageReporter:
      type: 'lcov'
      dir: 'coverage/'
