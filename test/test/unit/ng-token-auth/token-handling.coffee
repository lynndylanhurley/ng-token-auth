suite 'cookie store', ->
  newAuthHeader = "token=(^_^) client=#{validClient} expiry=12345 uid=#{validUid}"
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
        .respond(201, successResp, {'Authorization': newAuthHeader})

      $cookieStore.put('auth_header', '(^^,)')

      dfd = $auth.validateUser()

      $httpBackend.flush()

    test 'headers should be updated', ->
      assert.equal(newAuthHeader, $auth.header)

    test 'header is included with the next request to the api', ->
      $httpBackend
        .expectGET('/api/test', (headers) ->
          assert.equal(newAuthHeader, headers.Authorization)
          headers
        )
        .respond(201, successResp, {'Authorization', 'whatever'})

      $http.get('/api/test')

      $httpBackend.flush()

    test 'header is not included in requests to alternate apis', ->
      $httpBackend
        .expectGET('/alternate-api/test', (headers) ->
          assert.equal(null, headers.Authorization)
          headers
        )
        .respond(201, successResp, {'Authorization', 'whatever'})

      $http.get('/alternate-api/test')

      $httpBackend.flush()


    test 'promise should be resolved', (done) ->
      dfd.then(->
        assert true
        done()
      )
      $timeout.flush()

    test 'subsequent calls do not require api requests', (done) ->
      $auth.validateUser().then(->
        assert true
        done()
      )
      $timeout.flush()

      return false


  suite 'invalid headers', ->
    setup ->
      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(401, errorResp)

      $cookieStore.put('auth_header', '(-_-)')

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
