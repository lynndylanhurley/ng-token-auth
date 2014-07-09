angular.module('ngTokenAuthTestApp')
  .controller 'IndexCtrl', ($scope, $auth, $http, $modal) ->
    $scope.accessRestrictedRoute = ->
      $http.get($auth.apiUrl() + '/demo/members_only')
        .success((resp) -> alert(resp.data.message))
        .error((resp) -> alert(resp.errors[0]))


    $scope.$on('auth:registration-email-sent', (ev, data) ->
      $modal({
        title: "Success"
        html: true
        content: "<div id='alert-registration-email-sent'>A registration email was "+
          "sent to " + data.email + ". follow the instructions contained in the "+
          "email to complete registration.</div>"
      })

      delete $scope.registrationForm[field] for field, val of $scope.registrationForm
    )

    $scope.$on('auth:registration-email-failed', (ev, data) ->
      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-registration-email-failed'>Unable to send email "+
          "registration: " + _.map(data.errors).toString() + "</div>"
      })
    )

    $scope.$on('auth:login', (ev, user) ->
      $modal({
        title: "Success"
        html: true
        content: "<div id='alert-auth-login'>Welcome back " + user.email + '</div>'
      })

      delete $scope.loginForm[field] for field, val of $scope.loginForm
      delete $scope.registrationForm[field] for field, val of $scope.registrationForm
    )

    $scope.$on('auth:failure', (ev, data) ->
      $modal({
        title: "Error"
        html: true
        content: "<div id='alert-failure'>Authentication failure: " +
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

    $scope.$on('auth:logout-failure', (ev) ->
      $modal({
        title: 'Error'
        html: true
        content: "<div id='alert-logout-failure'>Unable to complete logout. "+
          "Please try again.</div>"
      })
    )
