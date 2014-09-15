suite 'configuration', ->
  suite 'basic settings', ->
    apiUrl = '/kronos'

    setup ->
      sinon.spy($auth, 'validateUser')

      $authProvider.configure({
        apiUrl: apiUrl
        validateOnPageLoad: true
        proxyIf: -> true
      })

    # restore defaults
    teardown ->
      $authProvider.configure({
        apiUrl: '/api'
        proxyIf: -> false
      })

    test 'apiUrl has been changed', ->
      assert.equal apiUrl, $auth.getConfig().apiUrl

    test '$auth proxies to proxy url', ->
      assert.equal '/proxy', $auth.apiUrl()

    test 'headers are appended to requests to proxy', ->
      successResp =
        success: true
        data: validUser

      $cookieStore.put('auth_headers', validAuthHeader)

      $httpBackend
        .expectGET('/proxy/auth/validate_token', (headers) ->
          console.log 'validAuthHeader', validAuthHeader['access-token']
          console.log 'cur', headers['access-token']
          assert.equal(validAuthHeader['access-token'], headers['access-token'])
          headers
        )
        .respond(201, successResp, {'access-token', 'whatever'})

      $auth.validateUser()
      $httpBackend.flush()

  suite 'alternate token format', ->
    expectedHeaders =
      "Authorization": "token=#{validToken} expiry=#{validExpiry} uid=#{validUid}"

    setup ->
      $authProvider.configure({
        tokenFormat:
          "Authorization": "token={{token}} expiry={{expiry}} uid={{uid}}"

        parseExpiry: (headers) ->
          (parseInt(headers['Authorization'].match(/expiry=([^ ]+) /)[1], 10)) || null
      })

    teardown ->
      $authProvider.configure({
        tokenFormat:
          "access-token": "{{ token }}"
          "token-type":   "Bearer"
          client:         "{{ clientId }}"
          expiry:         "{{ expiry }}"
          uid:            "{{ uid }}"

        parseExpiry: (headers) ->
          (parseInt(headers['expiry'], 10) * 1000) || null
      })

    test 'auth headers are built according to config.tokenFormat', ->
      headers = $auth.buildAuthHeaders({
        token:    validToken
        clientId: validClient
        uid:      validUid
        expiry:   validExpiry
      })

      assert.deepEqual(headers, expectedHeaders)

    test 'expiry should be derived from cached headers', ->
      $auth.setAuthHeaders(expectedHeaders)
      expiry = $auth.getExpiry()
      assert.equal(expiry, validExpiry)

  suite 'alternate login response format', ->
    setup ->
      # define custom login response handler
      $authProvider.configure({
        handleLoginResponse: (resp) -> resp
      })

      # return non-standard login response format
      $httpBackend
        .expectPOST('/api/auth/sign_in')
        .respond(201, validUser)

      $auth.submitLogin({
        email: validUser.email
        password: 'secret123'
      })

      $httpBackend.flush()

    teardown ->
      # restore default login response handler
      $authProvider.configure({
        handleLoginResponse: (resp) -> resp.data
      })

    test 'new user is defined in the root scope', ->
      assert.equal(validUser.uid, $rootScope.user.uid)

    test 'success event should return user info', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:login-success', validUser)


  suite 'alternate token validation response format', ->
    successResp = validUser
    newAuthHeader = {
      "access-token": "(✿◠‿◠)"
      "token-type":   'Bearer'
      client:         validClient
      expiry:         validExpiry.toString()
      uid:            validUid.toString()
    }
    dfd = null

    setup ->
      # define custom token validation response handler
      $authProvider.configure({
        handleTokenValidationResponse: (resp) -> resp
      })

      $httpBackend
        .expectGET('/api/auth/validate_token')
        .respond(201, successResp, newAuthHeader)

      $cookieStore.put('auth_headers', validAuthHeader)

      $auth.validateUser()

      $httpBackend.flush()

    teardown ->
      # restore default token validation response handler
      $authProvider.configure({
        handleTokenValidationResponse: (resp) -> resp.data
      })

    test 'new user is defined in the root scope', ->
      assert.equal(validUser.uid, $rootScope.user.uid)
