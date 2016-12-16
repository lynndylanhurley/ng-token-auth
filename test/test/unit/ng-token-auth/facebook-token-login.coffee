suite 'oauth access token sign in', ->
  dfd = null
  accessToken = 'token123'
  suite 'successful sign in', ->
    expectedUser =
      id:         validUser.id
      uid:        validUser.uid
      email:      validUser.email
      auth_token: validToken
      expiry:     validExpiry
      client_id:  validClient
      signedIn:   true
      configName: "default"

    suite 'using config options', ->
      test 'optional params are sent', ->
        $httpBackend
          .expectGET("/api/auth/facebook_access_token/callback?access_token=#{accessToken}&spirit_animal=scorpion")
          .respond(201, {
            success: true
            data: expectedUser
          })
        dfd = $auth.authenticateAccessToken('facebookAccessToken', accessToken, {params: {spirit_animal: 'scorpion'}})

        $httpBackend.flush()

    suite 'with existing user', -> 
      setup ->
        $httpBackend
          .expectGET("/api/auth/facebook_access_token/callback?access_token=#{accessToken}")
          .respond(201, {
            success: true
            data: expectedUser
          })

        dfd = $auth.authenticateAccessToken('facebookAccessToken', accessToken)

        $httpBackend.flush()


      test 'user should be authenticated, promise is resolved', (done) ->
        called = false
        dfd.then(=>
          called = true
        )

        setTimeout ->
          $timeout.flush()
          assert.deepEqual($rootScope.user, expectedUser)
          assert $rootScope.$broadcast.calledWith('auth:login-success')
          assert $rootScope.$broadcast.neverCalledWith('auth:oauth-registration')
          assert(called)
          done()

      test 'expiry is set', (done) ->
        setTimeout ->
          $timeout.flush()
          assert.equal(validExpiry * 1000, $auth.getConfig().parseExpiry($auth.retrieveData('auth_headers')))
          done()

    suite 'with new user', ->
      setup ->
        $httpBackend
          .expectGET("/api/auth/facebook_access_token/callback?access_token=#{accessToken}")
          .respond(201, {
            success: true
            data: angular.extend({oauth_registration: true}, expectedUser)
          })

        dfd = $auth.authenticateAccessToken('facebookAccessToken', accessToken)

        $httpBackend.flush()

      test 'should fire oauth-registration event', (done) ->
        called = false
        dfd.then(=>
          called = true
        )

        setTimeout ->
          $timeout.flush()
          assert $rootScope.$broadcast.calledWithMatch('auth:oauth-registration', expectedUser)
          assert(called)
          done()

  suite 'failed sign in', ->
    errorResp =
      success: false
      error: ['ugh']

    setup ->
      $httpBackend
        .expectGET("/api/auth/facebook_access_token/callback?access_token=#{accessToken}")
        .respond(401, errorResp)

      dfd = $auth.authenticateAccessToken('facebookAccessToken', accessToken)

      $httpBackend.flush()

    test 'user is undefined in the root scope', ->
      assert.equal(undefined, $rootScope.user.uid)

    test 'error event should return error response', ->
      assert $rootScope.$broadcast.calledWithMatch('auth:login-error', errorResp)

    test 'promise is rejected', ->
      caught = false
      dfd.catch(-> caught = true)
      $timeout.flush()
      assert(caught)