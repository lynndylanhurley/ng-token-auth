suite 'configuration', ->
  apiUrl = '/kronos'

  setup ->
    sinon.spy($auth, 'validateUser')

    $authProvider.configure({
      apiUrl: apiUrl
      validateOnPageLoad: true
    })

  # restore defaults
  teardown ->
    $authProvider.configure({
      apiUrl: '/api'
    })

  test 'apiUrl has been changed', ->
    assert.equal apiUrl, $auth.config.apiUrl
