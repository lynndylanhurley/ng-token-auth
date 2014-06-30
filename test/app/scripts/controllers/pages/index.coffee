angular.module('ngTokenAuthTestApp')
  .controller 'IndexCtrl', ($scope, $auth, $http) ->
    console.log 'index'

    $scope.accessRestrictedRoute = ->
      $http.get($auth.config.apiUrl + '/test/members_only')
        .success((resp) -> alert(resp.data.message))
        .error((resp) -> alert(resp.errors[0]))
