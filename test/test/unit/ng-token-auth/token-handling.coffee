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

      $cookieStore.put('auth_headers', validAuthHeader)

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
      $auth.validateUser().catch(-> assert true)
      $timeout.flush()

    test 'validation request should not be made if headers are empty', ->
      $cookieStore.put('auth_headers', {})
      $auth.validateUser().catch(-> assert true)
      $timeout.flush()


  suite 'error response containing tokens', ->
    setup ->
      $httpBackend
        .expectGET('/api/err')
        .respond(401, errorResp, newAuthHeader)

      $cookieStore.put('auth_headers', validAuthHeader)
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

      $cookieStore.put('auth_headers', {'access-token': '(-_-)'})

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
