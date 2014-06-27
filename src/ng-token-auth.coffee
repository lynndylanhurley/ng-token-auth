angular.module('ng-token-auth', ['ngCookies'])
  .provider '$auth', ->
    config =
      apiUrl:              '/api'
      signOutUrl:          '/auth/sign_out'
      emailSignInUrl:      '/auth/sign_in'
      tokenValidationPath: '/auth/validate_token'
      useIEProxy:          false
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
          email: null
          dfd:   null
          user: {}


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


          # this needs to happen after a reflow so that the promise
          # can be rejected properly before it is destroyed.
          rejectDfd: (reason) ->
            if @dfd?
              @dfd.reject(reason)
              $timeout((=> @dfd = null))


          # this needs to happen after a reflow so that the promise
          # can be rejected properly before it is destroyed.
          resolveDfd: ->
            @dfd.resolve({id: @user.id})
            $timeout((=> @dfd = null), 0)

          # this is something that can be returned from 'resolve' methods
          # of pages that have restricted access
          validateUser: ->
            unless @dfd?
              @dfd = $q.defer()

              unless @token and @email and @user.id
                # token querystring is present. user most likely just came from
                # registration email link.
                if $location.search().token != undefined
                  @token = $location.search().token
                  @email = $location.search().email

                # token cookie is present. user is returning to the site, or
                # has refreshed the page.
                else if $cookieStore.get('auth_token')
                  @token = $cookieStore.get('auth_token')
                  @email = $cookieStore.get('auth_email')

                if @token and @email
                  @validateToken()

                # new user session. will redirect to login
                else
                  @rejectDfd({
                    reason: 'unauthorized'
                    errors: ['No credentials']
                  })

              else
                # user is logged in
                @resolveDfd()

            @dfd.promise


          # confirm that user's auth token is still valid.
          validateToken: () ->
            $http.post(config.apiUrl + config.tokenValidationPath, {
              auth_token: @token,
              email: @email
            })
              .success((resp) =>
                console.log 'validate token resp', resp
                @handleValidAuth(resp.data)
              )
              .error((data) =>
                @invalidateTokens()
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
            @email = null

            # kill cookies, otherwise session will resume on page reload
            delete $cookies['auth_token']
            delete $cookies['auth_email']


          # store tokens as cookies for returning users / page refresh
          persistTokens: (u)->
            @token = u.auth_token
            @email = u.email

            $cookieStore.put('auth_token', @token)
            $cookieStore.put('auth_email', @email)

            # add api token headers to all subsequent requests
            $http.defaults.headers.common['Authorization'] = @buildAuthHeader()


          # generate auth header from auth token + user email
          buildAuthHeader: ->
            "token=#{@token} email=#{@email}"


          # destroy auth token on server, destroy user auth credentials
          signOut: ->
            $http.post(config.apiUrl + config.signOutUrl, {
              email: @email
              token: @auth_token
            })
              .success((resp) => @invalidateTokens())
              .error((resp) => @invalidateTokens())


          handleValidAuth: (user) ->
            _.extend @user, user
            @persistTokens(@user)
            @resolveDfd()


          # user closed external auth dialog. cancel authentication
          cancelAuth: ->
            $timeout.cancel(@t)
            @invalidateTokens()
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

  .run ($auth, $timeout, $window, $rootScope) ->
    # add listeners for external auth window communication
    $window.addEventListener("message", (ev) =>
      console.log 'received message', ev

      if ev.data.message == 'deliverCredentials'
        ev.source.close()
        $auth.handleValidAuth(_.omit(ev.data, 'message'))
        $rootScope.$digest()

      if ev.data.message == 'authFailure'
        ev.source.close()
        $auth.cancelAuth()
    )

    # bind global user object to auth user
    $rootScope.user = $auth.user

    # shortcuts to supported providers
    $rootScope.githubLogin = ->
      $auth.authenticate('github')

    $rootScope.facebookLogin = ->
      $auth.authenticate('facebook')

    $rootScope.googleLogin = ->
      $auth.authenticate('google')

    # shortcut to log out method
    $rootScope.signOut = ->
      $auth.signOut()

    # check to see if user is returning user
    $auth.validateUser()
