suite 'configuration', ->
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
