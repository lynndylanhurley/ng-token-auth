module.exports = (config) ->
  customLaunchers =
    'SL_Chrome':
      base: 'SauceLabs'
      browserName: 'chrome'

    #'SL_Firefox':
      #base: 'SauceLabs'
      #browserName: 'firefox'
      #version: '26'

    #'SL_Safari':
      #base: 'SauceLabs'
      #browserName: 'safari'
      #platform: 'OS X 10.9'
      #version: '7'

    #'SL_IE_9':
      #base: 'SauceLabs'
      #browserName: 'internet explorer'
      #platform: 'Windows 2008'
      #version: '9'

    #'SL_IE_10':
      #base: 'SauceLabs'
      #browserName: 'internet explorer'
      #platform: 'Windows 2012'
      #version: '10'

    #'SL_IE_11':
      #base: 'SauceLabs'
      #browserName: 'internet explorer'
      #platform: 'Windows 8.1'
      #version: '11'

  config.set
    basePath : '../../'

    preprocessors:
      'src/*.coffee': ['coverage']
      'test/test/**/*.coffee': ['coffee']

    files : [
      'test/app/bower_components/angular/angular.js'
      'test/app/bower_components/angular-cookie/angular-cookie.js'
      'test/app/bower_components/angular-mocks/angular-mocks.js'
      'src/*.coffee'
      'test/test/unit/test-helper.coffee'
      'test/test/unit/ng-token-auth/**/*.coffee'
    ]

    autoWatch: true

    reporters: ['spec', 'saucelabs', 'coverage']

    frameworks: ['mocha', 'chai', 'sinon', 'chai-as-promised']

    browsers: Object.keys(customLaunchers)
    #browsers: ['Chrome']

    colors: true

    client:
      mocha:
        ui: 'tdd'

    sauceLabs:
      testName:         'ng-token-auth unit tests'
      startConnect:     false
      tunnelIdentifier: process.env.TRAVIS_JOB_NUMBER

    customLaunchers: customLaunchers

    coverageReporter:
      type: 'lcov'
      dir: 'coverage/'
