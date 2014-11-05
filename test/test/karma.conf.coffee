module.exports = (config) ->
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
