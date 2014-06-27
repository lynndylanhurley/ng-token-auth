angular.module('ngTokenAuthTestApp')
  .directive 'scrollTo', ($location, $anchorScroll) ->
    restrict: 'A'
    scope:
      scrollTo: '@'

    link: (scope, el, attrs) ->
      el.click ->
        $location.hash(attrs.href.replace('#', ''))
        $anchorScroll()
        return false
