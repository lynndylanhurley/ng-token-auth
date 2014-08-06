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
      assert.equal apiUrl, $auth.config.apiUrl

    test '$auth proxies to proxy url', ->
      assert.equal '/proxy', $auth.apiUrl()

  suite 'alternate token format', ->
    expectedHeaders =
      "access_token": "#{validToken}"
      "token_type":   "Bearer"
      "username":     "#{validUid}"
      "expiry":       "#{validExpiry}"

    setup ->
      $authProvider.configure({
        tokenFormat:
          "access_token": "{{ token }}"
          "token_type":   "Bearer"
          "username":     "{{ uid }}"
          "expiry":       "{{ expiry }}"

        parseExpiry: (headers) ->
          headers['expiry']
      })

    teardown ->
      $authProvider.configure({
        tokenFormat:
          "Authorization": "token={{ token }} client={{ clientId }} expiry={{ expiry }} uid={{ uid }}"

        parseExpiry: (headers) ->
          expiry = headers.match(/expiry=([^ ]+) /)
          if expiry
            expiry = parseInt(expiry[1], 10) * 1000 # convert from ruby time
          else
            null
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
