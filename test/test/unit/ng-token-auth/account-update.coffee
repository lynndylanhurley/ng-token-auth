suite 'account update', ->
  suite 'successful update', ->
    updatedUser = angular.copy(validUser, {operating_thetan: 123})
    successResp =
      success: true
      data: updatedUser

    setup ->
      $httpBackend
        .expectPUT('/api/auth')
        .respond(201, successResp)

      $auth.updateAccount({
        operating_thetan: 123
      })

      $httpBackend.flush()

    test 'user update event is broadcast by $rootScope', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:account-update-success', successResp)

    test 'user object is updated', ->
      assert.deepEqual($rootScope.user, updatedUser)

  suite 'failed update', ->
    failedResp =
      success: false
      errors: ['(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧']

    setup ->
      $httpBackend
        .expectPUT('/api/auth')
        .respond(403, failedResp)

      $auth.updateAccount({
        operating_thetan: 123
      })

      $httpBackend.flush()

    test 'user update event is broadcast by $rootScope', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:account-update-error', failedResp)
