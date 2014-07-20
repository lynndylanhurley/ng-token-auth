suite 'configuration', ->
  apiUrl = '/kronos'

  setup ->
    $authProvider.configure({
      apiUrl: apiUrl
    })

  # restore defaults
  teardown ->
    $authProvider.configure({
      apiUrl: '/api'
    })

  test 'apiUrl has been changed', ->
    assert.equal apiUrl, $auth.config.apiUrl
