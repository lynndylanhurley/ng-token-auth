angular.module('ngTokenAuthTestApp')
  .controller 'MainCtrl', ($rootScope, $scope, $location, $state, $stateParams, usSpinnerService, $timeout, $auth) ->
    # cache element selectors
    $body = $('body')

    # called on page change (ui-sref)
    $rootScope.$on '$stateChangeStart', (event, toState, toParams, fromState, fromParams) ->
      # tracking
      ga('send', 'pageview', {'page': $location.path()})

      # set body class to state name
      $body.attr 'class', toState.name.replace(/\./g, ' ') + ' loading'

      # show loading spinner
      usSpinnerService.spin('main-loading')

      # close dropdown nav
      $scope.collapse = false

    # new page, DOM has finished loading
    $rootScope.$on '$viewContentLoaded', (event, viewConfig) ->
      $timeout((->
        # remove loading spinner
        usSpinnerService.stop('main-loading')

        # fade in
        $body.removeClass('loading')
      ), 0)


    $rootScope.$on 'auth:failure', (event, reason) ->
      console.log 'auth failure', reason

    $rootScope.$on 'auth:success', (ev, user) ->
      console.log 'auth success', user

    $rootScope.$on 'auth:registration-email-sent', (ev, params) ->
      console.log 'auth sent email', params

    # redraw the current page. useful for updating content when
    # data has changed server-side.
    $rootScope.refresh = ->
      $state.transitionTo($state.current, $stateParams, {
        reload: true
        inherit: false
        notify: true
      })
