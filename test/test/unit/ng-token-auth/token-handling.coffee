suite 'token handling', ->
  newAuthHeader = {
    "access-token": "(^_^)"
    "token-type":   'Bearer'
    client:         validClient
    expiry:         validExpiry.toString()
    uid:            validUid.toString()
  }
  dfd = null

  successResp =
    success: true
    data: validUser

  errorResp =
    errors: ['unauthorized']
    message: 'expired headers'

  suite 'header from response should be stored in cookies', ->
    setup ->
      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(201, successResp, newAuthHeader)

      ipCookie('auth_headers', validAuthHeader, {path: '/'})

      dfd = $auth.validateUser()

      $httpBackend.flush()

    test 'headers should be updated', ->
      assert.deepEqual(newAuthHeader, $auth.retrieveData('auth_headers'))

    test 'header is included with the next request to the api', ->
      $httpBackend
        .expectGET('/api/test', (headers) ->
          assert.equal(newAuthHeader['access-token'], headers['access-token'])
          headers
        )
        .respond(201, successResp, {'access-token', 'whatever'})

      $http.get('/api/test')

      $httpBackend.flush()

    test 'header is not included in requests to alternate apis', ->
      $httpBackend
        .expectGET('/alternate-api/test', (headers) ->
          assert.equal(null, headers['access-token'])
          headers
        )
        .respond(201, successResp, {'access-token', 'whatever'})

      $http.get('/alternate-api/test')

      $httpBackend.flush()


    test 'promise should be resolved', (done) ->
      dfd.then(->
        assert true
        done()
      )
      $timeout.flush()

    test 'subsequent calls to validateUser do not require api requests', (done) ->
      $auth.validateUser().then(->
        assert true
        done()
      )
      $timeout.flush()

      return false


  suite 'undefined headers', ->
    test 'validateUser should not make requests if no token is present', ->
      caught = false

      $auth.validateUser().catch(-> caught = true)
      $timeout.flush()
      assert(caught)


    test 'validation request should not be made if headers are empty', ->
      ipCookie('auth_headers', {}, {path: '/'})
      caught = false
      $auth.validateUser().catch(-> caught = true)
      $timeout.flush()
      assert(caught)

  suite 'undefined headers but forcing token validation', ->
    setup ->
      $auth.getConfig().forceValidateToken = true
      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(201, successResp, newAuthHeader)

    test 'validateUser should validate the token even if it is not present', ->
      caught = false
      $auth.validateUser().catch(-> caught = true)
      $timeout.flush()
      assert(!caught)

    test 'validation request should be made if headers are empty', ->
      ipCookie('auth_headers', {}, {path: '/'})
      caught = false
      $auth.validateUser().catch(-> caught = true)
      $timeout.flush()
      assert(!caught)

    teardown ->
      $httpBackend.flush()


  suite 'error response containing tokens', ->
    setup ->
      $httpBackend
        .expectGET('/api/err')
        .respond(401, errorResp, newAuthHeader)

      ipCookie('auth_headers', validAuthHeader, {path: '/'})
      dfd = $http.get('/api/err')
      $httpBackend.flush()

    test 'headers should be updated', ->
      assert.deepEqual(newAuthHeader, $auth.retrieveData('auth_headers'))

    test 'header is included with the next request to the api', ->
      $httpBackend
        .expectGET('/api/test', (headers) ->
          assert.equal(newAuthHeader['access-token'], headers['access-token'])
          headers
        )
        .respond(201, successResp, {'access-token', 'whatever'})

      $http.get('/api/test')

      $httpBackend.flush()


  suite 'invalid headers', ->
    setup ->
      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(401, errorResp)

      ipCookie('auth_headers', {'access-token': '(-_-)'}, {path: '/'})

      dfd = $auth.validateUser()

      $httpBackend.flush()

    test 'promise should be rejected', (done) ->
      dfd.catch(->
        assert true
        done()
      )
      $timeout.flush()

    test '$rootScope broadcasts invalid auth event', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:validation-error', errorResp)
      $timeout.flush()

  suite 'outdated headers', ->
    outdatedExpiry  = (new Date().getTime() / 1000) - 500 | 0
    outdatedHeaders = {
      "access-token": "(x_x)"
      "token-type":   'Bearer'
      client:         validClient
      expiry:         outdatedExpiry
      uid:            validUid
    }

    currentHeaders = {
      "access-token": "(^_^)"
      "token-type":   'Bearer'
      client:         validClient
      expiry:         validExpiry
      uid:            validUid.toString()
    }

    setup ->
      $auth.persistData('auth_headers', currentHeaders)
      $auth.user.signedIn = true
      $httpBackend
        .expectGET('/api/test')
        .respond(201, successResp, outdatedHeaders)

      $http.get('/api/test')

      $httpBackend.flush()

    test 'user is still authenticated', ->
      passed = false
      $auth.validateUser().then(->
        passed = true
      )
      $timeout.flush()
      assert passed

    test 'header was not updated', ->
      assert($auth.retrieveData('auth_headers')['access-token'])
      assert.equal(
        currentHeaders['access-token'],
        $auth.retrieveData('auth_headers')['access-token']
      )


  suite 'expired headers', ->
    expiredExpiry  = (new Date().getTime() / 1000) - 500 | 0
    expiredHeaders = {
      "access-token": "(x_x)"
      "token-type":   'Bearer'
      client:         validClient
      expiry:         expiredExpiry
      uid:            validUid
    }

    setup ->
      $auth.persistData('auth_headers', expiredHeaders)
      $auth.user.signedIn = true

    test 'promise should be rejected without making request', ->
      caught = false
      $auth.validateUser().catch(->
        caught = true
      )
      $timeout.flush()
      assert caught

    test 'expired session event should be broadcast', ->
      $auth.validateUser()
      $timeout.flush()
      assert $rootScope.$broadcast.calledWith('auth:session-expired')

    test 'tokens are invalidated', ->
      $auth.validateUser()
      $timeout.flush()
      assert.equal(null, $auth.retrieveData('auth_headers'))

  suite 'empty response', ->
    setup ->
      $auth.getConfig().forceValidateToken = true
      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(401, undefined)

      dfd = $auth.validateUser()

      $httpBackend.flush()

    test 'promise should be rejected without error', (done) ->
      dfd.catch(->
        assert true
        done()
      )
      $timeout.flush()