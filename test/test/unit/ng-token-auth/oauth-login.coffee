suite 'oauth2 login', ->
  dfd = null

  suite 'using postMessage', ->
    popupWindow =
      closed: false
      postMessage: ->

    setup ->
      # disable popup behavior
      $window.open = -> popupWindow

      # verify that popup was initiated
      sinon.spy($window, 'open')

      dfd = $auth.authenticate('github')

      return false

    suite 'postMessage success', ->
      test 'user should be authenticated', (done)->
        called = false
        dfd.then(=>
          called = true
        )

        # fake response from api redirect
        $window.postMessage({
          message:    "deliverCredentials"
          id:         validUser.id
          uid:        validUser.uid
          email:      validUser.email
          auth_token: validToken
          client_id:  validClient
        }, '*')

        setTimeout((->
          $timeout.flush()

          assert.deepEqual($rootScope.user, {
            id:         validUser.id
            uid:        validUser.uid
            email:      validUser.email
            auth_token: validToken
            client_id:  validClient
          })

          assert(true, called)

          done()
        ))

    suite 'postMessage error', (done) ->
      errorResponse =
        message: 'authFailure'
        errors: ['420']

      setup ->
        sinon.spy($auth, 'cancel')

      test 'error response cancels authentication', (done) ->
        called = false

        dfd.finally(->
          called = true
        )

        # fake response from api redirect
        $window.postMessage(errorResponse, '*')

        setTimeout((->
          $timeout.flush()
          assert true, called
          assert $auth.cancel.called
          assert $rootScope.$broadcast.calledWith('auth:login-error')
          done()
        ), 0)


    suite 'postMessage window closed before message is sent', ->
      setup ->
        sinon.spy($auth, 'cancel')

      teardown ->
        popupWindow.closed = false

      test 'auth is cancelled', (done) ->
        called = false

        dfd.catch =>
          called = true

        popupWindow.closed = true

        $timeout.flush()

        assert $auth.cancel.called
        assert.equal(true, called)
        assert.equal(null, $auth.t)
        done()


    suite 'cancel method', ->
      test 'timer is rejected then nullified', (done) ->
        called = false

        $auth.t.catch =>
          called = true

        $auth.cancel()

        # wait for reflow
        setTimeout((->
          $timeout.flush()
          assert.equal(true, called)
          assert.equal(null, $auth.t)
          done()
        ), 0)

      test 'promise is rejected then nullified', (done) ->
        called = false

        $auth.dfd.promise.catch ->
          called = true

        $auth.cancel()

        # wait for reflow
        setTimeout((->
          $timeout.flush()
          assert.equal(true, called)
          assert.equal(null, $auth.dfd)
          done()
        ), 0)

  suite 'using hard redirect', ->
    successResp =
      success: true
      data: validUser

    suite 'to api', ->
      redirectUrl = null

      setup ->
        redirectUrl = $auth.buildAuthUrl('github')
        $authProvider.configure({forceHardRedirect: true})

        # mock location replace, create spy
        sinon.stub($location, 'replace').returns(null)

        $auth.authenticate('github')
        return false

      teardown ->
        $authProvider.configure({forceHardRedirect: false})

      test 'location should be replaced', ->
        assert($location.replace.calledWithMatch(redirectUrl))

    suite 'on return from api', ->
      setup ->
        $httpBackend
          .expectGET('/api/auth/validate_token')
          .respond(201, successResp)

        setValidAuthQS()

        $auth.validateUser()
        $httpBackend.flush()

      test 'new user is not defined in the root scope', ->
        assert.equal(validUser.uid, $rootScope.user.uid)

      test '$rootScope broadcast validation success event', ->
        assert $rootScope.$broadcast.calledWithMatch('auth:validation-success', validUser)
