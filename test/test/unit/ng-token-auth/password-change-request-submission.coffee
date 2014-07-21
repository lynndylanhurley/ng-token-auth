suite 'email user password change request', ->
  suite 'successful request', ->
    setup ->
      $httpBackend
        .expectPOST('/api/auth/password')
        .respond(201, {success: true})

      $auth.requestPasswordReset({
        email: validUser.email
      })

      $httpBackend.flush()

    test '$rootScope should broadcast success event', ->
      assert $rootScope.$broadcast.calledWith('auth:password-reset-request-success')

  suite 'directive access', ->
    args =
      email: validUser.email

    setup ->
      $httpBackend
        .expectPOST('/api/auth/password')
        .respond(201, {success: true})

      sinon.spy($auth, 'requestPasswordReset')

      $rootScope.requestPasswordReset(args)

      $httpBackend.flush()

    test '$rootScope should broadcast success event', ->
      assert $auth.requestPasswordReset.calledWithMatch(args)

  suite 'failed request', ->
    errorResp =
      success: false
      errors: ['blehg']

    setup ->
      $httpBackend
        .expectPOST('/api/auth/password')
        .respond(401, errorResp)

      $auth.requestPasswordReset({
        email: validUser.email
      })

      $httpBackend.flush()

    test '$rootScope should broadcast error event with response', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:password-reset-request-error', errorResp)
