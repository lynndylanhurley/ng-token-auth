suite 'account delete', ->
  dfd = null
  setup ->
    angular.extend($rootScope.user, validUser)
    ipCookie('auth_headers', validAuthHeader, {path: '/'})

  suite 'successful deletion', ->
    successResp =
      success: true

    setup ->
      $httpBackend
        .expectDELETE('/api/auth')
        .respond(201, successResp)

      dfd = $auth.destroyAccount()

      $httpBackend.flush()

    test 'account delete event is broadcast by $rootScope', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:account-destroy-success', successResp)

    test 'user object is destroyed', ->
      assert.deepEqual($rootScope.user, {})

    test 'local auth headers are destroyed', ->
      assert.isUndefined $auth.retrieveData('auth_headers')

    test 'promise is resolved', ->
      resolved = false
      dfd.then(-> resolved = true)
      $timeout.flush()
      assert(resolved)

  suite 'failed update', ->
    failedResp =
      success: false
      errors: ['◃┆◉◡◉┆▷']

    setup ->
      $httpBackend
        .expectDELETE('/api/auth')
        .respond(403, failedResp)

      dfd = $auth.destroyAccount()

      $httpBackend.flush()

    test 'failed account delete event is broadcast by $rootScope', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:account-destroy-error', failedResp)

    test 'user is still defined on root scope', ->
      assert.deepEqual($rootScope.user, validUser)

    test 'auth headers persist', ->
      assert.deepEqual($auth.retrieveData('auth_headers'), validAuthHeader)

    test 'promise is rejected', ->
      caught = false
      dfd.catch(-> caught = true)
      $timeout.flush()
      assert(caught)
