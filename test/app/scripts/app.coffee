angular.module('ngTokenAuthTestApp', [
  'ngSanitize'
  'ui.router'
  'mgcrea.ngStrap'
  'angularSpinner'
  'ngTokenAuthTestPartials'
  'ng-token-auth'
])
  .config ($stateProvider, $urlRouterProvider, $locationProvider, $sceProvider, $authProvider, $httpProvider) ->
    # disable sce
    # TODO: FIX
    $sceProvider.enabled(false)

    # push-state routes
    $locationProvider.html5Mode(false)

    # default to 404 if state not found
    $urlRouterProvider.otherwise('/404')

    $authProvider.configure([
      default:
        apiUrl:  CONFIG.apiUrl
        proxyIf: -> window.isOldIE()
        authProviderPaths:
          github:    '/auth/github'
          facebook:  '/auth/facebook'
          google:    '/auth/google_oauth2'
          developer: '/auth/developer'
    ,
      evilUser:
        apiUrl:                CONFIG.apiUrl
        proxyIf:               -> window.isOldIE()
        signOutUrl:              '/mangs/sign_out'
        emailSignInPath:         '/mangs/sign_in'
        emailRegistrationPath:   '/mangs'
        accountUpdatePath:       '/mangs'
        accountDeletePath:       '/mangs'
        passwordResetPath:       '/mangs/password'
        passwordUpdatePath:      '/mangs/password'
        tokenValidationPath:     '/mangs/validate_token'
        authProviderPaths:
          github:    '/mangs/github'
          facebook:  '/mangs/facebook'
          google:    '/mangs/google_oauth2'
    ])

    $stateProvider
      .state 'index',
        url: '/'
        templateUrl: 'index.html'
        controller: 'IndexCtrl'

      .state 'null',
        url: ''
        templateUrl: 'index.html'
        controller: 'IndexCtrl'

      .state 'multi-user',
        url: '/multi-user'
        templateUrl: 'multi-user.html'
        controller: 'AltUserCtrl'

      .state '404',
        url: '/404'
        templateUrl: '404.html'

      .state 'style-guide',
        url: '/style-guide'
        templateUrl: 'style-guide.html'
        controller: 'StyleGuideCtrl'

      .state 'terms',
        url: '/terms'
        templateUrl: 'terms.html'
