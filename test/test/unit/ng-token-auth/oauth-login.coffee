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

    suite 'using config options', ->
      test 'optional params are sent', ->
        expectedAuthUrl = $auth.apiUrl() +
          $auth.getConfig().authProviderPaths['github'] +
          '?auth_origin_url=' +
          encodeURIComponent(window.location.href) +
          '&spirit_animal=scorpion'

        $auth.authenticate('github', {params: {spirit_animal: 'scorpion'}})
        assert $window.open.calledWith(expectedAuthUrl)

    suite 'defaults config', ->
      setup ->
        dfd = $auth.authenticate('github')
        return false


      suite 'postMessage success', ->
        expectedUser =
          id:         validUser.id
          uid:        validUser.uid
          email:      validUser.email
          auth_token: validToken
          expiry:     validExpiry
          client_id:  validClient
          signedIn:   true
          configName: "default"

        setup ->
          # mock pm response
          $window.postMessage(angular.extend({message: 'deliverCredentials'}, expectedUser), '*')


        test 'user should be authenticated, promise is resolved', (done) ->
          called = false
          dfd.then(=>
            called = true
          )

          setTimeout ->
            $timeout.flush()
            assert.deepEqual($rootScope.user, expectedUser)
            assert(called)
            done()


        test 'expiry is set', (done) ->
          setTimeout ->
            $timeout.flush()
            assert.equal(validExpiry * 1000, $auth.getConfig().parseExpiry($auth.retrieveData('auth_headers')))
            done()


      suite 'directive access', ->
        args = 'github'

        test '$auth.authenticate was called from $rootScope', ->
          dfd = $rootScope.authenticate('github')
          dfd.then(-> assert(true))
          $timeout.flush()


      suite 'postMessage error', (done) ->
        errorResponse =
          message: 'authFailure'
          errors: ['420']

        setup ->
          sinon.spy($auth, 'cancel')

        test 'error response cancels authentication, rejects promise', (done) ->
          caught = false

          dfd.catch(->
            caught = true
          )

          # fake response from api redirect
          $window.postMessage(errorResponse, '*')

          setTimeout((->
            $timeout.flush()
            assert true, caught
            assert $auth.cancel.called
            assert $rootScope.$broadcast.calledWith('auth:login-error')
            done()
          ), 0)

      suite 'postMessage window closed before message is sent', ->
        setup ->
          sinon.spy($auth, 'cancel')

        teardown ->
          popupWindow.closed = false

        test 'auth is cancelled, promise is rejected', (done) ->
          caught = false

          dfd.catch =>
            caught = true

          popupWindow.closed = true

          $timeout.flush()

          assert $auth.cancel.called
          assert.equal(true, caught)
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
        sinon.stub($auth, 'visitUrl').returns(null)

        $auth.authenticate('github')
        return false

      teardown ->
        $authProvider.configure({forceHardRedirect: false})

      test 'location should be replaced', ->
        assert($auth.visitUrl.calledWithMatch(redirectUrl))

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
