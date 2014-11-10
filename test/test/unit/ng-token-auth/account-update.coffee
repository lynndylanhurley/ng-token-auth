suite 'account update', ->
  dfd = null
  suite 'successful update', ->
    updatedUser = angular.extend(validUser, {operating_thetan: 123, uid: 'updated_uid'})
    successResp =
      success: true
      data: updatedUser

    setup ->

      $httpBackend
        .expectPUT('/api/auth')
        .respond(201, successResp)

      sinon.stub($auth, 'retrieveData').returns({uid: validUser.uid})
      sinon.spy($auth, 'setAuthHeaders')

      dfd = $auth.updateAccount({
        operating_thetan: 123
      })

      $httpBackend.flush()

    test 'user update event is broadcast by $rootScope', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:account-update-success', successResp)

    test 'user object is updated', ->
      assert.deepEqual($rootScope.user, updatedUser)

    test 'auth_headers is updated with new uid', ->
      assert $auth.setAuthHeaders.calledWith({uid: 'updated_uid'})

    test 'promise is resolved', ->
      resolved = false
      dfd.then(-> resolved = true)
      $timeout.flush()
      assert(resolved)

  suite 'failed update', ->
    failedResp =
      success: false
      errors: ['(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧']

    setup ->
      $httpBackend
        .expectPUT('/api/auth')
        .respond(403, failedResp)

      dfd = $auth.updateAccount({
        operating_thetan: 123
      })

      $httpBackend.flush()

    test 'user update event is broadcast by $rootScope', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:account-update-error', failedResp)

    test 'promise is rejected', ->
      caught = false
      dfd.catch(-> caught = true)
      $timeout.flush()
      assert(caught)
