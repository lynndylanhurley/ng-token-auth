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
      "Authorization": "token=#{validToken} expiry=#{validExpiry} uid=#{validUid}"

    setup ->
      $authProvider.configure({
        tokenFormat:
          "Authorization": "token={{token}} expiry={{expiry}} uid={{uid}}"

        parseExpiry: (headers) ->
          console.log 'headers', headers
          (parseInt(headers['Authorization'].match(/expiry=([^ ]+) /)[1], 10)) || null
      })

    teardown ->
      $authProvider.configure({
        tokenFormat:
          access_token: "{{ token }}"
          token_type:   "Bearer"
          client:       "{{ clientId }}"
          expiry:       "{{ expiry }}"
          uid:          "{{ uid }}"

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
