suite 'oauth2 login', ->
  dfd = null

  suite 'using newWindow', ->
    popupWindow =
      closed: false
      postMessage: ->

    setup ->

      $authProvider.configure({omniauthWindowType: 'newWindow'})

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
          '&spirit_animal=scorpion&omniauth_window_type=newWindow'

        $auth.authenticate('github', {params: {spirit_animal: 'scorpion'}})
        assert $window.open.calledWith(expectedAuthUrl, '_blank')

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

        suite 'with existing user', -> 
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
            # mock pm response
            $window.postMessage(angular.extend({message: 'deliverCredentials', oauth_registration: true}, expectedUser), '*')


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
          assert.equal(null, $auth.requestCredentialsPollingTimer)
          done()


      suite 'cancel method', ->
        test 'timer is rejected then nullified', (done) ->
          called = false

          $auth.requestCredentialsPollingTimer.catch =>
            called = true

          $auth.cancel()

          # wait for reflow
          setTimeout((->
            $timeout.flush()
            assert.equal(true, called)
            assert.equal(null, $auth.requestCredentialsPollingTimer)
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

  suite 'using sameWindow', ->
    successResp =
      success: true
      data: validUser

    suite 'to api', ->
      redirectUrl = null

      setup ->
        redirectUrl = $auth.buildAuthUrl('sameWindow', 'github')
        $authProvider.configure({omniauthWindowType: 'sameWindow'})

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

  suite 'using inAppBrowser', ->

    listeners = {}
    response = {}

    popupWindow = 
        addEventListener: (eventName, callback) -> 
          listeners[eventName] = callback
        removeEventListener: -> (eventName, callback) ->
          i = 0
          while listeners[eventName][i]
            if listeners[eventName][i] == callback
              delete listeners[eventName][i] 
            else
              i += 1
        dispatchEvent: (event) ->
          listeners[event.type](event)
        closed: false
        close: (->)
        executeScript: (code, callback) ->
          callback([response]) # inAppBrowser wraps values in array



    setup ->

      $authProvider.configure({omniauthWindowType: 'inAppBrowser'})

      # disable popup behavior
      $window.open = -> popupWindow

      # verify that popup was initiated
      sinon.stub($window, 'open').returns(popupWindow)

    suite 'using config options', ->
      test 'optional params are sent', ->
        expectedAuthUrl = $auth.apiUrl() +
          $auth.getConfig().authProviderPaths['github'] +
          '?auth_origin_url=' +
          encodeURIComponent(window.location.href) +
          '&spirit_animal=scorpion&omniauth_window_type=inAppBrowser'

        $auth.authenticate('github', {params: {spirit_animal: 'scorpion'}})
        assert $window.open.calledWith(expectedAuthUrl, '_blank')

    suite 'defaults config', ->
      setup ->
        dfd = $auth.authenticate('github')
        return false


      suite 'executeScript success', ->
        expectedUser =
          id:         validUser.id
          uid:        validUser.uid
          email:      validUser.email
          auth_token: validToken
          expiry:     validExpiry
          client_id:  validClient
          signedIn:   true
          configName: "default"

        suite 'with existing user', -> 
          setup ->
            response = angular.extend({message: 'deliverCredentials'}, expectedUser)

          test 'user should be authenticated, promise is resolved', (done) ->
            called = false
            dfd.then(=>
              called = true
            )

            popupWindow.dispatchEvent(new Event('loadstop'))

            setTimeout((->
              assert.deepEqual($rootScope.user, expectedUser)
              done()
            ), 0)


      suite 'executeScript error', (done) ->
        errorResponse =
          message: 'authFailure'
          errors: ['420']

        setup ->
          sinon.spy($auth, 'cancel')
          response = angular.extend({message: 'deliverCredentials'}, errorResponse)

        test 'error response cancels authentication, rejects promise', (done) ->
          caught = false

          dfd.catch(->
            caught = true
          )

          popupWindow.dispatchEvent(new Event('loadstop'))

          setTimeout((->
            assert true, caught
            assert $auth.cancel.called
            assert $rootScope.$broadcast.calledWith('auth:login-error')
            done()
          ), 0)

      suite 'inAppBrowser window closed before message is sent', ->
        setup ->
          sinon.spy($auth, 'cancel')

        teardown ->
          popupWindow.closed = false

        test 'auth is cancelled, promise is rejected', (done) ->
          caught = false

          dfd.catch =>
            caught = true

          $auth.handleAuthWindowClose()

          assert $auth.cancel.called
          assert.equal(null, $auth.requestCredentialsPollingTimer)
          done()
