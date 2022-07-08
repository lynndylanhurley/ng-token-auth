/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
if ((typeof module !== 'undefined') && (typeof exports !== 'undefined') && (module.exports === exports)) {
  module.exports = 'ng-token-auth';
}

angular.module('ng-token-auth', ['ipCookie'])
  .provider('$auth', function() {
    const configs = {
      default: {
        apiUrl:                  '/api',
        signOutUrl:              '/auth/sign_out',
        emailSignInPath:         '/auth/sign_in',
        emailRegistrationPath:   '/auth',
        accountUpdatePath:       '/auth',
        accountDeletePath:       '/auth',
        confirmationSuccessUrl() { return window.location.href; },
        passwordResetPath:       '/auth/password',
        passwordUpdatePath:      '/auth/password',
        passwordResetSuccessUrl() { return window.location.href; },
        tokenValidationPath:     '/auth/validate_token',
        proxyIf() { return false; },
        proxyUrl:                '/proxy',
        validateOnPageLoad:      true,
        omniauthWindowType:      'sameWindow',
        storage:                 'cookies',
        forceValidateToken:      false,

        tokenFormat: {
          "access-token": "{{ token }}",
          "token-type":   "Bearer",
          client:         "{{ clientId }}",
          expiry:         "{{ expiry }}",
          uid:            "{{ uid }}"
        },

        cookieOps: {
          path: "/",
          expires: 9999,
          expirationUnit: 'days',
          secure: false
        },

        // popups are difficult to test. mock this method in testing.
        createPopup(url) {
          return window.open(url, '_blank', 'closebuttoncaption=Cancel');
        },

        parseExpiry(headers) {
          // convert from ruby time (seconds) to js time (millis)
          return (parseInt(headers['expiry'], 10) * 1000) || null;
        },

        handleLoginResponse(resp) { return resp.data; },
        handleAccountUpdateResponse(resp) { return resp.data; },
        handleTokenValidationResponse(resp) { return resp.data; },

        authProviderPaths: {
          github:    '/auth/github',
          facebook:  '/auth/facebook',
          google:    '/auth/google_oauth2',
          apple:     '/auth/apple'
        }
      }
    };


    let defaultConfigName = "default";


    return {
      configure(params) {

        // user is using multiple concurrent configs (>1 user types).
        if (params instanceof Array && params.length) {
          // extend each item in array from default settings
          for (let i = 0; i < params.length; i++) {
            // get the name of the config
            const conf = params[i];
            let label = null;
            for (let k in conf) {
              const v = conf[k];
              label = k;

              // set the first item in array as default config
              if (i === 0) { defaultConfigName = label; }
            }

            // use copy preserve the original default settings object while
            // extending each config object
            const defaults = angular.copy(configs["default"]);
            const fullConfig = {};
            fullConfig[label] = angular.extend(defaults, conf[label]);
            angular.extend(configs, fullConfig);
          }


          // remove existng default config
          if (defaultConfigName !== "default") { delete configs["default"]; }

        // user is extending the single default config
        } else if (params instanceof Object) {
          angular.extend(configs["default"], params);


        // user is doing something wrong
        } else {
          throw "Invalid argument: ng-token-auth config should be an Array or Object.";
        }

        return configs;
      },


      $get: [
        '$http',
        '$q',
        '$location',
        'ipCookie',
        '$window',
        '$timeout',
        '$rootScope',
        '$interpolate',
        '$interval',
        ($http, $q, $location, ipCookie, $window, $timeout, $rootScope, $interpolate, $interval) => {
          return {
            header:            null,
            dfd:               null,
            user:              {},
            mustResetPassword: false,
            listener:          null,

            // called once at startup
            initialize() {
              this.initializeListeners();
              this.cancelOmniauthInAppBrowserListeners = (function() {});
              return this.addScopeMethods();
            },

            initializeListeners() {
              //@listener = @handlePostMessage.bind(@)
              this.listener = angular.bind(this, this.handlePostMessage);

              if ($window.addEventListener) {
                return $window.addEventListener("message", this.listener, false);
              }
            },


            cancel(reason) {
              // cancel any pending timers
              if (this.requestCredentialsPollingTimer != null) {
                $timeout.cancel(this.requestCredentialsPollingTimer);
              }

              // cancel inAppBrowser listeners if set
              this.cancelOmniauthInAppBrowserListeners();

              // reject any pending promises
              if (this.dfd != null) {
                this.rejectDfd(reason);
              }

              // nullify timer after reflow
              return $timeout((() => { return this.requestCredentialsPollingTimer = null; }), 0);
            },


            // cancel any pending processes, clean up garbage
            destroy() {
              this.cancel();

              if ($window.removeEventListener) {
                return $window.removeEventListener("message", this.listener, false);
              }
            },


            // handle the events broadcast from external auth tabs/popups
            handlePostMessage(ev) {
              if (ev.data.message === 'deliverCredentials') {
                delete ev.data.message;

                // check if a new user was registered
                const oauthRegistration = ev.data.oauth_registration;
                delete ev.data.oauth_registration;
                this.handleValidAuth(ev.data, true);
                $rootScope.$broadcast('auth:login-success', ev.data);
                if (oauthRegistration) {
                  $rootScope.$broadcast('auth:oauth-registration', ev.data);
                }
              }
              if (ev.data.message === 'authFailure') {
                const error = {
                  reason: 'unauthorized',
                  errors: [ev.data.error]
                };
                this.cancel(error);
                return $rootScope.$broadcast('auth:login-error', error);
              }
            },


            // make all public API methods available to directives
            addScopeMethods() {
              // bind global user object to auth user
              $rootScope.user = this.user;

              // template access to authentication method
              $rootScope.authenticate  = angular.bind(this, this.authenticate);

              // template access to view actions
              $rootScope.signOut              = angular.bind(this, this.signOut);
              $rootScope.destroyAccount       = angular.bind(this, this.destroyAccount);
              $rootScope.submitRegistration   = angular.bind(this, this.submitRegistration);
              $rootScope.submitLogin          = angular.bind(this, this.submitLogin);
              $rootScope.requestPasswordReset = angular.bind(this, this.requestPasswordReset);
              $rootScope.updatePassword       = angular.bind(this, this.updatePassword);
              $rootScope.updateAccount        = angular.bind(this, this.updateAccount);

              // check to see if user is returning user
              if (this.getConfig().validateOnPageLoad) {
                return this.validateUser({config: this.getSavedConfig()});
              }
            },


            // register by email. server will send confirmation email
            // containing a link to activate the account. the link will
            // redirect to this site.
            submitRegistration(params, opts) {
              if (opts == null) { opts = {}; }
              const successUrl = this.getResultOrValue(this.getConfig(opts.config).confirmationSuccessUrl);
              angular.extend(params, {
                confirm_success_url: successUrl,
                config_name: this.getCurrentConfigName(opts.config)
              });
              const request = $http.post(this.apiUrl(opts.config) + this.getConfig(opts.config).emailRegistrationPath, params);
              request
                .then(resp => $rootScope.$broadcast('auth:registration-email-success', params)
                , resp => $rootScope.$broadcast('auth:registration-email-error', resp.data));
              return request;
            },


            // capture input from user, authenticate serverside
            submitLogin(params, opts, httpopts) {
              if (opts == null) { opts = {}; }
              if (httpopts == null) { httpopts = {}; }
              this.initDfd();
              $http.post(this.apiUrl(opts.config) + this.getConfig(opts.config).emailSignInPath, params, httpopts)
                .then(resp => {
                  this.setConfigName(opts.config);
                  const authData = this.getConfig(opts.config).handleLoginResponse(resp.data, this);
                  this.handleValidAuth(authData);
                  return $rootScope.$broadcast('auth:login-success', this.user);
                }
                , resp => {
                  this.rejectDfd({
                    reason: 'unauthorized',
                    errors: ['Invalid credentials']
                  });
                  return $rootScope.$broadcast('auth:login-error', resp.data);
                });
              return this.dfd.promise;
            },


            // check if user is authenticated
            userIsAuthenticated() {
              return this.retrieveData('auth_headers') && this.user.signedIn && !this.tokenHasExpired();
            },


            // request password reset from API
            requestPasswordReset(params, opts) {
              if (opts == null) { opts = {}; }
              const successUrl = this.getResultOrValue(
                this.getConfig(opts.config).passwordResetSuccessUrl
              );

              params.redirect_url = successUrl;
              if (opts.config != null) { params.config_name  = opts.config; }

              const request = $http.post(this.apiUrl(opts.config) + this.getConfig(opts.config).passwordResetPath, params);
              request
                .then(resp => $rootScope.$broadcast('auth:password-reset-request-success', params)
                , resp => $rootScope.$broadcast('auth:password-reset-request-error', resp.data));
              return request;
            },


            // update user password
            updatePassword(params) {
              const request = $http.put(this.apiUrl() + this.getConfig().passwordUpdatePath, params);
              request
                .then(resp => {
                  $rootScope.$broadcast('auth:password-change-success', resp.data);
                  return this.mustResetPassword = false;
                }
                , resp => $rootScope.$broadcast('auth:password-change-error', resp.data));
              return request;
            },


            // update user account info
            updateAccount(params) {
              const request = $http.put(this.apiUrl() + this.getConfig().accountUpdatePath, params);
              request
                .then(resp => {
                  const updateResponse = this.getConfig().handleAccountUpdateResponse(resp.data);
                  const curHeaders = this.retrieveData('auth_headers');

                  angular.extend(this.user, updateResponse);

                  // ensure any critical headers (uid + ?) that are returned in
                  // the update response are updated appropriately in storage
                  if (curHeaders) {
                    const newHeaders = {};
                    const object = this.getConfig().tokenFormat;
                    for (let key in object) {
                      const val = object[key];
                      if (curHeaders[key] && updateResponse[key]) {
                        newHeaders[key] = updateResponse[key];
                      }
                    }
                    this.setAuthHeaders(newHeaders);
                  }

                  return $rootScope.$broadcast('auth:account-update-success', resp.data);
                }
                , resp => $rootScope.$broadcast('auth:account-update-error', resp.data));
              return request;
            },


            // permanently destroy a user's account.
            destroyAccount(params) {
              const request = $http.delete(this.apiUrl() + this.getConfig().accountUpdatePath, params);
              request
                .then(resp => {
                  this.invalidateTokens();
                  return $rootScope.$broadcast('auth:account-destroy-success', resp.data);
                }
                , resp => $rootScope.$broadcast('auth:account-destroy-error', resp.data));
              return request;
            },


            // open external auth provider in separate window, send requests for
            // credentials until api auth callback page responds.
            authenticate(provider, opts) {
              if (opts == null) { opts = {}; }
              if (this.dfd == null) {
                this.setConfigName(opts.config);
                this.initDfd();
                this.openAuthWindow(provider, opts);
              }

              return this.dfd.promise;
            },


            setConfigName(configName) {
              if (configName == null) { configName = defaultConfigName; }
              return this.persistData('currentConfigName', configName, configName);
            },


            // open external window to authentication provider
            openAuthWindow(provider, opts) {

              const {
                omniauthWindowType
              } = this.getConfig(opts.config);
              const authUrl = this.buildAuthUrl(omniauthWindowType, provider, opts);

              if (omniauthWindowType === 'newWindow') {
                return this.requestCredentialsViaPostMessage(this.getConfig().createPopup(authUrl));
              } else if (omniauthWindowType === 'inAppBrowser') {
                return this.requestCredentialsViaExecuteScript(this.getConfig().createPopup(authUrl));
              } else if (omniauthWindowType === 'sameWindow') {
                return this.visitUrl(authUrl);
              } else {
                throw 'Unsupported omniauthWindowType "#{omniauthWindowType}"';
              }
            },


            // testing actual redirects is difficult. stub this for testing
            visitUrl(url) {
              return $window.location.replace(url);
            },


            buildAuthUrl(omniauthWindowType, provider, opts) {
              if (opts == null) { opts = {}; }
              let authUrl  = this.getConfig(opts.config).apiUrl;
              authUrl += this.getConfig(opts.config).authProviderPaths[provider];
              authUrl += '?auth_origin_url=' + encodeURIComponent(opts.auth_origin_url || $window.location.href);

              const params = angular.extend({}, opts.params || {}, {
                omniauth_window_type: omniauthWindowType
              });

              for (let key in params) {
                const val = params[key];
                authUrl += '&';
                authUrl += encodeURIComponent(key);
                authUrl += '=';
                authUrl += encodeURIComponent(val);
              }

              return authUrl;
            },

            // ping auth window to see if user has completed registration.
            // this method is recursively called until:
            // 1. user completes authentication
            // 2. user fails authentication
            // 3. auth window is closed
            requestCredentialsViaPostMessage(authWindow) {
              // user has closed the external provider's auth window without
              // completing login.
              if (authWindow.closed) {
                return this.handleAuthWindowClose(authWindow);

              // still awaiting user input
              } else {
                authWindow.postMessage("requestCredentials", "*");
                return this.requestCredentialsPollingTimer = $timeout((() => this.requestCredentialsViaPostMessage(authWindow)), 500);
              }
            },


            // handle inAppBrowser's executeScript flow
            // flow will complete if:
            // 1. user completes authentication
            // 2. user fails authentication
            // 3. inAppBrowser auth window is closed
            requestCredentialsViaExecuteScript(authWindow) {
              this.cancelOmniauthInAppBrowserListeners();
              const handleAuthWindowClose = this.handleAuthWindowClose.bind(this, authWindow);
              const handleLoadStop = this.handleLoadStop.bind(this, authWindow);
              const handlePostMessage = this.handlePostMessage.bind(this);

              authWindow.addEventListener('loadstop', handleLoadStop);
              authWindow.addEventListener('exit', handleAuthWindowClose);
              authWindow.addEventListener('message', handlePostMessage);

              return this.cancelOmniauthInAppBrowserListeners = function() {
                authWindow.removeEventListener('loadstop', handleLoadStop);
                authWindow.removeEventListener('exit', handleAuthWindowClose);
                return authWindow.addEventListener('message', handlePostMessage);
              };
            },


            // responds to inAppBrowser window loads
            handleLoadStop(authWindow) {
              const _this = this;

              // favor InAppBrowser postMessage API if available, otherwise revert to returning directly via
              // the executeScript API, which is known to have limitations on payload size
              const remoteCode = `\
function performBestTransit() { \
var data = requestCredentials(); \
if (webkit && webkit.messageHandlers && webkit.messageHandlers.cordova_iab) { \
var dataWithDeliverMessage = Object.assign({}, data, { message: 'deliverCredentials' }); \
webkit.messageHandlers.cordova_iab.postMessage(JSON.stringify(dataWithDeliverMessage)); \
return 'postMessageSuccess'; \
} else { \
return data; \
} \
} \
performBestTransit();`;

              return authWindow.executeScript({code: remoteCode }, function(response) {
                const data = response[0];
                if (data === 'postMessageSuccess') {
                  // the standard issue postHandler will take care of the rest
                  return authWindow.close();
                } else if (data) {
                  const ev = new Event('message');
                  ev.data = data;
                  _this.cancelOmniauthInAppBrowserListeners();
                  $window.dispatchEvent(ev);
                  _this.initDfd();
                  return authWindow.close();
                }
              });
            },

            // responds to inAppBrowser window closes
            handleAuthWindowClose(authWindow) {
              this.cancel({
                reason: 'unauthorized',
                errors: ['User canceled login']
              });
              this.cancelOmniauthInAppBrowserListeners;
              return $rootScope.$broadcast('auth:window-closed');
            },

            // this needs to happen after a reflow so that the promise
            // can be rejected properly before it is destroyed.
            resolveDfd() {
              if (!this.dfd) { return; }
              this.dfd.resolve(this.user);
              return $timeout((() => {
                this.dfd = null;
                if (!$rootScope.$$phase) { return $rootScope.$digest(); }
              }
              ), 0);
            },


            // generates query string based on simple or complex object graphs
            buildQueryString(param, prefix) {
              const str = [];
              for (let k in param) {
                const v = param[k];
                k = prefix ? prefix + "[" + k + "]" : k;
                const encoded = angular.isObject(v) ? this.buildQueryString(v, k) : (k) + "=" + encodeURIComponent(v);
                str.push(encoded);
              }
              return str.join("&");
            },


            // parses raw URL for querystring parameters to account for issues
            // with querystring / fragment ordering in angular < 1.4.x
            parseLocation(location) {
              const locationSubstring = location.substring(1);
              const obj = {};
              if (locationSubstring) {
                const pairs = locationSubstring.split('&');
                let pair = undefined;
                let i = undefined;
                for (i in pairs) {
                  i = i;
                  if ((pairs[i] === '') || (typeof pairs[i] === 'function')) {
                    continue;
                  }
                  pair = pairs[i].split('=');
                  obj[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1]);
                }
              }
              return obj;
            },


            // this is something that can be returned from 'resolve' methods
            // of pages that have restricted access
            validateUser(opts) {
              if (opts == null) { opts = {}; }
              let configName = opts.config;

              if (this.dfd == null) {
                this.initDfd();

                // save trip to API if possible. assume that user is still signed
                // in if auth headers are present and token has not expired.
                if (this.userIsAuthenticated()) {
                    // user is still presumably logged in
                    this.resolveDfd();

                } else {
                  // token querystring is present. user most likely just came from
                  // registration email link.
                  const search = $location.search();

                  // determine querystring params accounting for possible angular parsing issues
                  const location_parse = this.parseLocation(window.location.search);
                  const params = Object.keys(search).length===0 ? location_parse : search;

                  // auth_token matches what is sent with postMessage, but supporting token for
                  // backwards compatability
                  const token = params.auth_token || params.token;

                  if (token !== undefined) {
                    const clientId   = params.client_id;
                    const {
                      uid
                    } = params;
                    const {
                      expiry
                    } = params;
                    configName = params.config;

                    // use the configuration that was used in creating
                    // the confirmation link
                    this.setConfigName(configName);

                    // check if redirected from password reset link
                    this.mustResetPassword = params.reset_password;

                    // check if redirected from email confirmation link
                    this.firstTimeLogin = params.account_confirmation_success;

                    // check if redirected from auth registration
                    this.oauthRegistration = params.oauth_registration;

                    // persist these values
                    this.setAuthHeaders(this.buildAuthHeaders({
                      token,
                      clientId,
                      uid,
                      expiry
                    }));

                    // build url base
                    let url = ($location.path() || '/');

                    // strip token-related qs from url to prevent re-use of these params
                    // on page refresh
                    ['auth_token', 'token', 'client_id', 'uid', 'expiry', 'config', 'reset_password', 'account_confirmation_success', 'oauth_registration'].forEach(prop => delete params[prop]);

                    // append any remaining params, if any
                    if (Object.keys(params).length > 0) {
                      url += '?' + this.buildQueryString(params);
                    }

                    // redirect to target url
                    $location.url(url);

                  // token cookie is present. user is returning to the site, or
                  // has refreshed the page.
                  } else if (this.retrieveData('currentConfigName')) {
                    configName = this.retrieveData('currentConfigName');
                  }

                  // cookie might not be set, but forcing token validation has
                  // been enabled
                  if (this.getConfig().forceValidateToken) {
                    this.validateToken({config: configName});

                  } else if (!isEmpty(this.retrieveData('auth_headers'))) {
                    // if token has expired, do not verify token with API
                    if (this.tokenHasExpired()) {
                      $rootScope.$broadcast('auth:session-expired');
                      this.rejectDfd({
                        reason: 'unauthorized',
                        errors: ['Session expired.']
                      });

                    } else {
                      // token has been saved in session var, token has not
                      // expired. must be verified with API.
                      this.validateToken({config: configName});
                    }

                  // new user session. will redirect to login
                  } else {
                    this.rejectDfd({
                      reason: 'unauthorized',
                      errors: ['No credentials']
                    });
                    $rootScope.$broadcast('auth:invalid');
                  }
                }
              }


              return this.dfd.promise;
            },


            // confirm that user's auth token is still valid.
            validateToken(opts) {
              if (opts == null) { opts = {}; }
              if (!this.tokenHasExpired()) {
                return $http.get(this.apiUrl(opts.config) + this.getConfig(opts.config).tokenValidationPath)
                  .then(resp => {
                    const authData = this.getConfig(opts.config).handleTokenValidationResponse(resp.data);
                    this.handleValidAuth(authData);

                    // broadcast event for first time login
                    if (this.firstTimeLogin) {
                      $rootScope.$broadcast('auth:email-confirmation-success', this.user);
                    }

                    if (this.oauthRegistration) {
                      $rootScope.$broadcast('auth:oauth-registration', this.user);
                    }

                    if (this.mustResetPassword) {
                      $rootScope.$broadcast('auth:password-reset-confirm-success', this.user);
                    }

                    return $rootScope.$broadcast('auth:validation-success', this.user);
                  }

                  , resp => {
                    // broadcast event for first time login failure
                    if (this.firstTimeLogin) {
                      $rootScope.$broadcast('auth:email-confirmation-error', resp.data);
                    }

                    if (this.mustResetPassword) {
                      $rootScope.$broadcast('auth:password-reset-confirm-error', resp.data);
                    }

                    $rootScope.$broadcast('auth:validation-error', resp.data);

                    // No data is no response, no response is no connection. Token cannot be destroyed if no connection
                    return this.rejectDfd({
                      reason: 'unauthorized',
                      errors: (resp.data != null) ? resp.data.errors : ['Unspecified error']
                    }
                    ,
                      resp.status > 0
                    );

                  });
              } else {
                return this.rejectDfd({
                  reason: 'unauthorized',
                  errors: ['Expired credentials']
                });
              }
            },


            // ensure token has not expired
            tokenHasExpired() {
              const expiry = this.getExpiry();
              const now    = new Date().getTime();

              return (expiry && (expiry < now));
            },


            // get expiry by method provided in config
            getExpiry() {
              return this.getConfig().parseExpiry(this.retrieveData('auth_headers') || {});
            },


            // this service attempts to cache auth tokens, but sometimes we
            // will want to discard saved tokens. examples include:
            // 1. login failure
            // 2. token validation failure
            // 3. user logs out
            invalidateTokens() {
              // cannot delete user object for scoping reasons. instead, delete
              // all keys on object.
              for (let key in this.user) { const val = this.user[key]; delete this.user[key]; }

              // remove any assumptions about current configuration
              this.deleteData('currentConfigName');

              if (this.timer != null) { $interval.cancel(this.timer); }

              // kill cookies, otherwise session will resume on page reload
              // setting this value to null will force the validateToken method
              // to re-validate credentials with api server when validate is called
              return this.deleteData('auth_headers');
            },


            // destroy auth token on server, destroy user auth credentials
            signOut() {
              const request = $http.delete(this.apiUrl() + this.getConfig().signOutUrl);
              request.then(resp => {
                  this.invalidateTokens();
                  return $rootScope.$broadcast('auth:logout-success');
                }
                , resp => {
                  this.invalidateTokens();
                  return $rootScope.$broadcast('auth:logout-error', resp.data);
                });
              return request;
            },


            // handle successful authentication
            handleValidAuth(user, setHeader) {
              // cancel any pending postMessage checks
              if (setHeader == null) { setHeader = false; }
              if (this.requestCredentialsPollingTimer != null) { $timeout.cancel(this.requestCredentialsPollingTimer); }

              // cancel any inAppBrowser listeners
              this.cancelOmniauthInAppBrowserListeners();

              // must extend existing object for scoping reasons
              angular.extend(this.user, user);

              // add shortcut to determine user auth status
              this.user.signedIn   = true;
              this.user.configName = this.getCurrentConfigName();

              // postMessage will not contain header. must save headers manually.
              if (setHeader) {
                this.setAuthHeaders(this.buildAuthHeaders({
                  token:    this.user.auth_token,
                  clientId: this.user.client_id,
                  uid:      this.user.uid,
                  expiry:   this.user.expiry
                }));
              }

              // fulfill promise
              return this.resolveDfd();
            },


            // configure auth token format.
            buildAuthHeaders(ctx) {
              const headers = {};

              const object = this.getConfig().tokenFormat;
              for (let key in object) {
                const val = object[key];
                headers[key] = $interpolate(val)(ctx);
              }

              return headers;
            },


            // abstract persistent data store
            persistData(key, val, configName) {
              if (this.getConfig(configName).storage instanceof Object) {
                return this.getConfig(configName).storage.persistData(key, val, this.getConfig(configName));
              } else {
                switch (this.getConfig(configName).storage) {
                  case 'localStorage':
                    return $window.localStorage.setItem(key, JSON.stringify(val));
                  case 'sessionStorage':
                    return $window.sessionStorage.setItem(key, JSON.stringify(val));
                  default:
                    return ipCookie(key, val, this.getConfig().cookieOps);
                }
              }
            },

            // abstract persistent data retrieval
            retrieveData(key) {
              try {
                if (this.getConfig().storage instanceof Object) {
                  return this.getConfig().storage.retrieveData(key);
                } else {
                  switch (this.getConfig().storage) {
                    case 'localStorage':
                      return JSON.parse($window.localStorage.getItem(key));
                    case 'sessionStorage':
                      return JSON.parse($window.sessionStorage.getItem(key));
                    default: return ipCookie(key);
                  }
                }
              } catch (e) {
                // gracefully handle if JSON parsing
                if (e instanceof SyntaxError) {
                  return undefined;
                } else {
                  throw e;
                }
              }
            },

            // abstract persistent data removal
            deleteData(key) {
              if (this.getConfig().storage instanceof Object) {
                this.getConfig().storage.deleteData(key);
              }
              switch (this.getConfig().storage) {
                case 'localStorage':
                  return $window.localStorage.removeItem(key);
                case 'sessionStorage':
                  return $window.sessionStorage.removeItem(key);
                default:
                  var cookieOps = {path: this.getConfig().cookieOps.path};

                  if (this.getConfig().cookieOps.domain !== undefined) {
                    cookieOps.domain = this.getConfig().cookieOps.domain;
                  }

                  return ipCookie.remove(key, cookieOps);
              }
            },

            // persist authentication token, client id, uid
            setAuthHeaders(h) {
              const newHeaders = angular.extend((this.retrieveData('auth_headers') || {}), h);
              const result = this.persistData('auth_headers', newHeaders);

              const expiry = this.getExpiry();
              const now    = new Date().getTime();

              if (expiry > now) {
                if (this.timer != null) { $interval.cancel(this.timer); }

                this.timer = $interval((() => {
                  return this.validateUser({config: this.getSavedConfig()});
                }
                ), (parseInt((expiry - now))), 1);
              }

              return result;
            },



            initDfd() {
              this.dfd = $q.defer();
              return this.dfd.promise.then(angular.noop, angular.noop);
            },

            // failed login. invalidate auth header and reject promise.
            // defered object must be destroyed after reflow.
            rejectDfd(reason, invalidateTokens) {
              if (invalidateTokens == null) { invalidateTokens = true; }
              if (invalidateTokens === true) { this.invalidateTokens(); }
              if (this.dfd != null) {
                this.dfd.reject(reason);

                // must nullify after reflow so promises can be rejected
                return $timeout((() => { return this.dfd = null; }), 0);
              }
            },


            // use proxy for IE
            apiUrl(configName) {
              if (this.getConfig(configName).proxyIf()) {
                return this.getConfig(configName).proxyUrl;
              } else {
                return this.getConfig(configName).apiUrl;
              }
            },


            getConfig(name) {
              return configs[this.getCurrentConfigName(name)];
            },



            // if value is a method, call the method. otherwise return the
            // argument itself
            getResultOrValue(arg) {
              if (typeof(arg) === 'function') {
                return arg();
              } else {
                return arg;
              }
            },



            // a config name will be return in the following order of precedence:
            // 1. matches arg
            // 2. saved from past authentication
            // 3. first available config name
            getCurrentConfigName(name) {
              return name || this.getSavedConfig();
            },


            // can't rely on retrieveData because it will cause a recursive loop
            // if config hasn't been initialized. instead find first available
            // value of 'defaultConfigName'. searches the following places in
            // this priority:
            // 1. localStorage
            // 2. sessionStorage
            // 3. cookies
            // 4. default (first available config)
            getSavedConfig() {
              let c   = undefined;
              const key = 'currentConfigName';

              if (this.hasLocalStorage()) {
                if (c == null) { c = JSON.parse($window.localStorage.getItem(key)); }
              } else if (this.hasSessionStorage()) {
                if (c == null) { c = JSON.parse($window.sessionStorage.getItem(key)); }
              }

              if (c == null) { c = ipCookie(key); }

              return c || defaultConfigName;
            },

            hasSessionStorage() {
              if ((this._hasSessionStorage == null)) {

                this._hasSessionStorage = false;
                // trying to call setItem will
                // throw an error if sessionStorage is disabled
                try {
                  $window.sessionStorage.setItem('ng-token-auth-test', 'ng-token-auth-test');
                  $window.sessionStorage.removeItem('ng-token-auth-test');
                  this._hasSessionStorage = true;
                } catch (error) {}
              }

              return this._hasSessionStorage;
            },

            hasLocalStorage() {
              if ((this._hasLocalStorage == null)) {

                this._hasLocalStorage = false;
                // trying to call setItem will
                // throw an error if localStorage is disabled
                try {
                  $window.localStorage.setItem('ng-token-auth-test', 'ng-token-auth-test');
                  $window.localStorage.removeItem('ng-token-auth-test');
                  this._hasLocalStorage = true;
                } catch (error) {}
              }

              return this._hasLocalStorage;
            }
          };
        }

      ]
    };
  })


  // each response will contain auth headers that have been updated by
  // the server. copy those headers for use in the next request.
  .config(['$httpProvider', function($httpProvider) {

    // responses are sometimes returned out of order. check that response is
    // current before saving the auth data.
    const tokenIsCurrent = function($auth, headers) {
      const oldTokenExpiry = Number($auth.getExpiry());
      const newTokenExpiry = Number($auth.getConfig().parseExpiry(headers || {}));

      return newTokenExpiry >= oldTokenExpiry;
    };


    // uniform handling of response headers for success or error conditions
    const updateHeadersFromResponse = function($auth, resp) {
      const newHeaders = {};
      const object = $auth.getConfig().tokenFormat;
      for (let key in object) {
        const val = object[key];
        if (resp.headers(key)) {
          newHeaders[key] = resp.headers(key);
        }
      }

      if (tokenIsCurrent($auth, newHeaders)) {
        return $auth.setAuthHeaders(newHeaders);
      }
    };

    // this is ugly...
    // we need to configure an interceptor (must be done in the configuration
    // phase), but we need access to the $http service, which is only available
    // during the run phase. the following technique was taken from this
    // stackoverflow post:
    // http://stackoverflow.com/questions/14681654/i-need-two-instances-of-angularjs-http-service-or-what
    $httpProvider.interceptors.push(['$injector', $injector => ({
      request(req) {
        $injector.invoke(['$http', '$auth',  function($http, $auth) {
          if (req.url.match($auth.apiUrl())) {
            return (() => {
              const result = [];
              const object = $auth.retrieveData('auth_headers');
              for (let key in object) {
                const val = object[key];
                result.push(req.headers[key] = val);
              }
              return result;
            })();
          }
        }
        ]);

        return req;
      },

      response(resp) {
        $injector.invoke(['$http', '$auth', function($http, $auth) {
          if (resp.config.url.match($auth.apiUrl())) {
            return updateHeadersFromResponse($auth, resp);
          }
        }
        ]);

        return resp;
      },

      responseError(resp) {
        $injector.invoke(['$http', '$auth', function($http, $auth) {
          if (resp && resp.config && resp.config.url && resp.config.url.match($auth.apiUrl())) {
            return updateHeadersFromResponse($auth, resp);
          }
        }
        ]);

        return $injector.get('$q').reject(resp);
      }
    })
    ]);

    // define http methods that may need to carry auth headers
    const httpMethods = ['get', 'post', 'put', 'patch', 'delete'];

    // disable IE ajax request caching for each of the necessary http methods
    return angular.forEach(httpMethods, function(method) {
      if ($httpProvider.defaults.headers[method] == null) { $httpProvider.defaults.headers[method] = {}; }
      return $httpProvider.defaults.headers[method]['If-Modified-Since'] = 'Mon, 26 Jul 1997 05:00:00 GMT';
    });
  }
  ])

  .run(['$auth', '$window', '$rootScope', ($auth, $window, $rootScope) => $auth.initialize()
  ]);

// ie8 and ie9 require special handling
window.isOldIE = function() {
  let out = false;
  const nav = navigator.userAgent.toLowerCase();
  if (nav && (nav.indexOf('msie') !== -1)) {
    const version = parseInt(nav.split('msie')[1]);
    if (version < 10) {
      out = true;
    }
  }

  return out;
};

// ie <= 11 do not support postMessage
window.isIE = function() {
  const nav = navigator.userAgent.toLowerCase();
  return (nav && (nav.indexOf('msie') !== -1)) || !!navigator.userAgent.match(/Trident.*rv\:11\./);
};

window.isEmpty = function(obj) {
  // null and undefined are "empty"
  if (!obj) { return true; }

  // Assume if it has a length property with a non-zero value
  // that that property is correct.
  if (obj.length > 0) { return false; }
  if (obj.length === 0) { return true; }

  // Otherwise, does it have any properties of its own?
  // Note that this doesn't handle
  // toString and valueOf enumeration bugs in IE < 9
  for (let key in obj) {
    const val = obj[key];
    if (Object.prototype.hasOwnProperty.call(obj, key)) { return false; }
  }

  return true;
};
