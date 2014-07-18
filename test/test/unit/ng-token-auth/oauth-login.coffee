suite 'oauth2 login', ->
  suite 'success', ->
    suite 'using postMessage', ->
      dfd = null

      setup ->
        # disable popup behavior
        $window.open = ->
          closed: false
          postMessage: ->

        # verify that popup was initiated
        sinon.spy($window, 'open')

        dfd = $auth.authenticate('github')

        # fake response from api redirect
        $window.postMessage({
          message:    "deliverCredentials"
          id:         validUser.id
          uid:        validUser.uid
          email:      validUser.email
          auth_token: validToken
          client_id:  validClient
        }, '*')

      test 'user should be authenticated', (done) ->
        dfd.then(=>
          assert.deepEqual($rootScope.user, {
            id:         validUser.id
            uid:        validUser.uid
            email:      validUser.email
            auth_token: validToken
            client_id:  validClient
          })
        )

        setTimeout(done, 1500)

    suite 'using hard redirect', ->
      successResp =
        success: true
        data: validUser

      setup ->
        $httpBackend
          .expectGET('/api/auth/validate_token')
          .respond(201, successResp)

        setValidAuthQS()

        $auth.validateUser()
        $httpBackend.flush()

      test 'that new user is not defined in the root scope', ->
        assert.equal(validUser.uid, $rootScope.user.uid)

      test 'that $rootScope broadcast validation success event', ->
        assert $rootScope.$broadcast.calledWithMatch('auth:validation-success', validUser)
