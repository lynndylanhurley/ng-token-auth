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
      apiUrl: '//defsynth-api.dev'
    })

    console.log '@-->auth config', $authProvider

    $stateProvider
      .state 'index',
        url: '/'
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
