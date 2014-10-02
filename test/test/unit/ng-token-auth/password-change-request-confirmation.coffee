suite 'password change confirmation', ->
  dfd = null
  suite 'successful authentication', ->
    successResp =
      sucess: true
      data:   validUser

    setup ->
      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(201, successResp)

      # mock the querystring for the password reset confirmation link
      setValidPasswordConfirmQS()

      dfd = $auth.validateUser()
      $httpBackend.flush()

    test 'that new user is defined in the root scope', ->
      assert.equal(validUser.uid, $rootScope.user.uid)

    test 'that $rootScope broadcast validation success event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:password-reset-confirm-success', validUser)

    test 'that $rootScope broadcast email confirmation success event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:validation-success', validUser)

    test 'token expiry is set', ->
      assert.equal(validExpiry * 1000, $auth.getConfig().parseExpiry($auth.retrieveData('auth_headers')))

    test 'promise is resolved', ->
      resolved = false
      dfd.then(-> resolved = true)
      $timeout.flush()
      assert(resolved)


  suite 'failed authentication', ->
    errorResp =
      sucess: false
      errors: ['xxx']

    setup ->
      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(401, errorResp)

      # mock the querystring for the email confirmation link
      setValidPasswordConfirmQS()

      dfd = $auth.validateUser()
      $httpBackend.flush()

    test 'that new user is not defined in the root scope', ->
      assert.equal(undefined, $rootScope.user.uid)

    test 'that $rootScope broadcast password reset request error event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:password-reset-confirm-error', errorResp)

    test 'that $rootScope broadcast validation error event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:validation-error', errorResp)

    test 'promise is rejected', ->
      caught = false
      dfd.catch(-> caught = true)
      $timeout.flush()
      assert(caught)
