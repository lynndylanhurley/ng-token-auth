if typeof module != 'undefined' and typeof exports != 'undefined' and module.exports == exports
  module.exports = 'ng-token-auth'

angular.module('ng-token-auth', ['ipCookie'])
  .provider('$auth', ->
    configs =
      default:
        apiUrl:                  '/api'
        signOutUrl:              '/auth/sign_out'
        emailSignInPath:         '/auth/sign_in'
        emailRegistrationPath:   '/auth'
        accountUpdatePath:       '/auth'
        accountDeletePath:       '/auth'
        confirmationSuccessUrl:  -> window.location.href
        passwordResetPath:       '/auth/password'
        passwordUpdatePath:      '/auth/password'
        passwordResetSuccessUrl: -> window.location.href
        tokenValidationPath:     '/auth/validate_token'
        proxyIf:                 -> false
        proxyUrl:                '/proxy'
        validateOnPageLoad:      true
        omniauthWindowType:      'sameWindow'
        storage:                 'cookies'
        forceValidateToken:      false

        tokenFormat:
          "access-token": "{{ token }}"
          "token-type":   "Bearer"
          client:         "{{ clientId }}"
          expiry:         "{{ expiry }}"
          uid:            "{{ uid }}"

        cookieOps:
          path: "/"
          expires: 9999
          expirationUnit: 'days'
          secure: false

        # popups are difficult to test. mock this method in testing.
        createPopup: (url) ->
          window.open(url, '_blank', 'closebuttoncaption=Cancel')

        parseExpiry: (headers) ->
          # convert from ruby time (seconds) to js time (millis)
          (parseInt(headers['expiry'], 10) * 1000) || null

        handleLoginResponse:           (resp) -> resp.data
        handleAccountUpdateResponse:   (resp) -> resp.data
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
          delete configs["default"] unless defaultConfigName == "default"

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
        'ipCookie'
        '$window'
        '$timeout'
        '$rootScope'
        '$interpolate'
        '$interval'
        ($http, $q, $location, ipCookie, $window, $timeout, $rootScope, $interpolate, $interval) =>
          header:            null
          dfd:               null
          user:              {}
          mustResetPassword: false
          listener:          null

          # called once at startup
          initialize: ->
            @initializeListeners()
            @cancelOmniauthInAppBrowserListeners = (->)
            @addScopeMethods()

          initializeListeners: ->
            #@listener = @handlePostMessage.bind(@)
            @listener = angular.bind(@, @handlePostMessage)

            if $window.addEventListener
              $window.addEventListener("message", @listener, false)


          cancel: (reason) ->
            # cancel any pending timers
            if @requestCredentialsPollingTimer?
              $timeout.cancel(@requestCredentialsPollingTimer)

            # cancel inAppBrowser listeners if set
            @cancelOmniauthInAppBrowserListeners()

            # reject any pending promises
            if @dfd?
              @rejectDfd(reason)

            # nullify timer after reflow
            return $timeout((=> @requestCredentialsPollingTimer = null), 0)


          # cancel any pending processes, clean up garbage
          destroy: ->
            @cancel()

            if $window.removeEventListener
              $window.removeEventListener("message", @listener, false)


          # handle the events broadcast from external auth tabs/popups
          handlePostMessage: (ev) ->
            if ev.data.message == 'deliverCredentials'
              delete ev.data.message

              # check if a new user was registered
              oauthRegistration = ev.data.oauth_registration
              delete ev.data.oauth_registration
              @handleValidAuth(ev.data, true)
              $rootScope.$broadcast('auth:login-success', ev.data)
              if oauthRegistration
                $rootScope.$broadcast('auth:oauth-registration', ev.data)
            if ev.data.message == 'authFailure'
              error = {
                reason: 'unauthorized'
                errors: [ev.data.error]
              }
              @cancel(error)
              $rootScope.$broadcast('auth:login-error', error)


          # make all public API methods available to directives
          addScopeMethods: ->
            # bind global user object to auth user
            $rootScope.user = @user

            # template access to authentication method
            $rootScope.authenticate  = angular.bind(@, @authenticate)

            # template access to view actions
            $rootScope.signOut              = angular.bind(@, @signOut)
            $rootScope.destroyAccount       = angular.bind(@, @destroyAccount)
            $rootScope.submitRegistration   = angular.bind(@, @submitRegistration)
            $rootScope.submitLogin          = angular.bind(@, @submitLogin)
            $rootScope.requestPasswordReset = angular.bind(@, @requestPasswordReset)
            $rootScope.updatePassword       = angular.bind(@, @updatePassword)
            $rootScope.updateAccount        = angular.bind(@, @updateAccount)

            # check to see if user is returning user
            if @getConfig().validateOnPageLoad
              @validateUser({config: @getSavedConfig()})


          # register by email. server will send confirmation email
          # containing a link to activate the account. the link will
          # redirect to this site.
          submitRegistration: (params, opts={}) ->
            successUrl = @getResultOrValue(@getConfig(opts.config).confirmationSuccessUrl)
            angular.extend(params, {
              confirm_success_url: successUrl,
              config_name: @getCurrentConfigName(opts.config)
            })
            $http.post(@apiUrl(opts.config) + @getConfig(opts.config).emailRegistrationPath, params)
              .success((resp)->
                $rootScope.$broadcast('auth:registration-email-success', params)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:registration-email-error', resp)
              )


          # capture input from user, authenticate serverside
          submitLogin: (params, opts={}, httpopts={}) ->
            @initDfd()
            $http.post(@apiUrl(opts.config) + @getConfig(opts.config).emailSignInPath, params, httpopts)
              .success((resp) =>
                @setConfigName(opts.config)
                authData = @getConfig(opts.config).handleLoginResponse(resp, @)
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
            @retrieveData('auth_headers') and @user.signedIn and not @tokenHasExpired()


          # request password reset from API
          requestPasswordReset: (params, opts={}) ->
            successUrl = @getResultOrValue(
              @getConfig(opts.config).passwordResetSuccessUrl
            )

            params.redirect_url = successUrl
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

                updateResponse = @getConfig().handleAccountUpdateResponse(resp)
                curHeaders = @retrieveData('auth_headers')

                angular.extend @user, updateResponse

                # ensure any critical headers (uid + ?) that are returned in
                # the update response are updated appropriately in storage
                if curHeaders
                  newHeaders = {}
                  for key, val of @getConfig().tokenFormat
                    if curHeaders[key] && updateResponse[key]
                      newHeaders[key] = updateResponse[key]
                  @setAuthHeaders(newHeaders)

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
          authenticate: (provider, opts={}) ->
            unless @dfd?
              @setConfigName(opts.config)
              @initDfd()
              @openAuthWindow(provider, opts)

            @dfd.promise


          setConfigName: (configName) ->
            configName ?= defaultConfigName
            @persistData('currentConfigName', configName, configName)


          # open external window to authentication provider
          openAuthWindow: (provider, opts) ->

            omniauthWindowType = @getConfig(opts.config).omniauthWindowType
            authUrl = @buildAuthUrl(omniauthWindowType, provider, opts)

            if omniauthWindowType is 'newWindow'
              @requestCredentialsViaPostMessage(@getConfig().createPopup(authUrl))
            else if omniauthWindowType is 'inAppBrowser'
              @requestCredentialsViaExecuteScript(@getConfig().createPopup(authUrl))
            else if omniauthWindowType is 'sameWindow'
              @visitUrl(authUrl)
            else
              throw 'Unsupported omniauthWindowType "#{omniauthWindowType}"'


          # testing actual redirects is difficult. stub this for testing
          visitUrl: (url) ->
            $window.location.replace(url)


          buildAuthUrl: (omniauthWindowType, provider, opts={}) ->
            authUrl  = @getConfig(opts.config).apiUrl
            authUrl += @getConfig(opts.config).authProviderPaths[provider]
            authUrl += '?auth_origin_url=' + encodeURIComponent($window.location.href)

            params = angular.extend({}, opts.params || {}, {
              omniauth_window_type: omniauthWindowType
            })

            for key, val of params
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
          requestCredentialsViaPostMessage: (authWindow) ->
            # user has closed the external provider's auth window without
            # completing login.
            if authWindow.closed
              @handleAuthWindowClose(authWindow)

            # still awaiting user input
            else
              authWindow.postMessage("requestCredentials", "*")
              @requestCredentialsPollingTimer = $timeout((=>@requestCredentialsViaPostMessage(authWindow)), 500)


          # handle inAppBrowser's executeScript flow
          # flow will complete if:
          # 1. user completes authentication
          # 2. user fails authentication
          # 3. inAppBrowser auth window is closed
          requestCredentialsViaExecuteScript: (authWindow) ->
            @cancelOmniauthInAppBrowserListeners()
            handleAuthWindowClose = @handleAuthWindowClose.bind(this, authWindow)
            handleLoadStop = @handleLoadStop.bind(this, authWindow)

            authWindow.addEventListener('loadstop', handleLoadStop)
            authWindow.addEventListener('exit', handleAuthWindowClose)

            this.cancelOmniauthInAppBrowserListeners = () ->
              authWindow.removeEventListener('loadstop', handleLoadStop)
              authWindow.removeEventListener('exit', handleAuthWindowClose)


          # responds to inAppBrowser window loads
          handleLoadStop: (authWindow) ->
            _this = this
            authWindow.executeScript({code: 'requestCredentials()'}, (response) ->
              data = response[0]
              if data
                ev = new Event('message')
                ev.data = data
                _this.cancelOmniauthInAppBrowserListeners()
                $window.dispatchEvent(ev)
                _this.initDfd();
                authWindow.close()
            )

          # responds to inAppBrowser window closes
          handleAuthWindowClose: (authWindow) ->
            @cancel({
              reason: 'unauthorized'
              errors: ['User canceled login']
            })
            @cancelOmniauthInAppBrowserListeners
            $rootScope.$broadcast('auth:window-closed')

          # this needs to happen after a reflow so that the promise
          # can be rejected properly before it is destroyed.
          resolveDfd: ->
            @dfd.resolve(@user)
            $timeout((=>
              @dfd = null
              $rootScope.$digest() unless $rootScope.$$phase
            ), 0)


          # generates query string based on simple or complex object graphs
          buildQueryString: (param, prefix) ->
            str = []
            for k,v of param
              k = if prefix then prefix + "[" + k + "]" else k
              encoded = if angular.isObject(v) then @buildQueryString(v, k) else (k) + "=" + encodeURIComponent(v)
              str.push encoded
            str.join "&"


          # parses raw URL for querystring parameters to account for issues
          # with querystring / fragment ordering in angular < 1.4.x
          parseLocation: (location) ->
            locationSubstring = location.substring(1)
            obj = {}
            if locationSubstring
              pairs = locationSubstring.split('&')
              pair = undefined
              i = undefined
              for i of pairs
                `i = i`
                if (pairs[i] == '') || (typeof pairs[i] is 'function')
                  continue
                pair = pairs[i].split('=')
                obj[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1])
            obj


          # this is something that can be returned from 'resolve' methods
          # of pages that have restricted access
          validateUser: (opts={}) ->
            configName = opts.config

            unless @dfd?
              @initDfd()

              # save trip to API if possible. assume that user is still signed
              # in if auth headers are present and token has not expired.
              if @userIsAuthenticated()
                  # user is still presumably logged in
                  @resolveDfd()

              else
                # token querystring is present. user most likely just came from
                # registration email link.
                search = $location.search()

                # determine querystring params accounting for possible angular parsing issues
                location_parse = @parseLocation(window.location.search)
                params = if Object.keys(search).length==0 then location_parse else search

                # auth_token matches what is sent with postMessage, but supporting token for
                # backwards compatability
                token = params.auth_token || params.token

                if token != undefined
                  clientId   = params.client_id
                  uid        = params.uid
                  expiry     = params.expiry
                  configName = params.config

                  # use the configuration that was used in creating
                  # the confirmation link
                  @setConfigName(configName)

                  # check if redirected from password reset link
                  @mustResetPassword = params.reset_password

                  # check if redirected from email confirmation link
                  @firstTimeLogin = params.account_confirmation_success

                  # check if redirected from auth registration
                  @oauthRegistration = params.oauth_registration

                  # persist these values
                  @setAuthHeaders(@buildAuthHeaders({
                    token:    token
                    clientId: clientId
                    uid:      uid
                    expiry:   expiry
                  }))

                  # build url base
                  url = ($location.path() || '/')

                  # strip token-related qs from url to prevent re-use of these params
                  # on page refresh
                  ['auth_token', 'token', 'client_id', 'uid', 'expiry', 'config', 'reset_password', 'account_confirmation_success', 'oauth_registration'].forEach (prop) ->
                    delete params[prop];

                  # append any remaining params, if any
                  if Object.keys(params).length > 0
                    url += '?' + @buildQueryString(params);

                  # redirect to target url
                  $location.url(url)

                # token cookie is present. user is returning to the site, or
                # has refreshed the page.
                else if @retrieveData('currentConfigName')
                  configName = @retrieveData('currentConfigName')

                # cookie might not be set, but forcing token validation has
                # been enabled
                if @getConfig().forceValidateToken
                  @validateToken({config: configName})

                else if !isEmpty(@retrieveData('auth_headers'))
                  # if token has expired, do not verify token with API
                  if @tokenHasExpired()
                    $rootScope.$broadcast('auth:session-expired')
                    @rejectDfd({
                      reason: 'unauthorized'
                      errors: ['Session expired.']
                    })

                  else
                    # token has been saved in session var, token has not
                    # expired. must be verified with API.
                    @validateToken({config: configName})

                # new user session. will redirect to login
                else
                  @rejectDfd({
                    reason: 'unauthorized'
                    errors: ['No credentials']
                  })
                  $rootScope.$broadcast('auth:invalid')


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

                  if @oauthRegistration
                    $rootScope.$broadcast('auth:oauth-registration', @user)

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
                    errors: if data? then data.errors else ['Unspecified error']
                  })
                )
            else
              @rejectDfd({
                reason: 'unauthorized'
                errors: ['Expired credentials']
              })


          # ensure token has not expired
          tokenHasExpired: ->
            expiry = @getExpiry()
            now    = new Date().getTime()

            return (expiry and expiry < now)


          # get expiry by method provided in config
          getExpiry: ->
            @getConfig().parseExpiry(@retrieveData('auth_headers') || {})


          # this service attempts to cache auth tokens, but sometimes we
          # will want to discard saved tokens. examples include:
          # 1. login failure
          # 2. token validation failure
          # 3. user logs out
          invalidateTokens: ->
            # cannot delete user object for scoping reasons. instead, delete
            # all keys on object.
            delete @user[key] for key, val of @user

            # remove any assumptions about current configuration
            @deleteData('currentConfigName')

            $interval.cancel @timer if @timer?

            # kill cookies, otherwise session will resume on page reload
            # setting this value to null will force the validateToken method
            # to re-validate credentials with api server when validate is called
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
            $timeout.cancel(@requestCredentialsPollingTimer) if @requestCredentialsPollingTimer?

            # cancel any inAppBrowser listeners
            @cancelOmniauthInAppBrowserListeners()

            # must extend existing object for scoping reasons
            angular.extend @user, user

            # add shortcut to determine user auth status
            @user.signedIn   = true
            @user.configName = @getCurrentConfigName()

            # postMessage will not contain header. must save headers manually.
            if setHeader
              @setAuthHeaders(@buildAuthHeaders({
                token:    @user.auth_token
                clientId: @user.client_id
                uid:      @user.uid
                expiry:   @user.expiry
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
          persistData: (key, val, configName) ->
            if @getConfig(configName).storage instanceof Object
              @getConfig(configName).storage.persistData(key, val, @getConfig(configName))
            else
              switch @getConfig(configName).storage
                when 'localStorage'
                  $window.localStorage.setItem(key, JSON.stringify(val))
                when 'sessionStorage'
                  $window.sessionStorage.setItem(key, JSON.stringify(val))
                else
                  ipCookie(key, val, @getConfig().cookieOps)

          # abstract persistent data retrieval
          retrieveData: (key) ->
            try
              if @getConfig().storage instanceof Object
                @getConfig().storage.retrieveData(key)
              else
                switch @getConfig().storage
                  when 'localStorage'
                    JSON.parse($window.localStorage.getItem(key))
                  when 'sessionStorage'
                    JSON.parse($window.sessionStorage.getItem(key))
                  else ipCookie(key)
            catch e
              # gracefully handle if JSON parsing
              if e instanceof SyntaxError
                undefined
              else
                throw e

          # abstract persistent data removal
          deleteData: (key) ->
            if @getConfig().storage instanceof Object
              @getConfig().storage.deleteData(key);
            switch @getConfig().storage
              when 'localStorage'
                $window.localStorage.removeItem(key)
              when 'sessionStorage'
                $window.sessionStorage.removeItem(key)
              else
                ipCookie.remove(key, {path: @getConfig().cookieOps.path})

          # persist authentication token, client id, uid
          setAuthHeaders: (h) ->
            newHeaders = angular.extend((@retrieveData('auth_headers') || {}), h)
            result = @persistData('auth_headers', newHeaders)

            expiry = @getExpiry()
            now    = new Date().getTime()

            if expiry > now
              $interval.cancel @timer if @timer?

              @timer = $interval (=>
                @validateUser {config: @getSavedConfig()}
              ), (parseInt (expiry - now)), 1

            result



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



          # if value is a method, call the method. otherwise return the
          # argument itself
          getResultOrValue: (arg) ->
            if typeof(arg) == 'function'
              arg()
            else
              arg



          # a config name will be return in the following order of precedence:
          # 1. matches arg
          # 2. saved from past authentication
          # 3. first available config name
          getCurrentConfigName: (name) ->
            name || @getSavedConfig()


          # can't rely on retrieveData because it will cause a recursive loop
          # if config hasn't been initialized. instead find first available
          # value of 'defaultConfigName'. searches the following places in
          # this priority:
          # 1. localStorage
          # 2. sessionStorage
          # 3. cookies
          # 4. default (first available config)
          getSavedConfig: ->
            c   = undefined
            key = 'currentConfigName'

            if @hasLocalStorage()
              c ?= JSON.parse($window.localStorage.getItem(key))
            else if @hasSessionStorage()
              c ?= JSON.parse($window.sessionStorage.getItem(key))

            c ?= ipCookie(key)

            return c || defaultConfigName

          hasSessionStorage: ->
            if !@_hasSessionStorage?

              @_hasSessionStorage = false
              # trying to call setItem will
              # throw an error if sessionStorage is disabled
              try
                $window.sessionStorage.setItem('ng-token-auth-test', 'ng-token-auth-test');
                $window.sessionStorage.removeItem('ng-token-auth-test');
                @_hasSessionStorage = true
              catch error

            return @_hasSessionStorage

          hasLocalStorage: ->
            if !@_hasLocalStorage?

              @_hasLocalStorage = false
              # trying to call setItem will
              # throw an error if localStorage is disabled
              try
                $window.localStorage.setItem('ng-token-auth-test', 'ng-token-auth-test');
                $window.localStorage.removeItem('ng-token-auth-test');
                @_hasLocalStorage = true
              catch error

            return @_hasLocalStorage

      ]
    }
  )


  # each response will contain auth headers that have been updated by
  # the server. copy those headers for use in the next request.
  .config(['$httpProvider', ($httpProvider) ->

    # responses are sometimes returned out of order. check that response is
    # current before saving the auth data.
    tokenIsCurrent = ($auth, headers) ->
      oldTokenExpiry = Number($auth.getExpiry())
      newTokenExpiry = Number($auth.getConfig().parseExpiry(headers || {}))

      return newTokenExpiry >= oldTokenExpiry


    # uniform handling of response headers for success or error conditions
    updateHeadersFromResponse = ($auth, resp) ->
      newHeaders = {}
      for key, val of $auth.getConfig().tokenFormat
        if resp.headers(key)
          newHeaders[key] = resp.headers(key)

      if tokenIsCurrent($auth, newHeaders)
        $auth.setAuthHeaders(newHeaders)

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
            for key, val of $auth.retrieveData('auth_headers')
              req.headers[key] = val
        ]

        return req

      response: (resp) ->
        $injector.invoke ['$http', '$auth', ($http, $auth) ->
          if resp.config.url.match($auth.apiUrl())
            return updateHeadersFromResponse($auth, resp)
        ]

        return resp

      responseError: (resp) ->
        $injector.invoke ['$http', '$auth', ($http, $auth) ->
          if resp.config.url.match($auth.apiUrl())
            return updateHeadersFromResponse($auth, resp)
        ]

        return $injector.get('$q').reject(resp)
    ]

    # define http methods that may need to carry auth headers
    httpMethods = ['get', 'post', 'put', 'patch', 'delete']

    # disable IE ajax request caching for each of the necessary http methods
    angular.forEach(httpMethods, (method) ->
      $httpProvider.defaults.headers[method] ?= {}
      $httpProvider.defaults.headers[method]['If-Modified-Since'] = 'Mon, 26 Jul 1997 05:00:00 GMT'
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
