module.exports = (config) ->
  config.set
    basePath : '../../'

    preprocessors:
      'src/*.coffee': ['coverage']
      'test/test/**/*.coffee': ['coffee']
      'test/app/scripts/**/*.coffee': ['coffee']

    files : [
      # bower:js
      "test/app/bower_components/jquery/dist/jquery.js"
      "test/app/bower_components/angular/angular.js"
      "test/app/bower_components/angular-animate/angular-animate.js"
      "test/app/bower_components/Faker/Faker.js"
      "test/app/bower_components/lodash/dist/lodash.compat.js"
      "test/app/bower_components/bootstrap-additions/dist/bootstrap-additions.min.css"
      "test/app/bower_components/angular-sanitize/angular-sanitize.js"
      "test/app/bower_components/angular-cookies/angular-cookies.js"
      "test/app/bower_components/angular-resource/angular-resource.js"
      "test/app/bower_components/angular-mocks/angular-mocks.js"
      "test/app/bower_components/matchmedia/matchMedia.js"
      "test/app/bower_components/spin.js/spin.js"
      "test/app/bower_components/respond/dest/respond.src.js"
      "test/app/bower_components/angular-ui-router/release/angular-ui-router.js"
      "test/app/bower_components/angular-motion/dist/angular-motion.min.css"
      "test/app/bower_components/matchmedia-ng/matchmedia-ng.js"
      "test/app/bower_components/angular-spinner/angular-spinner.js"
      "test/app/bower_components/angular-strap/dist/angular-strap.min.js"
      "test/app/bower_components/angular-strap/dist/angular-strap.tpl.min.js"
      # endbower

      # inject:js
      "test/.tmp/views/404.js"
      "test/.tmp/views/index.js"
      "test/.tmp/views/multi-user.js"
      "test/.tmp/views/style-guide.js"
      "test/.tmp/views/terms.js"
      "test/.tmp/views/partials/password-change-error-modal.js"
      "test/.tmp/views/partials/password-reset-modal.js"
      "test/.tmp/views/partials/style-guide/popover.js"
      "test/.tmp/scripts/app.js"
      "test/.tmp/scripts/ng-token-auth.js"
      "test/.tmp/scripts/controllers/main.js"
      "test/.tmp/scripts/directives/scroll-to.js"
      "test/.tmp/scripts/plugins/prism.js"
      "test/.tmp/scripts/polyfills/navigator.js"
      "test/.tmp/scripts/polyfills/trim.js"
      "test/.tmp/scripts/controllers/pages/alt-user.js"
      "test/.tmp/scripts/controllers/pages/index.js"
      "test/.tmp/scripts/controllers/pages/style-guide.js"
      # endinject

      'src/*.coffee'
      'test/app/scripts/**/*.coffee'
      'test/test/unit/test-helper.coffee'
      'test/test/unit/ng-token-auth/**/*.coffee'
      'test/test/unit/demo-site/**/*.coffee'
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
