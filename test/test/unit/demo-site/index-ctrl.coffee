suite 'IndexCtrl', ->
  createController = null
  scope            = null

  setup ->
    scope = $rootScope.$new()

    createController = ->
      $controller('IndexCtrl', {
        '$scope': scope
      })


  test 'sanity', ->
    ctrl = createController()
    assert(ctrl)
    assert.equal('bang', scope.test())
