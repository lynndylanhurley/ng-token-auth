suite 'alternate storage', ->
  newAuthHeader = {
    "access-token": "(^_^)"
    "token-type":   'Bearer'
    client:         validClient
    expiry:         validExpiry.toString()
    uid:            validUid.toString()
  }

  successResp =
    success: true
    data: validUser

  suite 'localStorage', ->
    # configure for local storage
    setup ->
      $authProvider.configure({
        storage: 'localStorage'
      })

    # restore config defaults
    teardown ->
      $authProvider.configure({
        storage: 'cookies'
      })

    suite 'token validation', ->
      setup ->
        $httpBackend
          .expectGET('/api/auth/validate_token')
          .respond(201, successResp, newAuthHeader)

        $window.localStorage.setItem('auth_headers', JSON.stringify(validAuthHeader))

        $auth.validateUser()

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

    suite 'sign out', ->
      setup ->
        $httpBackend
          .expectDELETE('/api/auth/sign_out')
          .respond(201, successResp)

        $window.localStorage.setItem('auth_headers', JSON.stringify(validAuthHeader))

        $auth.signOut()

        $httpBackend.flush()

      test '$rootScope should broadcast logout success event', ->
        assert $rootScope.$broadcast.calledWith('auth:logout-success')

      test 'localStorage item should no longer be present', ->
        assert($cookieStore.get('auth_headers') == undefined)
