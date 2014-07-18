suite 'email user sign in', ->
  suite 'successful sign in', ->
    setup ->
      $httpBackend
        .expectPOST('/api/auth/sign_in')
        .respond(201, {
          success: true
          data: validUser
        })

      $auth.submitLogin({
        email: validUser.email
        password: 'secret123'
      })

      $httpBackend.flush()

    test 'new user is defined in the root scope', ->
      assert.equal(validUser.uid, $rootScope.user.uid)

    test 'success event should return user info', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:login-success', validUser)

  suite 'failed sign in', ->
    errorResp =
      success: false
      error: ['ugh']

    setup ->
      $httpBackend
        .expectPOST('/api/auth/sign_in')
        .respond(401, errorResp)

      $auth.submitLogin({
        email: validUser.email
        password: 'secret123'
      })

      $httpBackend.flush()

    test 'new user is defined in the root scope', ->
      assert.equal(undefined, $rootScope.user.uid)

    test 'success event should return user info', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:login-error', errorResp)
