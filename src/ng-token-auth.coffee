angular.module('ng-token-auth', ['ngCookies'])
  .provider('$auth', ->
    config =
      apiUrl:                  '/api'
      signOutUrl:              '/auth/sign_out'
      emailSignInPath:         '/auth/sign_in'
      emailRegistrationPath:   '/auth'
      confirmationSuccessUrl:  window.location.href
      passwordResetPath:       '/auth/password'
      passwordUpdatePath:      '/auth/password'
      passwordResetSuccessUrl: window.location.href
      tokenValidationPath:     '/auth/validate_token'
      proxyIf:                 -> false
      proxyUrl:                '/proxy'
      validateOnPageLoad:      true
      forceHardRedirect:       false
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
            $rootScope.submitRegistration   = (params) => @submitRegistration(params)
            $rootScope.submitLogin          = (params) => @submitLogin(params)
            $rootScope.requestPasswordReset = (params) => @requestPasswordReset(params)
            $rootScope.updatePassword       = (params) => @updatePassword(params)

            # check to see if user is returning user
            if @config.validateOnPageLoad
              @validateUser()


          # register by email. server will send confirmation email
          # containing a link to activate the account. the link will
          # redirect to this site.
          submitRegistration: (params) ->
            angular.extend(params, {
              confirm_success_url: config.confirmationSuccessUrl
            })
            $http.post(@apiUrl() + config.emailRegistrationPath, params)
              .success(->
                $rootScope.$broadcast('auth:registration-email-success', params)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:registration-email-error', resp)
              )


          # capture input from user, authenticate serverside
          submitLogin: (params) ->
            @initDfd()
            $http.post(@apiUrl() + config.emailSignInPath, params)
              .success((resp) =>
                @handleValidAuth(resp.data)
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


          # request password reset from API
          requestPasswordReset: (params) ->
            params.redirect_url = config.passwordResetSuccessUrl

            $http.post(@apiUrl() + config.passwordResetPath, params)
              .success(->
                $rootScope.$broadcast('auth:password-reset-request-success', params)
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:password-reset-request-error', resp)
              )


          # update user password
          updatePassword: (params) ->
            $http.put(@apiUrl() + config.passwordUpdatePath, params)
              .success((resp) =>
                $rootScope.$broadcast('auth:password-change-success', resp)
                @mustResetPassword = false
              )
              .error((resp) ->
                $rootScope.$broadcast('auth:password-change-error', resp)
              )


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
            @dfd.resolve({id: @user.id})
            $timeout((=>
              @dfd = null
              $rootScope.$digest() unless $rootScope.$$phase
            ), 0)


          # this is something that can be returned from 'resolve' methods
          # of pages that have restricted access
          validateUser: ->
            unless @dfd?
              @initDfd()

              unless @header and @user.id
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
                  @setAuthHeader(@buildAuthToken(token, clientId, uid))

                  # strip qs from url to prevent re-use of these params
                  # on page refresh
                  $location.url(($location.path() || '/'))

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
                  errors: ['Invalid/expired credentials']
                })
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
                $rootScope.$broadcast('auth:logout-error', resp)
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


          # auth token format. consider making this configurable
          buildAuthToken: (token, clientId, uid) ->
            "token=#{token} client=#{clientId} uid=#{uid}"


          # persist authentication token, client id, uid
          setAuthHeader: (header) ->
            @header = $http.defaults.headers.common['Authorization'] = header
            $cookieStore.put('auth_header', header)


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
  .config(($httpProvider) ->
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

    # define http methods that may need to carry auth headers
    httpMethods = ['get', 'post', 'put', 'patch', 'delete']

    # disable IE ajax request caching for each of the necessary http methods
    angular.forEach(httpMethods, (method) ->
      $httpProvider.defaults.headers[method] ?= method
      $httpProvider.defaults.headers[method]['If-Modified-Since'] = '0'
    )

  )

  .run(($auth, $window, $rootScope) -> $auth.initialize())


# ie8 and ie9 require special handling
window.isOldIE = ->
  out = false
  nav = navigator.userAgent.toLowerCase()
  if nav and nav.indexOf('msie') != -1
    version = parseInt(nav.split('msie')[1])
    if version < 10
      out = true

  out
