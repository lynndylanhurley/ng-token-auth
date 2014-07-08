angular.module('ng-token-auth', ['ngCookies'])
  .provider '$auth', ->
    config =
      apiUrl:                 '/api'
      signOutUrl:             '/auth/sign_out'
      emailSignInPath:        '/auth/sign_in'
      emailRegistrationPath:  '/auth'
      confirmationSuccessUrl: window.location.href
      tokenValidationPath:    '/auth/validate_token'
      proxyIf:                -> false
      proxyUrl:               '/proxy'
      authProviderPaths:
        github:    '/auth/github'
        facebook:  '/auth/facebook'
        google:    '/auth/google_oauth2'


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
          header:   null
          dfd:      null
          config:   config
          user:     {}


          # register by email. server will send confirmation email
          # containing a link to activate the account. the link will
          # redirect to this site.
          submitRegistration: (params) ->
            angular.extend(params, {
              confirm_success_url: config.confirmationSuccessUrl
            })
            $http.post(@apiUrl() + config.emailRegistrationPath, params)
              .success(->
                $rootScope.$broadcast('auth:registration-email-sent', params)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:registration-email-failed', resp)
              )


          # capture input from user, authenticate serverside
          submitLogin: (params) ->
            @dfd = $q.defer()
            $http.post(@apiUrl() + config.emailSignInPath, params)
              .success((resp) =>
                @handleValidAuth(resp.data)
                $rootScope.$broadcast('auth:login', @user)
              )
              .error((resp) =>
                @rejectDfd({
                  reason: 'unauthorized'
                  errors: ['Invalid credentials']
                })
                $rootScope.$broadcast('auth:failure', resp)
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
            authUrl = config.apiUrl+
              config.authProviderPaths[provider]+
              '?auth_origin_url='+
              window.location.href

            if @useExternalWindow()
              $window.open(authUrl)
            else
              $window.location.href = $window.location.protocol+authUrl


          # ping auth window to see if user has completed registration.
          # recursively call this method until:
          # 1. user completes authentication
          # 2. user fails authentication
          # 3. auth window is closed
          requestCredentials: (authWindow) ->
            # user has closed the external provider's auth window without
            # completing login.
            if authWindow.closed
              @rejectDfd({
                reason: 'unauthorized'
                errors: ['User canceled login']
              })
              $rootScope.$broadcast('auth:window-closed')

            # still awaiting user input
            else
              authWindow.postMessage("requestCredentials", "*")
              @t = $timeout((=>@requestCredentials(authWindow)), 500)


          # failed login. invalidate auth header and reject promise.
          # defered object must be destroyed after reflow.
          rejectDfd: (reason) ->
            @invalidateTokens()
            if @dfd?
              @dfd.reject(reason)
              $timeout((=>
                @dfd = null
              ), 0)


          # this needs to happen after a reflow so that the promise
          # can be rejected properly before it is destroyed.
          resolveDfd: ->
            @dfd.resolve({id: @user.id})
            $timeout((=>
              @dfd = null
              $rootScope.$digest()
            ), 0)


          # this is something that can be returned from 'resolve' methods
          # of pages that have restricted access
          validateUser: ->
            unless @dfd?
              @dfd = $q.defer()

              unless @header and @user.id
                # token querystring is present. user most likely just came from
                # registration email link.
                if $location.search().token != undefined
                  token    = $location.search().token
                  clientId = $location.search().client_id
                  uid      = $location.search().uid

                  # persist these values
                  @setAuthHeader(@buildAuthToken(token, clientId, uid))

                  # strip qs from url to prevent re-use of these params
                  # on page refresh
                  $location.url($location.path() || '/')

                # token cookie is present. user is returning to the site, or
                # has refreshed the page.
                else if $cookieStore.get('auth_header')
                  @header = $cookieStore.get('auth_header')
                  $http.defaults.headers.common['Authorization'] = @header

                if @header
                  @validateToken()

                # new user session. will redirect to login
                else
                  @rejectDfd({
                    reason: 'unauthorized'
                    errors: ['No credentials']
                  })
                  $rootScope.$broadcast('auth:invalid')

              else
                # user is already logged in
                @resolveDfd()

            @dfd.promise


          # confirm that user's auth token is still valid.
          validateToken: () ->
            $http.get(@apiUrl() + config.tokenValidationPath)
              .success((resp) =>
                @handleValidAuth(resp.data)
                $rootScope.$broadcast('auth:validated', @user)
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

            # setting this value to null will force the validateToken method
            # to re-validate credentials with api server when validate is called
            @header = null

            # kill cookies, otherwise session will resume on page reload
            delete $cookies['auth_header']

            # kill default auth header
            $http.defaults.headers.common['Authorization'] = ''


          # destroy auth token on server, destroy user auth credentials
          signOut: ->
            $http.delete(@apiUrl() + config.signOutUrl)
              .success((resp) =>
                @invalidateTokens()
                $rootScope.$broadcast('auth:logout-success')
              )
              .error((resp) =>
                $rootScope.$broadcast('auth:logout-failure', resp)
              )


          # handle successful authentication
          handleValidAuth: (user, setHeader=false) ->
            # cancel any pending postMessage checks
            $timeout.cancel(@t) if @t?

            # must extend existing object for scoping reasons
            angular.extend @user, user

            # postMessage will not contain header. must save headers manually.
            if setHeader
              @setAuthHeader(@buildAuthToken(@user.auth_token, @user.client_id, @user.uid))

            # fulfill promise
            @resolveDfd()


          # user closed external auth dialog. cancel authentication
          cancelAuth: (reason) ->
            $timeout.cancel(@t)
            @rejectDfd(reason)
            $rootScope.$broadcast('auth:failure', reason)


          # auth token format. consider making this configurable
          buildAuthToken: (token, clientId, uid) ->
            "token=#{token} client=#{clientId} uid=#{uid}"


          # persist authentication token, client id, uid
          setAuthHeader: (header) ->
            @header = $http.defaults.headers.common['Authorization'] = header
            $cookieStore.put('auth_header', header)


          # ie8 + ie9 cannot use xdomain postMessage
          useExternalWindow: ->
            not $window.isOldIE()


          # use proxy for IE
          apiUrl: ->
            unless @_apiUrl?
              if config.proxyIf()
                @_apiUrl = '/proxy'
              else
                @_apiUrl = config.apiUrl

            @_apiUrl
      ]
    }


  # each response will contain auth headers that have been updated by
  # the server. copy those headers for use in the next request.
  .config ($httpProvider) ->
    # this is ugly...
    # we need to configure an interceptor (must be done in the configuration
    # phase), but we need access to the $http service, which is only available
    # during the run phase. the following technique was taken from this
    # stackoverflow post:
    # http://stackoverflow.com/questions/14681654/i-need-two-instances-of-angularjs-http-service-or-what
    $httpProvider.interceptors.push ($injector) ->
      response: (response) ->
        $injector.invoke ($http, $auth) ->
          if response.headers('Authorization')
            $auth.setAuthHeader(response.headers('Authorization'))
        return response


  .run ($auth, $window, $rootScope) ->
    # add listeners for communication with external auth window
    if $window.addEventListener
      $window.addEventListener("message", (ev) =>
        if ev.data.message == 'deliverCredentials'
          ev.source.close()
          delete ev.data.message
          $auth.handleValidAuth(ev.data, true)
          $rootScope.$broadcast('auth:login', ev.data)

        if ev.data.message == 'authFailure'
          ev.source.close()
          $auth.cancelAuth({
            reason: 'unauthorized'
            errors: [ev.data.error]
          })
      )

    # bind global user object to auth user
    $rootScope.user = $auth.user

    # template access to authentication method
    $rootScope.authenticate  = (provider) -> $auth.authenticate(provider)

    # template access to view actions
    $rootScope.signOut            = -> $auth.signOut()
    $rootScope.submitRegistration = (params) -> $auth.submitRegistration(params)
    $rootScope.submitLogin        = (params) -> $auth.submitLogin(params)

    # check to see if user is returning user
    $auth.validateUser()


# ie8 and ie9 require special handling
window.isOldIE = ->
  out = false
  nav = navigator.userAgent.toLowerCase()
  if nav and nav.indexOf('msie') != -1
    version = parseInt(nav.split('msie')[1])
    if version < 10
      out = true

  out
