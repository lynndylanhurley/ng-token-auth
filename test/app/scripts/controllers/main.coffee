angular.module('ngTokenAuthTestApp')
  .controller 'MainCtrl', ($rootScope, $scope, $location, $state, $stateParams, usSpinnerService, $timeout, $auth, $modal, $http, $q) ->

    # test validate user
    window.validateUser = -> $auth.validateUser()

    # cache element selectors
    $body = $('body')

    # click methods
    $scope.accessRestrictedRoute = ->
      $http.get($auth.apiUrl() + '/demo/members_only')
        .success((resp) -> alert(resp.data.message))
        .error((resp) -> alert(resp.errors[0]))

    $scope.restrictedRoutesBatch = ->
      $q.all([
        $http.get($auth.apiUrl() + '/demo/members_only')
        $http.get($auth.apiUrl() + '/demo/members_only')
      ])
        .then((resp) -> alert('Multiple requests to default user routes succeeded'))
        .catch((resp) -> alert('Multiple requests to default user routes failed'))


    $scope.accessRestrictedRouteEvilUser = ->
      $http.get($auth.apiUrl() + '/demo/members_only_mang')
        .success((resp) -> alert(resp.data.message))
        .error((resp) -> alert(resp.errors[0]))

    $scope.restrictedRoutesBatchEvilUser = ->
      $q.all([
        $http.get($auth.apiUrl() + '/demo/members_only_mang')
        $http.get($auth.apiUrl() + '/demo/members_only_mang')
      ])
        .then((resp) -> alert('Multiple requests to evil user routes succeeded'))
        .catch((resp) -> alert('Multiple requests to evil user routes failed'))


    $scope.accessRestrictedRouteMember = ->
      $http.get($auth.apiUrl() + '/demo/members_only_group')
        .success((resp) -> alert(resp.data.message))
        .error((resp) -> alert(resp.errors[0]))

    $scope.restrictedRoutesBatchMember = ->
      $q.all([
        $http.get($auth.apiUrl() + '/demo/members_only_group')
        $http.get($auth.apiUrl() + '/demo/members_only_group')
      ])
        .then((resp) -> alert('Multiple requests to member user routes succeeded'))
        .catch((resp) -> alert('Multiple requests to member user routes failed'))


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


    # redraw the current page. useful for updating content when
    # data has changed server-side.
    $rootScope.refresh = ->
      $state.transitionTo($state.current, $stateParams, {
        reload: true
        inherit: false
        notify: true
      })


    # event listeners
    $scope.$on('auth:registration-email-success', (ev, data) ->
      $modal({
        title: "Success"
        html: true
        content: "<div id='alert-registration-email-sent'>A registration email was "+
          "sent to " + data.email + ". follow the instructions contained in the "+
          "email to complete registration.</div>"
      })

      delete $scope.registrationForm[field] for field, val of $scope.registrationForm
    )

    $scope.$on('auth:registration-email-error', (ev, data) ->
      errors = _(data.errors)
        .map((v, k) -> "#{k}: #{v}.")
        .value()
        .join("<br/>")

      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-registration-email-failed'>Unable to send email "+
          "registration. " + errors + "</div>"
      })
    )

    $scope.$on('auth:email-confirmation-success', (ev, data) ->
      $modal({
        title: "Success!"
        html: true
        content: "<div id='alert-email-confirmation-success'>Welcome "+
          data.email+". Your account has been successfully created."+
          "</div>"
      })
    )

    $scope.$on('auth:email-confirmation-error', (ev, data) ->
      $modal({
        title: "Error!"
        html: true
        content: "<div id='alert-email-confirmation-error'>Unable to confirm "+
          "your account. Request a password reset to verify your identity."+
          "</div>"
      })
    )

    $scope.$on('auth:password-reset-request-success', (ev, params) ->
      $modal({
        title: "Success"
        html: true
        content: "<div id='alert-password-reset-request-success'>Password reset "+
          "instructions have been sent to " + params.email + "</div>"
      })
    )

    $scope.$on('auth:password-reset-request-error', (ev, data) ->
      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-password-reset-request-error'>Error: "+
          _.map(data.errors).toString() + "</div>"
      })
    )

    $scope.$on('auth:password-reset-confirm-error', (ev, data) ->
      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-password-reset-request-error'>Error: "+
          _.map(data.errors).toString() + "</div>"
      })
    )

    passwordChangeModal = $modal({
      title: "Change your password!"
      html: true
      show: false
      contentTemplate: 'partials/password-reset-modal.html'
    })

    passwordChangeSuccessModal = $modal({
      title: "Success"
      html: true
      show: false
      content: "<div id='alert-password-change-success'>Your password "+
        "has been successfully updated."
    })

    passwordChangeErrorScope = $scope.$new()
    passwordChangeErrorModal = $modal({
      title: "Error"
      html: true
      show: false
      scope: passwordChangeErrorScope
      contentTemplate: 'partials/password-change-error-modal.html'
    })

    $scope.showPasswordChangeModal = -> passwordChangeModal.show()

    $scope.$on('auth:password-reset-confirm-success', -> passwordChangeModal.show())

    $scope.$on('auth:password-change-success', ->
      passwordChangeModal.hide()
      passwordChangeSuccessModal.show()
    )

    $scope.$on('auth:password-change-error', (ev, data) ->
      passwordChangeErrorScope.errors = data.errors
      passwordChangeModal.hide()
      passwordChangeErrorModal.show()
    )

    passwordChangeErrorScope.$on('modal.hide', ->
      passwordChangeModal.show()
    )

    $scope.$on('auth:login-success', (ev, user) ->
      $modal({
        title: "Success"
        html: true
        content: "<div id='alert-auth-login-success'>Welcome back " + user.email + '</div>'
      })

      delete $scope.loginForm[field] for field, val of $scope.loginForm
      delete $scope.registrationForm[field] for field, val of $scope.registrationForm
    )

    $scope.$on('auth:login-error', (ev, data) ->
      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-login-error'>Authentication failure: " +
          data.errors[0] + '</div>'
      })
    )

    $scope.$on('auth:logout-success', (ev) ->
      $modal({
        title: 'Success'
        html: true
        content: "<div id='alert-logout-success'>Goodbye</div>"
      })
    )

    $scope.$on('auth:logout-error', (ev) ->
      $modal({
        title: 'Error'
        html: true
        content: "<div id='alert-logout-error'>Unable to complete logout. "+
          "Please try again.</div>"
      })
    )

    $scope.$on('auth:account-update-success', ->
      $modal({
        title: 'Success'
        html: true
        content: "<div id='alert-account-update-success'>Your account has been updated."+
          "</div>"
      })
    )

    $scope.$on('auth:account-update-error', (ev, data) ->
      errors = _(data.errors)
        .map((v, k) -> "#{k}: #{v}.")
        .value()
        .join("<br/>")

      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-account-update-error'>Unable to update "+
          "your account. " + errors + "</div>"
      })
    )

    $scope.$on('auth:account-destroy-success', ->
      $modal({
        title: 'Success'
        html: true
        content: "<div id='alert-account-destroy-success'>Your account has been destroyed."+
          "</div>"
      })
    )

    $scope.$on('auth:account-destroy-error', (ev, data) ->
      errors = _(data.errors)
        .map((v, k) -> "#{k}: #{v}.")
        .value()
        .join("<br/>")

      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-account-destroy-error'>Unable to destroy "+
          "your account. " + errors + "</div>"
      })
    )
