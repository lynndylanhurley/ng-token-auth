suite 'custom response interceptors', ->
  suite 'login', ->
    suite 'single config', ->
      apiUrl = '/stevia'
      dfd    = null

      user =
        uid: "support@ewide.biz"

      response = {
        "access_token": "R6cwCGmt7GDOwgt91DlYDcaic5-bFrS8bBJG-QdtM3VFiPA",
        "token_type":   "bearer",
        "expires_in":   86399,
        "userName":     "support@ewide.biz",
        ".issued":      "Fri, 31 Oct 2014 22:15:44 GMT",
        ".expires":     "Sat, 01 Nov 2014 22:15:44 GMT"
      }

      setup ->
        $authProvider.configure({
          apiUrl: apiUrl
          validateOnPageLoad: true
          proxyIf: -> false
          parseExpiry: (headers) ->
            headers['expiry']

          tokenFormat: ->
            'Authorization': 'Bearer {{ token }}'

          handleLoginResponse: (resp, $auth) ->
            $auth.persistData('auth_headers', {
              'Authorization': 'Bearer '+resp['access_token']
              'expiry': new Date().getTime() + resp['expires_in']
            })

            return {
              'uid': resp['userName']
            }
        })

        $httpBackend
          .expectPOST(apiUrl+'/auth/sign_in')
          .respond(201, response)

        dfd = $auth.submitLogin({
          email: user.uid
          password: 'secret123'
        })

        $httpBackend.flush()

      # restore defaults
      teardown ->
        $authProvider.configure({
          apiUrl: '/api'
          proxyIf: -> false
        })

      test 'new user is defined in the root scope', ->
        assert.equal(user.uid, $rootScope.user.uid)

      test 'success event should return user info', ->
        assert $rootScope.$broadcast.calledWithMatch('auth:login-success', user)

      test 'headers were saved for next request', ->
        testRan = false

        $httpBackend
          .expectGET(apiUrl+'/test', (headers) ->
            assert.equal 'Bearer '+response['access_token'], headers['Authorization']
            testRan = true
            return headers
          )
          .respond(201, {})

        $http.get(apiUrl+'/test')
        $httpBackend.flush()
        assert testRan


      test 'promise is resolved', ->
        resolved = false
        dfd.then(-> resolved = true)
        $timeout.flush()
        assert(resolved)
