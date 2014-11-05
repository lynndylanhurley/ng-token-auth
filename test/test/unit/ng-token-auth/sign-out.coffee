suite 'sign out', ->
  dfd = null

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

      ipCookie('auth_headers', validAuthHeader, {path: '/'})

      dfd = $auth.signOut()

      $httpBackend.flush()


    test '$rootScope should broadcast success event', ->
      assert $rootScope.$broadcast.calledWith('auth:logout-success')


    test 'cookie should no longer be present', ->
      assert(ipCookie('auth_headers') == undefined)


    test 'promise is resolved', ->
      resolved = false
      dfd.then(-> resolved = true)
      $timeout.flush()
      assert(resolved)


  suite 'directive access', ->
    test '$auth.signOut was called from $rootScope', ->
      $httpBackend
        .expectDELETE('/api/auth/sign_out')
        .respond(201, successResp)

      sinon.spy($auth, 'signOut')

      $rootScope.signOut()

      $httpBackend.flush()


  suite 'failed request', ->
    setup ->
      $httpBackend
        .expectDELETE('/api/auth/sign_out')
        .respond(401, errorResp)

      ipCookie('auth_headers', validAuthHeader, {path: '/'})

      dfd = $auth.signOut()

      $httpBackend.flush()


    test '$rootScope should broadcast error event', ->
      assert $rootScope.$broadcast.calledWith('auth:logout-error')


    test 'cookie should no longer be present', ->
      assert(ipCookie('auth_headers') == undefined)


    test 'promise is rejected', ->
      caught = false
      dfd.catch(-> caught = true)
      $timeout.flush()
      assert(caught)
