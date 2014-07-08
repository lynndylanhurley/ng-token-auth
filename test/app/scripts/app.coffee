angular.module('ngTokenAuthTestApp', [
  'ngSanitize'
  'ui.router'
  'mgcrea.ngStrap'
  'angularSpinner'
  'ngTokenAuthTestPartials'
  'ng-token-auth'
])
  .config ($stateProvider, $urlRouterProvider, $locationProvider, $sceProvider, $authProvider) ->
    # disable sce
    # TODO: FIX
    $sceProvider.enabled(false)

    # push-state routes
    $locationProvider.html5Mode(true)

    # default to 404 if state not found
    $urlRouterProvider.otherwise('/404')

    $authProvider.configure({
      #apiUrl: '//localhost:3000'
      #apiUrl: '//devise-token-auth-demo.dev'
      #apiUrl: '//devise-token-auth-demo.herokuapp.com'
      #apiUrl: '//devise-token-auth.192.168.1.102.xip.io'
      apiUrl: '//devise-token-auth.dev'
      proxyIf: -> window.isOldIE()
      authProviderPaths:
        github:    '/auth/github'
        facebook:  '/auth/facebook'
        google:    '/auth/google_oauth2'
        developer: '/auth/developer'
    })

    $stateProvider
      .state 'index',
        url: '/'
        templateUrl: 'index.html'
        controller: 'IndexCtrl'

      .state 'null',
        url: ''
        templateUrl: 'index.html'
        controller: 'IndexCtrl'

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
