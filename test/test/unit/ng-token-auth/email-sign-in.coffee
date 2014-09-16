suite 'email user sign in', ->
  dfd = null
  suite 'successful sign in', ->
    setup ->
      $httpBackend
        .expectPOST('/api/auth/sign_in')
        .respond(201, {
          success: true
          data: validUser
        })

      dfd = $auth.submitLogin({
        email: validUser.email
        password: 'secret123'
      })

      $httpBackend.flush()

    test 'new user is defined in the root scope', ->
      assert.equal(validUser.uid, $rootScope.user.uid)

    test 'success event should return user info', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:login-success', validUser)

    test 'promise is resolved', ->
      resolved = false
      dfd.then(-> resolved = true)
      $timeout.flush()
      assert(resolved)

  suite 'directive access', ->
    args =
      email: validUser.email
      password: 'secret123'

    test '$auth.submitLogin was called from $rootScope', ->
      $httpBackend
        .expectPOST('/api/auth/sign_in')
        .respond(201, {
          success: true
          data: validUser
        })

      sinon.spy($auth, 'submitLogin')

      $rootScope.submitLogin(args)

      $httpBackend.flush()


  suite 'failed sign in', ->
    errorResp =
      success: false
      error: ['ugh']

    setup ->
      $httpBackend
        .expectPOST('/api/auth/sign_in')
        .respond(401, errorResp)

      dfd = $auth.submitLogin({
        email: validUser.email
        password: 'secret123'
      })

      $httpBackend.flush()

    test 'new user is defined in the root scope', ->
      assert.equal(undefined, $rootScope.user.uid)

    test 'success event should return user info', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:login-error', errorResp)

    test 'promise is rejected', ->
      caught = false
      dfd.catch(-> caught = true)
      $timeout.flush()
      assert(caught)
