angular.module('ng-token-auth', ['ngCookies'])
  .provider '$auth', ->
    config =
      apiUrl:                 '/api'
      signOutUrl:             '/auth/sign_out'
      emailSignInPath:        '/auth/sign_in'
      emailRegistrationPath:  '/auth'
      confirmationSuccessUrl: window.location.href
      tokenValidationPath:    '/auth/validate_token'
      useIEProxy:             false
      authProviders:
        github:
          path: '/auth/github'
        facebook:
          path: '/auth/facebook'
        google:
          path: '/auth/google'


    return {
      configure: (params) ->
        angular.extend(config, params)


      $get: [
        '$http'
        '$q'
        '$location'
        '$cookies'
        '$cookieStore'
        '$window'
        '$timeout'
        '$rootScope'
        ($http, $q, $location, $cookies, $cookieStore, $window, $timeout, $rootScope) =>
          token: null
          uid:   null
          dfd:   null
          user:  {}


          # register by email. server will send confirmation email
          # containing a link to activate the account. the link will
          # redirect to this site.
          submitRegistration: (params) ->
            console.log 'submitting registration', params
            angular.extend(params, {
              confirm_success_url: config.confirmationSuccessUrl
            })
            $http.post(config.apiUrl + config.emailRegistrationPath, params)


          # capture input from user, authenticate serverside
          submitLogin: (params) ->
            console.log 'params', params
            @dfd = $q.defer()
            $http.post(config.apiUrl + config.emailSignInPath, params)
              .success((resp) =>
                console.log 'this', @
                console.log 'resp', resp.data
                @handleValidAuth(resp.data)
              )
              .error((resp) =>
                @rejectDfd({
                  reason: 'unauthorized'
                  errors: ['Invalid credentials']
                })
              )
            @dfd.promise


          # open external auth provider in separate window, send requests for
          # credentials until api auth callback page responds.
          authenticate: (provider) ->
            unless @dfd?
              @dfd = $q.defer()
              authWindow = @openAuthWindow(provider)
              @requestCredentials(authWindow)

            @dfd


          # open external window to authentication provider
          openAuthWindow: (provider) ->
            $window.open(config.apiUrl+config.authProviders[provider].path)


          requestCredentials: (authWindow) ->
            # user has closed the external provider's auth window without
            # completing login.
            if authWindow.closed
              @rejectDfd({
                reason: 'unauthorized'
                errors: ['User canceled login']
              })

            # ping auth window to see if user has completed registration
            else
              authWindow.postMessage("requestCredentials", "*")
              @t = $timeout((=>@requestCredentials(authWindow)), 500)


          # failed login. invalidate auth token and reject promise.
          # defered object must be destroyed after reflow.
          rejectDfd: (reason) ->
            @invalidateTokens()
            if @dfd?
              @dfd.reject(reason)
              $timeout((=> @dfd = null))


          # this needs to happen after a reflow so that the promise
          # can be rejected properly before it is destroyed.
          resolveDfd: ->
            @dfd.resolve({id: @user.id})
            $timeout((=> 
              @dfd = null
              $rootScope.$digest()
              console.log 'user', @user
            ), 0)

          # this is something that can be returned from 'resolve' methods
          # of pages that have restricted access
          validateUser: ->
            unless @dfd?
              @dfd = $q.defer()

              unless @token and @uid and @user.id
                # token querystring is present. user most likely just came from
                # registration email link.
                if $location.search().token != undefined
                  @token = $location.search().token
                  @uid   = $location.search().uid

                # token cookie is present. user is returning to the site, or
                # has refreshed the page.
                else if $cookieStore.get('auth_token')
                  @token = $cookieStore.get('auth_token')
                  @uid   = $cookieStore.get('auth_uid')

                if @token and @uid
                  @validateToken()

                # new user session. will redirect to login
                else
                  @rejectDfd({
                    reason: 'unauthorized'
                    errors: ['No credentials']
                  })

              else
                # user is already logged in
                @resolveDfd()

            @dfd.promise


          # confirm that user's auth token is still valid.
          validateToken: () ->
            $http.post(config.apiUrl + config.tokenValidationPath, {
              auth_token: @token,
              uid:        @uid
            })
              .success((resp) =>
                console.log 'validate token resp', resp
                @handleValidAuth(resp.data)
              )
              .error((data) =>
                @dfd.reject({
                  reason: 'unauthorized'
                  errors: ['Invalid/expired credentials']
                })

                # wait for reflow, nullify dfd
                $timeout((=> @dfd = null), 0)
              )


          # this service attempts to cache auth tokens, but sometimes we
          # will want to discard saved tokens. examples include:
          # 1. login failure
          # 2. token validation failure
          # 3. user logs out
          invalidateTokens: ->
            # cannot delete user object for scoping reasons. instead, delete
            # all keys on object.
            delete @user[key] for key, val of @user

            # setting these values to null will force the validateToken method
            # to re-validate credentials with api server when validate is called
            @token = null
            @uid   = null

            # kill cookies, otherwise session will resume on page reload
            delete $cookies['auth_token']
            delete $cookies['auth_uid']


          # store tokens as cookies for returning users / page refresh
          persistTokens: (u)->
            @token = u.auth_token
            @uid   = u.uid

            $cookieStore.put('auth_token', @token)
            $cookieStore.put('auth_uid', @uid)

            # add api token headers to all subsequent requests
            $http.defaults.headers.common['Authorization'] = @buildAuthHeader()


          # generate auth header from auth token + user uid
          buildAuthHeader: ->
            "token=#{@token} uid=#{@uid}"


          # destroy auth token on server, destroy user auth credentials
          signOut: ->
            $http.delete(config.apiUrl + config.signOutUrl)
              .success((resp) => @invalidateTokens())
              .error((resp) => @invalidateTokens())


          handleValidAuth: (user) ->
            $timeout.cancel(@t) if @t?
            angular.extend @user, user
            @token = @user.auth_token
            @uid   = @user.uid
            @persistTokens(@user)
            @resolveDfd()


          # user closed external auth dialog. cancel authentication
          cancelAuth: ->
            $timeout.cancel(@t)
            @rejectDfd()


          # use proxy for IE
          apiUrl: ->
            unless @_apiUrl?
              if config.useIEProxy and navigator.sayswho.match(/IE/)
                @_apiUrl = '/proxy'
              else
                @_apiUrl = config.apiUrl

            @_apiUrl
      ]
    }

  .run ($auth, $window, $rootScope) ->
    # add listeners for communication with external auth window
    $window.addEventListener("message", (ev) =>
      if ev.data.message == 'deliverCredentials'
        ev.source.close()
        delete ev.data.message
        $auth.handleValidAuth(ev.data)

      if ev.data.message == 'authFailure'
        ev.source.close()
        $auth.cancelAuth()
    )

    # bind global user object to auth user
    $rootScope.user = $auth.user

    # template access to authentication methods
    $rootScope.githubLogin   = -> $auth.authenticate('github')
    $rootScope.facebookLogin = -> $auth.authenticate('facebook')
    $rootScope.googleLogin   = -> $auth.authenticate('google')

    # template access to view actions
    $rootScope.signOut            = -> $auth.signOut()
    $rootScope.submitRegistration = (params) -> $auth.submitRegistration(params)
    $rootScope.submitLogin        = (params) -> $auth.submitLogin(params)

    # check to see if user is returning user
    $auth.validateUser()
