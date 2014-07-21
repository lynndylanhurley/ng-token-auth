suite 'sign out', ->
  successResp =
    success: true

  errorResp =
    success: false
    errors: ['fregg.jpg']

  suite 'successful request', ->
    setup ->
      $httpBackend
        .expectDELETE('/api/auth/sign_out')
        .respond(201, successResp)

      $auth.signOut()

      $httpBackend.flush()

    test '$rootScope should broadcast success event', ->
      assert $rootScope.$broadcast.calledWith('auth:logout-success')


  suite 'directive access', ->
    setup ->
      $httpBackend
        .expectDELETE('/api/auth/sign_out')
        .respond(201, successResp)

      sinon.spy($auth, 'signOut')

      $rootScope.signOut()

      $httpBackend.flush()

    test '$auth.signOut was called from $rootScope', ->
      assert $auth.signOut.called


  suite 'failed request', ->
    setup ->
      $httpBackend
        .expectDELETE('/api/auth/sign_out')
        .respond(401, errorResp)

      $auth.signOut()

      $httpBackend.flush()

    test '$rootScope should broadcast error event', ->
      assert $rootScope.$broadcast.calledWith('auth:logout-error')
