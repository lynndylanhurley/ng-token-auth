suite 'password update', ->
  suite 'successful password update', ->
    successResp =
      success: true

    setup ->
      $httpBackend
        .expectPUT('/api/auth/password')
        .respond(201, {success: true})

      $auth.updatePassword({
        password: 'secret123'
        password_confirmation: 'secret123'
      })

      $httpBackend.flush()

    test 'success event should return user info', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:password-change-success', successResp)

  suite 'failed password update', ->
    errorResp =
      success: false
      error: ['sry']

    setup ->
      $httpBackend
        .expectPUT('/api/auth/password')
        .respond(401, errorResp)

      $auth.updatePassword({
        password: 'secret123'
        password_confirmation: 'secret123'
      })

      $httpBackend.flush()

    test 'new user is defined in the root scope', ->
      assert.equal(undefined, $rootScope.user.uid)

    test 'success event should return user info', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:password-change-error', errorResp)
