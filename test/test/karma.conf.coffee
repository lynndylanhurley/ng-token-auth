module.exports = (config) ->
  config.set
    basePath : '../../'

    preprocessors: 
      'src/*.coffee': ['coffee']
      'test/test/**/*.coffee': ['coffee']

    files : [
      'test/app/bower_components/angular/angular.js'
      'test/app/bower_components/angular-route/angular-route.js'
      'test/app/bower_components/angular-cookies/angular-cookies.js'
      'test/app/bower_components/angular-mocks/angular-mocks.js'
      'src/*.coffee'
      'test/test/unit/test-helper.coffee'
      'test/test/unit/ng-token-auth/**/*.coffee'
    ]

    autoWatch: true

    reporters: ['spec']

    frameworks: ['mocha', 'chai', 'sinon', 'chai-as-promised']

    browsers: ['Chrome']

    colors: true

    client:
      mocha:
        ui: 'tdd'

    sauceLabs:
      testName:         'ng-token-auth unit tests'
      browsers:         ['sl_chrome']
      username:         process.env.SAUCE_USERNAME
      accessKey:        process.env.SAUCE_ACCESS_KEY
      startConnect:     true
      build:            process.env.TRAVIS_BUILD_NUMBER
      tunnelIdentifier: process.env.TRAVIS_BUILD_NUMBER

      customLaunchers: [
        base:        'SauceLabs'
        browserName: 'chrome'
        platform:    'Windows 7'
      ]

    #coverageReporter:
      #type: 'lcov'
      #dir: 'coverage/'
