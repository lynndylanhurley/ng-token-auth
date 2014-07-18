suite 'password change confirmation', ->
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

      $auth.validateUser()
      $httpBackend.flush()

    test 'that new user is defined in the root scope', ->
      assert.equal(validUser.uid, $rootScope.user.uid)

    test 'that $rootScope broadcast validation success event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:password-reset-confirm-success', validUser)

    test 'that $rootScope broadcast email confirmation success event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:validation-success', validUser)


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

      $auth.validateUser()
      $httpBackend.flush()

    test 'that new user is not defined in the root scope', ->
      assert.equal(undefined, $rootScope.user.uid)

    test 'that $rootScope broadcast password reset request error event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:password-reset-confirm-error', errorResp)

    test 'that $rootScope broadcast validation error event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:validation-error', errorResp)
