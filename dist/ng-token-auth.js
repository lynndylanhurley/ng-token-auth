var __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

if (typeof module !== 'undefined' && typeof exports !== 'undefined' && module.exports === exports) {
  module.exports = 'ng-token-auth';
}

angular.module('ng-token-auth', ['ipCookie']).provider('$auth', function() {
  var configs, defaultConfigName;
  configs = {
    "default": {
      apiUrl: '/api',
      signOutUrl: '/auth/sign_out',
      emailSignInPath: '/auth/sign_in',
      emailRegistrationPath: '/auth',
      accountUpdatePath: '/auth',
      accountDeletePath: '/auth',
      confirmationSuccessUrl: function() {
        return window.location.href;
      },
      passwordResetPath: '/auth/password',
      passwordUpdatePath: '/auth/password',
      passwordResetSuccessUrl: function() {
        return window.location.href;
      },
      tokenValidationPath: '/auth/validate_token',
      proxyIf: function() {
        return false;
      },
      ifModifiedSince: true,
      proxyUrl: '/proxy',
      validateOnPageLoad: true,
      omniauthWindowType: 'sameWindow',
      storage: 'cookies',
      forceValidateToken: false,
      tokenFormat: {
        "access-token": "{{ token }}",
        "token-type": "Bearer",
        client: "{{ clientId }}",
        expiry: "{{ expiry }}",
        uid: "{{ uid }}"
      },
      cookieOps: {
        path: "/",
        expires: 9999,
        expirationUnit: 'days',
        secure: false
      },
      createPopup: function(url) {
        return window.open(url, '_blank', 'closebuttoncaption=Cancel');
      },
      parseExpiry: function(headers) {
        return (parseInt(headers['expiry'], 10) * 1000) || null;
      },
      handleLoginResponse: function(resp) {
        return resp.data;
      },
      handleAccountUpdateResponse: function(resp) {
        return resp.data;
      },
      handleTokenValidationResponse: function(resp) {
        return resp.data;
      },
      authProviderPaths: {
        github: '/auth/github',
        facebook: '/auth/facebook',
        google: '/auth/google_oauth2'
      }
    }
  };
  defaultConfigName = "default";
  return {
    configure: function(params) {
      var conf, defaults, fullConfig, i, k, label, v, _i, _len;
      if (params instanceof Array && params.length) {
        for (i = _i = 0, _len = params.length; _i < _len; i = ++_i) {
          conf = params[i];
          label = null;
          for (k in conf) {
            v = conf[k];
            label = k;
            if (i === 0) {
              defaultConfigName = label;
            }
          }
          defaults = angular.copy(configs["default"]);
          fullConfig = {};
          fullConfig[label] = angular.extend(defaults, conf[label]);
          angular.extend(configs, fullConfig);
        }
        if (defaultConfigName !== "default") {
          delete configs["default"];
        }
      } else if (params instanceof Object) {
        angular.extend(configs["default"], params);
      } else {
        throw "Invalid argument: ng-token-auth config should be an Array or Object.";
      }
      return configs;
    },
    $get: [
      '$http', '$q', '$location', 'ipCookie', '$window', '$timeout', '$rootScope', '$interpolate', '$interval', (function(_this) {
        return function($http, $q, $location, ipCookie, $window, $timeout, $rootScope, $interpolate, $interval) {
          return {
            header: null,
            dfd: null,
            user: {},
            mustResetPassword: false,
            listener: null,
            initialize: function() {
              this.initializeListeners();
              this.cancelOmniauthInAppBrowserListeners = (function() {});
              return this.addScopeMethods();
            },
            initializeListeners: function() {
              this.listener = angular.bind(this, this.handlePostMessage);
              if ($window.addEventListener) {
                return $window.addEventListener("message", this.listener, false);
              }
            },
            cancel: function(reason) {
              if (this.requestCredentialsPollingTimer != null) {
                $timeout.cancel(this.requestCredentialsPollingTimer);
              }
              this.cancelOmniauthInAppBrowserListeners();
              if (this.dfd != null) {
                this.rejectDfd(reason);
              }
              return $timeout(((function(_this) {
                return function() {
                  return _this.requestCredentialsPollingTimer = null;
                };
              })(this)), 0);
            },
            destroy: function() {
              this.cancel();
              if ($window.removeEventListener) {
                return $window.removeEventListener("message", this.listener, false);
              }
            },
            handlePostMessage: function(ev) {
              var error, oauthRegistration;
              if (ev.data.message === 'deliverCredentials') {
                delete ev.data.message;
                oauthRegistration = ev.data.oauth_registration;
                delete ev.data.oauth_registration;
                this.handleValidAuth(ev.data, true);
                $rootScope.$broadcast('auth:login-success', ev.data);
                if (oauthRegistration) {
                  $rootScope.$broadcast('auth:oauth-registration', ev.data);
                }
              }
              if (ev.data.message === 'authFailure') {
                error = {
                  reason: 'unauthorized',
                  errors: [ev.data.error]
                };
                this.cancel(error);
                return $rootScope.$broadcast('auth:login-error', error);
              }
            },
            addScopeMethods: function() {
              $rootScope.user = this.user;
              $rootScope.authenticate = angular.bind(this, this.authenticate);
              $rootScope.signOut = angular.bind(this, this.signOut);
              $rootScope.destroyAccount = angular.bind(this, this.destroyAccount);
              $rootScope.submitRegistration = angular.bind(this, this.submitRegistration);
              $rootScope.submitLogin = angular.bind(this, this.submitLogin);
              $rootScope.requestPasswordReset = angular.bind(this, this.requestPasswordReset);
              $rootScope.updatePassword = angular.bind(this, this.updatePassword);
              $rootScope.updateAccount = angular.bind(this, this.updateAccount);
              if (this.getConfig().validateOnPageLoad) {
                return this.validateUser({
                  config: this.getSavedConfig()
                });
              }
            },
            submitRegistration: function(params, opts) {
              var successUrl;
              if (opts == null) {
                opts = {};
              }
              successUrl = this.getResultOrValue(this.getConfig(opts.config).confirmationSuccessUrl);
              angular.extend(params, {
                confirm_success_url: successUrl,
                config_name: this.getCurrentConfigName(opts.config)
              });
              return $http.post(this.apiUrl(opts.config) + this.getConfig(opts.config).emailRegistrationPath, params).then(function(resp) {
                $rootScope.$broadcast('auth:registration-email-success', params);
                return resp;
              }, function(resp) {
                $rootScope.$broadcast('auth:registration-email-error', resp.data);
                return $q.reject(resp);
              });
            },
            submitLogin: function(params, opts, httpopts) {
              if (opts == null) {
                opts = {};
              }
              if (httpopts == null) {
                httpopts = {};
              }
              this.initDfd();
              $http.post(this.apiUrl(opts.config) + this.getConfig(opts.config).emailSignInPath, params, httpopts).then((function(_this) {
                return function(resp) {
                  var authData;
                  _this.setConfigName(opts.config);
                  authData = _this.getConfig(opts.config).handleLoginResponse(resp.data, _this);
                  _this.handleValidAuth(authData);
                  $rootScope.$broadcast('auth:login-success', _this.user);
                  return resp;
                };
              })(this), (function(_this) {
                return function(resp) {
                  _this.rejectDfd({
                    reason: 'unauthorized',
                    errors: ['Invalid credentials']
                  });
                  $rootScope.$broadcast('auth:login-error', resp.data);
                  return $q.reject(resp);
                };
              })(this));
              return this.dfd.promise;
            },
            userIsAuthenticated: function() {
              return this.retrieveData('auth_headers') && this.user.signedIn && !this.tokenHasExpired();
            },
            requestPasswordReset: function(params, opts) {
              var successUrl;
              if (opts == null) {
                opts = {};
              }
              successUrl = this.getResultOrValue(this.getConfig(opts.config).passwordResetSuccessUrl);
              params.redirect_url = successUrl;
              if (opts.config != null) {
                params.config_name = opts.config;
              }
              return $http.post(this.apiUrl(opts.config) + this.getConfig(opts.config).passwordResetPath, params).then(function(resp) {
                $rootScope.$broadcast('auth:password-reset-request-success', params);
                return resp;
              }, function(resp) {
                $rootScope.$broadcast('auth:password-reset-request-error', resp.data);
                return $q.reject(resp);
              });
            },
            updatePassword: function(params) {
              return $http.put(this.apiUrl() + this.getConfig().passwordUpdatePath, params).then((function(_this) {
                return function(resp) {
                  $rootScope.$broadcast('auth:password-change-success', resp.data);
                  _this.mustResetPassword = false;
                  return resp;
                };
              })(this), function(resp) {
                $rootScope.$broadcast('auth:password-change-error', resp.data);
                return $q.reject(resp);
              });
            },
            updateAccount: function(params) {
              return $http.put(this.apiUrl() + this.getConfig().accountUpdatePath, params).then((function(_this) {
                return function(resp) {
                  var curHeaders, key, newHeaders, updateResponse, val, _ref;
                  updateResponse = _this.getConfig().handleAccountUpdateResponse(resp.data);
                  curHeaders = _this.retrieveData('auth_headers');
                  angular.extend(_this.user, updateResponse);
                  if (curHeaders) {
                    newHeaders = {};
                    _ref = _this.getConfig().tokenFormat;
                    for (key in _ref) {
                      val = _ref[key];
                      if (curHeaders[key] && updateResponse[key]) {
                        newHeaders[key] = updateResponse[key];
                      }
                    }
                    _this.setAuthHeaders(newHeaders);
                  }
                  $rootScope.$broadcast('auth:account-update-success', resp.data);
                  return resp;
                };
              })(this), function(resp) {
                $rootScope.$broadcast('auth:account-update-error', resp.data);
                return $q.reject(resp);
              });
            },
            destroyAccount: function(params) {
              return $http["delete"](this.apiUrl() + this.getConfig().accountUpdatePath, params).then((function(_this) {
                return function(resp) {
                  _this.invalidateTokens();
                  $rootScope.$broadcast('auth:account-destroy-success', resp.data);
                  return resp;
                };
              })(this), function(resp) {
                $rootScope.$broadcast('auth:account-destroy-error', resp.data);
                return $q.reject(resp);
              });
            },
            authenticate: function(provider, opts) {
              if (opts == null) {
                opts = {};
              }
              if (this.dfd == null) {
                this.setConfigName(opts.config);
                this.initDfd();
                this.openAuthWindow(provider, opts);
              }
              return this.dfd.promise;
            },
            setConfigName: function(configName) {
              if (configName == null) {
                configName = defaultConfigName;
              }
              return this.persistData('currentConfigName', configName, configName);
            },
            openAuthWindow: function(provider, opts) {
              var authUrl, omniauthWindowType;
              omniauthWindowType = this.getConfig(opts.config).omniauthWindowType;
              authUrl = this.buildAuthUrl(omniauthWindowType, provider, opts);
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
            visitUrl: function(url) {
              return $window.location.replace(url);
            },
            buildAuthUrl: function(omniauthWindowType, provider, opts) {
              var authUrl, key, params, val;
              if (opts == null) {
                opts = {};
              }
              authUrl = this.getConfig(opts.config).apiUrl;
              authUrl += this.getConfig(opts.config).authProviderPaths[provider];
              authUrl += '?auth_origin_url=' + encodeURIComponent($window.location.href);
              params = angular.extend({}, opts.params || {}, {
                omniauth_window_type: omniauthWindowType
              });
              for (key in params) {
                val = params[key];
                authUrl += '&';
                authUrl += encodeURIComponent(key);
                authUrl += '=';
                authUrl += encodeURIComponent(val);
              }
              return authUrl;
            },
            requestCredentialsViaPostMessage: function(authWindow) {
              if (authWindow.closed) {
                return this.handleAuthWindowClose(authWindow);
              } else {
                authWindow.postMessage("requestCredentials", "*");
                return this.requestCredentialsPollingTimer = $timeout(((function(_this) {
                  return function() {
                    return _this.requestCredentialsViaPostMessage(authWindow);
                  };
                })(this)), 500);
              }
            },
            requestCredentialsViaExecuteScript: function(authWindow) {
              var handleAuthWindowClose, handleLoadStop;
              this.cancelOmniauthInAppBrowserListeners();
              handleAuthWindowClose = this.handleAuthWindowClose.bind(this, authWindow);
              handleLoadStop = this.handleLoadStop.bind(this, authWindow);
              authWindow.addEventListener('loadstop', handleLoadStop);
              authWindow.addEventListener('exit', handleAuthWindowClose);
              return this.cancelOmniauthInAppBrowserListeners = function() {
                authWindow.removeEventListener('loadstop', handleLoadStop);
                return authWindow.removeEventListener('exit', handleAuthWindowClose);
              };
            },
            handleLoadStop: function(authWindow) {
              _this = this;
              return authWindow.executeScript({
                code: 'requestCredentials()'
              }, function(response) {
                var data, ev;
                data = response[0];
                if (data) {
                  ev = new Event('message');
                  ev.data = data;
                  _this.cancelOmniauthInAppBrowserListeners();
                  $window.dispatchEvent(ev);
                  _this.initDfd();
                  return authWindow.close();
                }
              });
            },
            handleAuthWindowClose: function(authWindow) {
              this.cancel({
                reason: 'unauthorized',
                errors: ['User canceled login']
              });
              this.cancelOmniauthInAppBrowserListeners;
              return $rootScope.$broadcast('auth:window-closed');
            },
            resolveDfd: function() {
              if (!this.dfd) {
                return;
              }
              this.dfd.resolve(this.user);
              return $timeout(((function(_this) {
                return function() {
                  _this.dfd = null;
                  if (!$rootScope.$$phase) {
                    return $rootScope.$digest();
                  }
                };
              })(this)), 0);
            },
            buildQueryString: function(param, prefix) {
              var encoded, k, str, v;
              str = [];
              for (k in param) {
                v = param[k];
                k = prefix ? prefix + "[" + k + "]" : k;
                encoded = angular.isObject(v) ? this.buildQueryString(v, k) : k + "=" + encodeURIComponent(v);
                str.push(encoded);
              }
              return str.join("&");
            },
            parseLocation: function(location) {
              var i, locationSubstring, obj, pair, pairs;
              locationSubstring = location.substring(1);
              obj = {};
              if (locationSubstring) {
                pairs = locationSubstring.split('&');
                pair = void 0;
                i = void 0;
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
            validateUser: function(opts) {
              var clientId, configName, expiry, location_parse, params, search, token, uid, url;
              if (opts == null) {
                opts = {};
              }
              configName = opts.config;
              if (this.dfd == null) {
                this.initDfd();
                if (this.userIsAuthenticated()) {
                  this.resolveDfd();
                } else {
                  search = $location.search();
                  location_parse = this.parseLocation(window.location.search);
                  params = Object.keys(search).length === 0 ? location_parse : search;
                  token = params.auth_token || params.token;
                  if (token !== void 0) {
                    clientId = params.client_id;
                    uid = params.uid;
                    expiry = params.expiry;
                    configName = params.config;
                    this.setConfigName(configName);
                    this.mustResetPassword = params.reset_password;
                    this.firstTimeLogin = params.account_confirmation_success;
                    this.oauthRegistration = params.oauth_registration;
                    this.setAuthHeaders(this.buildAuthHeaders({
                      token: token,
                      clientId: clientId,
                      uid: uid,
                      expiry: expiry
                    }));
                    url = $location.path() || '/';
                    ['auth_token', 'token', 'client_id', 'uid', 'expiry', 'config', 'reset_password', 'account_confirmation_success', 'oauth_registration'].forEach(function(prop) {
                      return delete params[prop];
                    });
                    if (Object.keys(params).length > 0) {
                      url += '?' + this.buildQueryString(params);
                    }
                    $location.url(url);
                  } else if (this.retrieveData('currentConfigName')) {
                    configName = this.retrieveData('currentConfigName');
                  }
                  if (this.getConfig().forceValidateToken) {
                    this.validateToken({
                      config: configName
                    });
                  } else if (!isEmpty(this.retrieveData('auth_headers'))) {
                    if (this.tokenHasExpired()) {
                      $rootScope.$broadcast('auth:session-expired');
                      this.rejectDfd({
                        reason: 'unauthorized',
                        errors: ['Session expired.']
                      });
                    } else {
                      this.validateToken({
                        config: configName
                      });
                    }
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
            validateToken: function(opts) {
              if (opts == null) {
                opts = {};
              }
              if (!this.tokenHasExpired()) {
                return $http.get(this.apiUrl(opts.config) + this.getConfig(opts.config).tokenValidationPath).then((function(_this) {
                  return function(resp) {
                    var authData;
                    authData = _this.getConfig(opts.config).handleTokenValidationResponse(resp.data);
                    _this.handleValidAuth(authData);
                    if (_this.firstTimeLogin) {
                      $rootScope.$broadcast('auth:email-confirmation-success', _this.user);
                    }
                    if (_this.oauthRegistration) {
                      $rootScope.$broadcast('auth:oauth-registration', _this.user);
                    }
                    if (_this.mustResetPassword) {
                      $rootScope.$broadcast('auth:password-reset-confirm-success', _this.user);
                    }
                    $rootScope.$broadcast('auth:validation-success', _this.user);
                    return _this.user;
                  };
                })(this), (function(_this) {
                  return function(resp) {
                    if (_this.firstTimeLogin) {
                      $rootScope.$broadcast('auth:email-confirmation-error', resp.data);
                    }
                    if (_this.mustResetPassword) {
                      $rootScope.$broadcast('auth:password-reset-confirm-error', resp.data);
                    }
                    $rootScope.$broadcast('auth:validation-error', resp.data);
                    _this.rejectDfd({
                      reason: 'unauthorized',
                      errors: resp.data != null ? resp.data.errors : ['Unspecified error']
                    }, resp.status > 0);
                    return $q.reject(resp);
                  };
                })(this));
              } else {
                return this.rejectDfd({
                  reason: 'unauthorized',
                  errors: ['Expired credentials']
                });
              }
            },
            tokenHasExpired: function() {
              var expiry, now;
              expiry = this.getExpiry();
              now = new Date().getTime();
              return expiry && expiry < now;
            },
            getExpiry: function() {
              return this.getConfig().parseExpiry(this.retrieveData('auth_headers') || {});
            },
            invalidateTokens: function() {
              var key, val, _ref;
              _ref = this.user;
              for (key in _ref) {
                val = _ref[key];
                delete this.user[key];
              }
              this.deleteData('currentConfigName');
              if (this.timer != null) {
                $interval.cancel(this.timer);
              }
              return this.deleteData('auth_headers');
            },
            signOut: function() {
              return $http["delete"](this.apiUrl() + this.getConfig().signOutUrl).then((function(_this) {
                return function(resp) {
                  _this.invalidateTokens();
                  $rootScope.$broadcast('auth:logout-success');
                  return resp;
                };
              })(this), (function(_this) {
                return function(resp) {
                  _this.invalidateTokens();
                  $rootScope.$broadcast('auth:logout-error', resp.data);
                  return $q.reject(resp);
                };
              })(this));
            },
            handleValidAuth: function(user, setHeader) {
              if (setHeader == null) {
                setHeader = false;
              }
              if (this.requestCredentialsPollingTimer != null) {
                $timeout.cancel(this.requestCredentialsPollingTimer);
              }
              this.cancelOmniauthInAppBrowserListeners();
              angular.extend(this.user, user);
              this.user.signedIn = true;
              this.user.configName = this.getCurrentConfigName();
              if (setHeader) {
                this.setAuthHeaders(this.buildAuthHeaders({
                  token: this.user.auth_token,
                  clientId: this.user.client_id,
                  uid: this.user.uid,
                  expiry: this.user.expiry
                }));
              }
              return this.resolveDfd();
            },
            buildAuthHeaders: function(ctx) {
              var headers, key, val, _ref;
              headers = {};
              _ref = this.getConfig().tokenFormat;
              for (key in _ref) {
                val = _ref[key];
                headers[key] = $interpolate(val)(ctx);
              }
              return headers;
            },
            persistData: function(key, val, configName) {
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
            retrieveData: function(key) {
              var e;
              try {
                if (this.getConfig().storage instanceof Object) {
                  return this.getConfig().storage.retrieveData(key);
                } else {
                  switch (this.getConfig().storage) {
                    case 'localStorage':
                      return JSON.parse($window.localStorage.getItem(key));
                    case 'sessionStorage':
                      return JSON.parse($window.sessionStorage.getItem(key));
                    default:
                      return ipCookie(key);
                  }
                }
              } catch (_error) {
                e = _error;
                if (e instanceof SyntaxError) {
                  return void 0;
                } else {
                  throw e;
                }
              }
            },
            deleteData: function(key) {
              var cookieOps;
              if (this.getConfig().storage instanceof Object) {
                this.getConfig().storage.deleteData(key);
              }
              switch (this.getConfig().storage) {
                case 'localStorage':
                  return $window.localStorage.removeItem(key);
                case 'sessionStorage':
                  return $window.sessionStorage.removeItem(key);
                default:
                  cookieOps = {
                    path: this.getConfig().cookieOps.path
                  };
                  if (this.getConfig().cookieOps.domain !== void 0) {
                    cookieOps.domain = this.getConfig().cookieOps.domain;
                  }
                  return ipCookie.remove(key, cookieOps);
              }
            },
            setAuthHeaders: function(h) {
              var expiry, newHeaders, now, result;
              newHeaders = angular.extend(this.retrieveData('auth_headers') || {}, h);
              result = this.persistData('auth_headers', newHeaders);
              expiry = this.getExpiry();
              now = new Date().getTime();
              if (expiry > now) {
                if (this.timer != null) {
                  $interval.cancel(this.timer);
                }
                this.timer = $interval(((function(_this) {
                  return function() {
                    return _this.validateUser({
                      config: _this.getSavedConfig()
                    });
                  };
                })(this)), parseInt(expiry - now), 1);
              }
              return result;
            },
            initDfd: function() {
              return this.dfd = $q.defer();
            },
            rejectDfd: function(reason, invalidateTokens) {
              if (invalidateTokens == null) {
                invalidateTokens = true;
              }
              if (invalidateTokens === true) {
                this.invalidateTokens();
              }
              if (this.dfd != null) {
                this.dfd.reject(reason);
                return $timeout(((function(_this) {
                  return function() {
                    return _this.dfd = null;
                  };
                })(this)), 0);
              }
            },
            apiUrl: function(configName) {
              if (this.getConfig(configName).proxyIf()) {
                return this.getConfig(configName).proxyUrl;
              } else {
                return this.getConfig(configName).apiUrl;
              }
            },
            getConfig: function(name) {
              return configs[this.getCurrentConfigName(name)];
            },
            getResultOrValue: function(arg) {
              if (typeof arg === 'function') {
                return arg();
              } else {
                return arg;
              }
            },
            getCurrentConfigName: function(name) {
              return name || this.getSavedConfig();
            },
            getSavedConfig: function() {
              var c, key;
              c = void 0;
              key = 'currentConfigName';
              if (this.hasLocalStorage()) {
                if (c == null) {
                  c = JSON.parse($window.localStorage.getItem(key));
                }
              } else if (this.hasSessionStorage()) {
                if (c == null) {
                  c = JSON.parse($window.sessionStorage.getItem(key));
                }
              }
              if (c == null) {
                c = ipCookie(key);
              }
              return c || defaultConfigName;
            },
            hasSessionStorage: function() {
              var error;
              if (this._hasSessionStorage == null) {
                this._hasSessionStorage = false;
                try {
                  $window.sessionStorage.setItem('ng-token-auth-test', 'ng-token-auth-test');
                  $window.sessionStorage.removeItem('ng-token-auth-test');
                  this._hasSessionStorage = true;
                } catch (_error) {
                  error = _error;
                }
              }
              return this._hasSessionStorage;
            },
            hasLocalStorage: function() {
              var error;
              if (this._hasLocalStorage == null) {
                this._hasLocalStorage = false;
                try {
                  $window.localStorage.setItem('ng-token-auth-test', 'ng-token-auth-test');
                  $window.localStorage.removeItem('ng-token-auth-test');
                  this._hasLocalStorage = true;
                } catch (_error) {
                  error = _error;
                }
              }
              return this._hasLocalStorage;
            }
          };
        };
      })(this)
    ]
  };
}).config([
  '$httpProvider', function($httpProvider) {
    var addIfModifiedSince, httpMethods, tokenIsCurrent, updateHeadersFromResponse;
    tokenIsCurrent = function($auth, headers) {
      var newTokenExpiry, oldTokenExpiry;
      oldTokenExpiry = Number($auth.getExpiry());
      newTokenExpiry = Number($auth.getConfig().parseExpiry(headers || {}));
      return newTokenExpiry >= oldTokenExpiry;
    };
    updateHeadersFromResponse = function($auth, resp) {
      var key, newHeaders, val, _ref;
      newHeaders = {};
      _ref = $auth.getConfig().tokenFormat;
      for (key in _ref) {
        val = _ref[key];
        if (resp.headers(key)) {
          newHeaders[key] = resp.headers(key);
        }
      }
      if (tokenIsCurrent($auth, newHeaders)) {
        return $auth.setAuthHeaders(newHeaders);
      }
    };
    httpMethods = ['get', 'post', 'put', 'patch', 'delete'];
    addIfModifiedSince = function($auth, req) {
      var _ref;
      if (_ref = req.method.toLowerCase(), __indexOf.call(httpMethods, _ref) < 0) {
        return req;
      }
      if ($auth.getConfig().ifModifiedSince) {
        req.headers['If-Modified-Since'] = 'Mon, 26 Jul 1997 05:00:00 GMT';
      }
      return req;
    };
    return $httpProvider.interceptors.push([
      '$injector', function($injector) {
        return {
          request: function(req) {
            $injector.invoke([
              '$http', '$auth', function($http, $auth) {
                var key, val, _ref;
                if (req.url.match($auth.apiUrl())) {
                  _ref = $auth.retrieveData('auth_headers');
                  for (key in _ref) {
                    val = _ref[key];
                    req.headers[key] = val;
                  }
                }
                return req = addIfModifiedSince($auth, req);
              }
            ]);
            return req;
          },
          response: function(resp) {
            $injector.invoke([
              '$http', '$auth', function($http, $auth) {
                if (resp.config.url.match($auth.apiUrl())) {
                  return updateHeadersFromResponse($auth, resp);
                }
              }
            ]);
            return resp;
          },
          responseError: function(resp) {
            $injector.invoke([
              '$http', '$auth', function($http, $auth) {
                if (resp.config.url.match($auth.apiUrl())) {
                  return updateHeadersFromResponse($auth, resp);
                }
              }
            ]);
            return $injector.get('$q').reject(resp);
          }
        };
      }
    ]);
  }
]).run([
  '$auth', '$window', '$rootScope', function($auth, $window, $rootScope) {
    return $auth.initialize();
  }
]);

window.isOldIE = function() {
  var nav, out, version;
  out = false;
  nav = navigator.userAgent.toLowerCase();
  if (nav && nav.indexOf('msie') !== -1) {
    version = parseInt(nav.split('msie')[1]);
    if (version < 10) {
      out = true;
    }
  }
  return out;
};

window.isIE = function() {
  var nav;
  nav = navigator.userAgent.toLowerCase();
  return (nav && nav.indexOf('msie') !== -1) || !!navigator.userAgent.match(/Trident.*rv\:11\./);
};

window.isEmpty = function(obj) {
  var key, val;
  if (!obj) {
    return true;
  }
  if (obj.length > 0) {
    return false;
  }
  if (obj.length === 0) {
    return true;
  }
  for (key in obj) {
    val = obj[key];
    if (Object.prototype.hasOwnProperty.call(obj, key)) {
      return false;
    }
  }
  return true;
};
