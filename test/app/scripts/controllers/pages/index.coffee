angular.module('ngTokenAuthTestApp')
  .controller 'IndexCtrl', ($scope, $auth, $http, $modal) ->
    $scope.accessRestrictedRoute = ->
      $http.get($auth.apiUrl() + '/demo/members_only')
        .success((resp) -> alert(resp.data.message))
        .error((resp) -> alert(resp.errors[0]))


    $scope.$on('auth:registration-email-sent', (ev, data) ->
      $modal({
        title: "Success"
        content: "A registration email was sent to " + data.email + ". "+
          "follow the instructions contained in the email to complete "+
          "registration."
      })

      delete $scope.registrationForm[field] for field, val of $scope.registrationForm
    )

    $scope.$on('auth:registration-email-failed', (ev, data) ->
      $modal({
        title: "Error"
        content: "Unable to send email registration: " + data.errors[0]
      })
    )

    $scope.$on('auth:login', (ev, user) ->
      $modal({
        title: "Success"
        content: "Welcome back " + user.email
      })

      delete $scope.loginForm[field] for field, val of $scope.loginForm
      delete $scope.registrationForm[field] for field, val of $scope.registrationForm
    )

    $scope.$on('auth:failure', (ev, data) ->
      $modal({
        title: "Error"
        content: "Authentication failure: " + data.errors[0]
      })
    )

    $scope.$on('auth:logout-success', (ev) ->
      $modal({
        title: 'Success'
        content: 'Goodbye'
      })
    )

    $scope.$on('auth:logout-failure', (ev) ->
      $modal({
        title: 'Error'
        content: 'Unable to complete logout. Please try again.'
      })
    )
