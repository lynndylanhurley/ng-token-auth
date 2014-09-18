angular.module('ng-token-auth', ['ngCookies'])
  .provider('$auth', ->
    configs =
      default:
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


    defaultConfigName = "default"


    return {
      configure: (params) ->
        # user is using multiple concurrent configs (>1 user types).
        if params instanceof Array and params.length
          # extend each item in array from default settings
          for conf, i in params
            # get the name of the config
            label = null
            for k, v of conf
              label = k

              # set the first item in array as default config
              defaultConfigName = label if i == 0

            # use copy preserve the original default settings object while
            # extending each config object
            defaults = angular.copy(configs["default"])
            fullConfig = {}
            fullConfig[label] = angular.extend(defaults, conf[label])
            angular.extend(configs, fullConfig)

          # remove existng default config
          delete configs["default"]

        # user is extending the single default config
        else if params instanceof Object
          angular.extend(configs["default"], params)

        # user is doing something wrong
        else
          throw "Invalid argument: ng-token-auth config should be an Array or Object."

        return configs


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
          user:              {}
          mustResetPassword: false
          currentConfigName: null
          listener:          null


          # called once at startup
          initialize: ->
            @setCurrentConfig()
            @initializeListeners()
            @addScopeMethods()


          # check if named configuration was set in a previous session
          # fall back to "default" if named config is not found
          setCurrentConfig: ->
            if typeof $window.localStorage != 'undefined'
              @currentConfigName ?= $window.localStorage.getItem("currentConfigName")
            @currentConfigName ?=  $cookieStore.get("currentConfigName") || null


          initializeListeners: ->
            @listener = @handlePostMessage.bind(@)
            if $window.addEventListener
              $window.addEventListener("message", @listener, false)


          cancel: (reason) ->
            # cancel any pending timers
            if @t?
              $timeout.cancel(@t)

            # reject any pending promises
            if @dfd?
              @rejectDfd(reason)

            # nullify timer after reflow
            return $timeout((=> @t = null), 0)


          # cancel any pending processes, clean up garbage
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
            $rootScope.authenticate  = @authenticate.bind(@)

            # template access to view actions
            $rootScope.signOut              = @signOut.bind(@)
            $rootScope.destroyAccount       = @destroyAccount.bind(@)
            $rootScope.submitRegistration   = @submitRegistration.bind(@)
            $rootScope.submitLogin          = @submitLogin.bind(@)
            $rootScope.requestPasswordReset = @requestPasswordReset.bind(@)
            $rootScope.updatePassword       = @updatePassword.bind(@)
            $rootScope.updateAccount        = @updateAccount.bind(@)

            # check to see if user is returning user
            if @getConfig().validateOnPageLoad
              @validateUser({config: @retrieveData('currentConfigName')})


          # register by email. server will send confirmation email
          # containing a link to activate the account. the link will
          # redirect to this site.
          submitRegistration: (params, opts={}) ->
            angular.extend(params, {
              confirm_success_url: @getConfig(opts.config).confirmationSuccessUrl,
              config_name: @getCurrentConfigName()
            })
            $http.post(@apiUrl(opts.config) + @getConfig(opts.config).emailRegistrationPath, params)
              .success((resp)->
                $rootScope.$broadcast('auth:registration-email-success', params)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:registration-email-error', resp)
              )


          # capture input from user, authenticate serverside
          submitLogin: (params, opts={}) ->
            @initDfd()
            $http.post(@apiUrl(opts.config) + @getConfig(opts.config).emailSignInPath, params)
              .success((resp) =>
                @setConfigName(opts)
                authData = @getConfig(opts.config).handleLoginResponse(resp)
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
          requestPasswordReset: (params, opts={}) ->
            params.redirect_url = @getConfig(opts.config).passwordResetSuccessUrl
            params.config_name  = opts.config if opts.config?

            $http.post(@apiUrl(opts.config) + @getConfig(opts.config).passwordResetPath, params)
              .success((resp) ->
                $rootScope.$broadcast('auth:password-reset-request-success', params)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:password-reset-request-error', resp)
              )


          # update user password
          updatePassword: (params) ->
            $http.put(@apiUrl() + @getConfig().passwordUpdatePath, params)
              .success((resp) =>
                $rootScope.$broadcast('auth:password-change-success', resp)
                @mustResetPassword = false
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:password-change-error', resp)
              )


          # update user account info
          updateAccount: (params) ->
            $http.put(@apiUrl() + @getConfig().accountUpdatePath, params)
              .success((resp) =>
                angular.extend @user, @getConfig().handleAccountUpdateResponse(resp)
                $rootScope.$broadcast('auth:account-update-success', resp)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:account-update-error', resp)
              )


          # permanently destroy a user's account.
          destroyAccount: (params) ->
            $http.delete(@apiUrl() + @getConfig().accountUpdatePath, params)
              .success((resp) =>
                @invalidateTokens()
                $rootScope.$broadcast('auth:account-destroy-success', resp)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:account-destroy-error', resp)
              )


          # open external auth provider in separate window, send requests for
          # credentials until api auth callback page responds.
          authenticate: (provider, opts) ->
            unless @dfd?
              @setConfigName(opts)
              @initDfd()
              @openAuthWindow(provider, opts)

            @dfd.promise


          setConfigName: (opts={}) ->
            @currentConfigName = opts.config if opts.config?
            @persistData('currentConfigName', @currentConfigName) if @currentConfigName?


          # open external window to authentication provider
          openAuthWindow: (provider, opts) ->
            authUrl = @buildAuthUrl(provider, opts)

            if @useExternalWindow()
              @requestCredentials(@createPopup(authUrl))
            else
              @visitUrl(authUrl)


          # testing actual redirects is difficult. stub this for testing
          visitUrl: (url) ->
            $window.location.replace(url)


          buildAuthUrl: (provider, opts={}) ->
            authUrl  = @getConfig(opts.config).apiUrl
            authUrl += @getConfig(opts.config).authProviderPaths[provider]
            authUrl += '?auth_origin_url=' + encodeURIComponent($window.location.href)

            if opts.params?
              for key, val of opts.params
                authUrl += '&'
                authUrl += encodeURIComponent(key)
                authUrl += '='
                authUrl += encodeURIComponent(val)

            return authUrl

          # ping auth window to see if user has completed registration.
          # this method is recursively called until:
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


          # popups are difficult to test. mock this method in testing.
          createPopup: (url) ->
            $window.open(url)


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
            configName = null

            unless @dfd?
              @initDfd()

              unless @userIsAuthenticated()
                # token querystring is present. user most likely just came from
                # registration email link.
                if $location.search().token != undefined
                  token      = $location.search().token
                  clientId   = $location.search().client_id
                  uid        = $location.search().uid
                  configName = $location.search().config

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
                  @headers   = @retrieveData('auth_headers')
                  configName = @retrieveData('currentConfigName')

                unless isEmpty(@headers)
                  @validateToken({config: configName})

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
          validateToken: (opts={}) ->
            unless @tokenHasExpired()
              $http.get(@apiUrl(opts.config) + @getConfig(opts.config).tokenValidationPath)
                .success((resp) =>
                  authData = @getConfig(opts.config).handleTokenValidationResponse(resp)
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
            @getConfig().parseExpiry(@headers)


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

            # remove any assumptions about current configuration
            @deleteData('currentConfigName')
            @currentConfigName = null

            # kill cookies, otherwise session will resume on page reload
            @deleteData('auth_headers')


          # destroy auth token on server, destroy user auth credentials
          signOut: ->
            $http.delete(@apiUrl() + @getConfig().signOutUrl)
              .success((resp) =>
                @invalidateTokens()
                $rootScope.$broadcast('auth:logout-success')
              )
              .error((resp) =>
                @invalidateTokens()
                $rootScope.$broadcast('auth:logout-error', resp)
              )


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


          # configure auth token format.
          buildAuthHeaders: (ctx) ->
            headers = {}

            for key, val of @getConfig().tokenFormat
              headers[key] = $interpolate(val)(ctx)

            return headers


          # abstract persistent data store
          persistData: (key, val) ->
            switch @getConfig().storage
              when 'localStorage'
                $window.localStorage.setItem(key, JSON.stringify(val))
              else $cookieStore.put(key, val)


          # abstract persistent data retrieval
          retrieveData: (key) ->
            switch @getConfig().storage
              when 'localStorage'
                JSON.parse($window.localStorage.getItem(key))
              else $cookieStore.get(key)


          # abstract persistent data removal
          deleteData: (key) ->
            switch @getConfig().storage
              when 'localStorage'
                $window.localStorage.removeItem(key)
              else $cookieStore.remove(key)


          # persist authentication token, client id, uid
          setAuthHeaders: (headers) ->
            @headers = angular.extend((@headers || {}), headers)
            @persistData('auth_headers', @headers)


          # ie8 + ie9 cannot use xdomain postMessage
          useExternalWindow: ->
            not (@getConfig().forceHardRedirect || $window.isIE())


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
          apiUrl: (configName) ->
            if @getConfig(configName).proxyIf()
              @getConfig(configName).proxyUrl
            else
              @getConfig(configName).apiUrl


          getConfig: (name) ->
            configs[@getCurrentConfigName(name)]


          # a config name will be return in the following order of precedence:
          # 1. matches arg
          # 2. matches @currentConfigName (saved from past authentication)
          # 3. matches defaultConfigName (first or only available config name)
          getCurrentConfigName: (name) ->
            name || @currentConfigName || defaultConfigName

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
          if req.url.match($auth.apiUrl())
            for key, val of $auth.headers
              req.headers[key] = val
        ]

        return req

      response: (resp) ->
        $injector.invoke ['$http', '$auth', ($http, $auth) ->
          if resp.config.url.match($auth.apiUrl())
            newHeaders = {}

            for key, val of $auth.getConfig().tokenFormat
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
      $httpProvider.defaults.headers[method] ?= {}
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

# ie <= 11 do not support postMessage
window.isIE = ->
  nav = navigator.userAgent.toLowerCase()
  ((nav and nav.indexOf('msie') != -1) || !!navigator.userAgent.match(/Trident.*rv\:11\./))

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
