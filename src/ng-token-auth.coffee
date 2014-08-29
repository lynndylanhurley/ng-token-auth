angular.module('ng-token-auth', ['ngCookies'])
  .provider('$auth', ->
    config =
      apiUrl:                  '/api'
      signOutUrl:              '/auth/sign_out'
      emailSignInPath:         '/auth/sign_in'
      emailRegistrationPath:   '/auth'
      accountUpdatePath:       '/auth'
      accountDeletePath:       '/auth'
      confirmationSuccessUrl:  window.location.href
      passwordResetPath:       '/auth/password'
      passwordUpdatePath:      '/auth/password'
      passwordResetSuccessUrl: window.location.href
      tokenValidationPath:     '/auth/validate_token'
      proxyIf:                 -> false
      proxyUrl:                '/proxy'
      validateOnPageLoad:      true
      forceHardRedirect:       false
      storage:                 'cookies'

      tokenFormat:
        "access-token": "{{ token }}"
        "token-type":   "Bearer"
        client:       "{{ clientId }}"
        expiry:       "{{ expiry }}"
        uid:          "{{ uid }}"

      parseExpiry: (headers) ->
        # convert from ruby time (seconds) to js time (millis)
        (parseInt(headers['expiry'], 10) * 1000) || null

      handleLoginResponse: (resp) -> resp.data
      handleAccountUpdateResponse: (resp) -> resp.data
      handleTokenValidationResponse: (resp) -> resp.data

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
        '$cookieStore'
        '$window'
        '$timeout'
        '$rootScope'
        '$interpolate'
        ($http, $q, $location, $cookieStore, $window, $timeout, $rootScope, $interpolate) =>
          header:            null
          dfd:               null
          config:            config
          user:              {}
          mustResetPassword: false
          listener:          null


          initialize: ->
            @initializeListeners()
            @addScopeMethods()


          initializeListeners: ->
            @listener = @handlePostMessage.bind(@)
            if $window.addEventListener
              $window.addEventListener("message", @listener, false)


          cancel: (reason) ->
            if @t?
              $timeout.cancel(@t)

            if @dfd?
              @rejectDfd(reason)

            return $timeout((=> @t = null), 0)


          destroy: ->
            @cancel()

            if $window.removeEventListener
              $window.removeEventListener("message", @listener, false)


          handlePostMessage: (ev) ->
            if ev.data.message == 'deliverCredentials'
              delete ev.data.message
              @handleValidAuth(ev.data, true)
              $rootScope.$broadcast('auth:login-success', ev.data)

            if ev.data.message == 'authFailure'
              error = {
                reason: 'unauthorized'
                errors: [ev.data.error]
              }
              @cancel(error)
              $rootScope.$broadcast('auth:login-error', error)


          addScopeMethods: ->
            # bind global user object to auth user
            $rootScope.user = @user

            # template access to authentication method
            $rootScope.authenticate  = (provider) => @authenticate(provider)

            # template access to view actions
            $rootScope.signOut              = => @signOut()
            $rootScope.destroyAccount       = => @destroyAccount()
            $rootScope.submitRegistration   = (params) => @submitRegistration(params)
            $rootScope.submitLogin          = (params) => @submitLogin(params)
            $rootScope.requestPasswordReset = (params) => @requestPasswordReset(params)
            $rootScope.updatePassword       = (params) => @updatePassword(params)
            $rootScope.updateAccount        = (params) => @updateAccount(params)

            # check to see if user is returning user
            if config.validateOnPageLoad
              @validateUser()


          # register by email. server will send confirmation email
          # containing a link to activate the account. the link will
          # redirect to this site.
          submitRegistration: (params) ->
            regDfd = $q.defer()

            angular.extend(params, {
              confirm_success_url: config.confirmationSuccessUrl
            })
            $http.post(@apiUrl() + config.emailRegistrationPath, params)
              .success((resp)->
                $rootScope.$broadcast('auth:registration-email-success', params)
                regDfd.resolve(resp)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:registration-email-error', resp)
                regDfd.reject(resp)
              )

            regDfd.promise


          # capture input from user, authenticate serverside
          submitLogin: (params) ->
            @initDfd()
            $http.post(@apiUrl() + config.emailSignInPath, params)
              .success((resp) =>
                authData = config.handleLoginResponse(resp)
                @handleValidAuth(authData)
                $rootScope.$broadcast('auth:login-success', @user)
              )
              .error((resp) =>
                @rejectDfd({
                  reason: 'unauthorized'
                  errors: ['Invalid credentials']
                })
                $rootScope.$broadcast('auth:login-error', resp)
              )
            @dfd.promise


          # check if user is authenticated
          userIsAuthenticated: ->
            @headers and @user.signedIn


          # request password reset from API
          requestPasswordReset: (params) ->
            params.redirect_url = config.passwordResetSuccessUrl
            pwdDfd = $q.defer()

            $http.post(@apiUrl() + config.passwordResetPath, params)
              .success((resp) ->
                $rootScope.$broadcast('auth:password-reset-request-success', params)
                pwdDfd.resolve(resp)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:password-reset-request-error', resp)
                pwdDfd.reject(resp)
              )

            pwdDfd.promise


          # update user password
          updatePassword: (params) ->
            pwdDfd = $q.defer()

            $http.put(@apiUrl() + config.passwordUpdatePath, params)
              .success((resp) =>
                $rootScope.$broadcast('auth:password-change-success', resp)
                @mustResetPassword = false
                pwdDfd.resolve(resp)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:password-change-error', resp)
                pwdDfd.reject(resp)
              )

            pwdDfd.promise

          # update user account info
          updateAccount: (params) ->
            acctDfd = $q.defer()

            $http.put(@apiUrl() + config.accountUpdatePath, params)
              .success((resp) =>
                angular.extend @user, config.handleAccountUpdateResponse(resp)
                $rootScope.$broadcast('auth:account-update-success', resp)
                acctDfd.resolve(resp)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:account-update-error', resp)
                acctDfd.reject(resp)
              )

            acctDfd.promise


          # permanently destroy a user's account.
          destroyAccount: (params) ->
            destroyDfd = $q.defer()

            $http.delete(@apiUrl() + config.accountUpdatePath, params)
              .success((resp) =>
                @invalidateTokens()
                $rootScope.$broadcast('auth:account-destroy-success', resp)
                destroyDfd.resolve(resp)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:account-destroy-error', resp)
                destroyDfd.reject(resp)
              )

            destroyDfd.promise

          # open external auth provider in separate window, send requests for
          # credentials until api auth callback page responds.
          authenticate: (provider) ->
            unless @dfd?
              @initDfd()
              @openAuthWindow(provider)

            @dfd.promise


          # open external window to authentication provider
          openAuthWindow: (provider) ->
            authUrl = @buildAuthUrl(provider)

            if @useExternalWindow()
              @requestCredentials($window.open(authUrl))
            else
              $location.replace(authUrl)


          buildAuthUrl: (provider) ->
            authUrl  = config.apiUrl
            authUrl += config.authProviderPaths[provider]
            authUrl += '?auth_origin_url='
            authUrl += $location.href


          # ping auth window to see if user has completed registration.
          # recursively call this method until:
          # 1. user completes authentication
          # 2. user fails authentication
          # 3. auth window is closed
          requestCredentials: (authWindow) ->
            # user has closed the external provider's auth window without
            # completing login.
            if authWindow.closed
              @cancel({
                reason: 'unauthorized'
                errors: ['User canceled login']
              })
              $rootScope.$broadcast('auth:window-closed')

            # still awaiting user input
            else
              authWindow.postMessage("requestCredentials", "*")
              @t = $timeout((=>@requestCredentials(authWindow)), 500)



          # this needs to happen after a reflow so that the promise
          # can be rejected properly before it is destroyed.
          resolveDfd: ->
            @dfd.resolve(@user)
            $timeout((=>
              @dfd = null
              $rootScope.$digest() unless $rootScope.$$phase
            ), 0)


          # this is something that can be returned from 'resolve' methods
          # of pages that have restricted access
          validateUser: ->
            unless @dfd?
              @initDfd()

              unless @userIsAuthenticated()
                # token querystring is present. user most likely just came from
                # registration email link.
                if $location.search().token != undefined
                  token    = $location.search().token
                  clientId = $location.search().client_id
                  uid      = $location.search().uid

                  # check if redirected from password reset link
                  @mustResetPassword = $location.search().reset_password

                  # check if redirected from email confirmation link
                  @firstTimeLogin = $location.search().account_confirmation_success

                  # persist these values
                  @setAuthHeaders(@buildAuthHeaders({
                    token:    token
                    clientId: clientId
                    uid:      uid
                  }))

                  # strip qs from url to prevent re-use of these params
                  # on page refresh
                  $location.url(($location.path() || '/'))

                # token cookie is present. user is returning to the site, or
                # has refreshed the page.
                else if @retrieveData('auth_headers')
                  @headers = @retrieveData('auth_headers')

                unless isEmpty(@headers)
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
            unless @tokenHasExpired()
              $http.get(@apiUrl() + config.tokenValidationPath)
                .success((resp) =>
                  authData = config.handleTokenValidationResponse(resp)
                  @handleValidAuth(authData)

                  # broadcast event for first time login
                  if @firstTimeLogin
                    $rootScope.$broadcast('auth:email-confirmation-success', @user)

                  if @mustResetPassword
                    $rootScope.$broadcast('auth:password-reset-confirm-success', @user)

                  $rootScope.$broadcast('auth:validation-success', @user)
                )
                .error((data) =>
                  # broadcast event for first time login failure
                  if @firstTimeLogin
                    $rootScope.$broadcast('auth:email-confirmation-error', data)

                  if @mustResetPassword
                    $rootScope.$broadcast('auth:password-reset-confirm-error', data)

                  $rootScope.$broadcast('auth:validation-error', data)

                  @rejectDfd({
                    reason: 'unauthorized'
                    errors: data.errors
                  })
                )
            else
              @rejectDfd({
                reason: 'unauthorized'
                errors: ['Expired credentials']
              })


          # don't bother checking known expired headers
          tokenHasExpired: ->
            expiry = @getExpiry()

            now = new Date().getTime()

            if @headers and expiry
              return (expiry and expiry < now)
            else
              return null


          # get expiry by method provided in config
          getExpiry: ->
            config.parseExpiry(@headers)


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
            @headers = null

            # kill cookies, otherwise session will resume on page reload
            @deleteData('auth_headers')


          # destroy auth token on server, destroy user auth credentials
          signOut: ->
            signOutDfd = $q.defer()

            $http.delete(@apiUrl() + config.signOutUrl)
              .success((resp) =>
                @invalidateTokens()
                $rootScope.$broadcast('auth:logout-success')
                signOutDfd.resolve(resp)
              )
              .error((resp) =>
                @invalidateTokens()
                $rootScope.$broadcast('auth:logout-error', resp)
                signOutDfd.reject(resp)
              )

            signOutDfd.promise


          # handle successful authentication
          handleValidAuth: (user, setHeader=false) ->
            # cancel any pending postMessage checks
            $timeout.cancel(@t) if @t?

            # must extend existing object for scoping reasons
            angular.extend @user, user

            # add shortcut to determine user auth status
            @user.signedIn = true

            # postMessage will not contain header. must save headers manually.
            if setHeader
              @setAuthHeaders(@buildAuthHeaders({
                token:    @user.auth_token
                clientId: @user.client_id
                uid:      @user.uid
              }))

            # fulfill promise
            @resolveDfd()


          # auth token format. consider making this configurable
          buildAuthHeaders: (ctx) ->
            headers = {}

            for key, val of config.tokenFormat
              headers[key] = $interpolate(val)(ctx)

            return headers


          # abstract persistent data store
          persistData: (key, val) ->
            switch config.storage
              when 'localStorage'
                $window.localStorage.setItem(key, JSON.stringify(val))
              else $cookieStore.put(key, val)


          # abstract persistent data retrieval
          retrieveData: (key) ->
            switch config.storage
              when 'localStorage'
                JSON.parse($window.localStorage.getItem(key))
              else $cookieStore.get(key)


          # abstract persistent data removal
          deleteData: (key) ->
            switch config.storage
              when 'localStorage'
                $window.localStorage.removeItem(key)
              else $cookieStore.remove(key)


          # persist authentication token, client id, uid
          setAuthHeaders: (headers) ->
            @headers = angular.extend((@headers || {}), headers)
            @persistData('auth_headers', @headers)



          # ie8 + ie9 cannot use xdomain postMessage
          useExternalWindow: ->
            not (config.forceHardRedirect || $window.isOldIE())


          initDfd: ->
            @dfd = $q.defer()


          # failed login. invalidate auth header and reject promise.
          # defered object must be destroyed after reflow.
          rejectDfd: (reason) ->
            @invalidateTokens()
            if @dfd?
              @dfd.reject(reason)

              # must nullify after reflow so promises can be rejected
              $timeout((=> @dfd = null), 0)


          # use proxy for IE
          apiUrl: ->
            if config.proxyIf()
              config.proxyUrl
            else
              config.apiUrl
      ]
    }
  )


  # each response will contain auth headers that have been updated by
  # the server. copy those headers for use in the next request.
  .config(['$httpProvider', ($httpProvider) ->
    # this is ugly...
    # we need to configure an interceptor (must be done in the configuration
    # phase), but we need access to the $http service, which is only available
    # during the run phase. the following technique was taken from this
    # stackoverflow post:
    # http://stackoverflow.com/questions/14681654/i-need-two-instances-of-angularjs-http-service-or-what
    $httpProvider.interceptors.push ['$injector', ($injector) ->
      request: (req) ->
        $injector.invoke ['$http', '$auth',  ($http, $auth) ->
          if req.url.match($auth.config.apiUrl)
            for key, val of $auth.headers
              req.headers[key] = val
        ]

        return req

      response: (resp) ->
        $injector.invoke ['$http', '$auth', ($http, $auth) ->
          newHeaders = {}

          for key, val of $auth.config.tokenFormat
            if resp.headers(key)
              newHeaders[key] = resp.headers(key)


          $auth.setAuthHeaders(newHeaders)
        ]

        return resp
    ]

    # define http methods that may need to carry auth headers
    httpMethods = ['get', 'post', 'put', 'patch', 'delete']

    # disable IE ajax request caching for each of the necessary http methods
    angular.forEach(httpMethods, (method) ->
      $httpProvider.defaults.headers[method] ?= method
      $httpProvider.defaults.headers[method]['If-Modified-Since'] = '0'
    )
  ])

  .run(['$auth', '$window', '$rootScope', ($auth, $window, $rootScope) ->
    $auth.initialize()
  ])

# ie8 and ie9 require special handling
window.isOldIE = ->
  out = false
  nav = navigator.userAgent.toLowerCase()
  if nav and nav.indexOf('msie') != -1
    version = parseInt(nav.split('msie')[1])
    if version < 10
      out = true

  out


window.isEmpty = (obj) ->
  # null and undefined are "empty"
  return true unless obj

  # Assume if it has a length property with a non-zero value
  # that that property is correct.
  return false if (obj.length > 0)
  return true if (obj.length == 0)

  # Otherwise, does it have any properties of its own?
  # Note that this doesn't handle
  # toString and valueOf enumeration bugs in IE < 9
  for key, val of obj
    return false if (Object.prototype.hasOwnProperty.call(obj, key))

  return true
