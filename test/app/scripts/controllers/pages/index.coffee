angular.module('ngTokenAuthTestApp')
  .controller 'IndexCtrl', ($scope, $auth, $http, $q) ->
    Prism.highlightAll()

    # this method tests controller injection sanity
    $scope.test = -> 'bang'
