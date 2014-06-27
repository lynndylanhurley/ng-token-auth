angular.module('ng-token-auth', ['ngCookies']).provider('$auth', function() {
  var config;
  config = {
    apiUrl: '/api',
    signOutUrl: '/auth/sign_out',
    emailSignInUrl: '/auth/sign_in',
    tokenValidationPath: '/auth/validate_token',
    useIEProxy: false,
    authProviders: {
      github: {
        path: '/auth/github'
      },
      facebook: {
        path: '/auth/facebook'
      },
      google: {
        path: '/auth/google'
      }
    }
  };
  return {
    configure: function(params) {
      return angular.extend(config, params);
    },
    $get: [
      '$http', '$q', '$location', '$cookies', '$cookieStore', '$window', '$timeout', '$rootScope', (function(_this) {
        return function($http, $q, $location, $cookies, $cookieStore, $window, $timeout, $rootScope) {
          return {
            token: null,
            email: null,
            dfd: null,
            user: {},
            authenticate: function(provider) {
              var authWindow;
              if (this.dfd == null) {
                this.dfd = $q.defer();
                authWindow = this.openAuthWindow(provider);
                this.requestCredentials(authWindow);
              }
              return this.dfd;
            },
            openAuthWindow: function(provider) {
              return $window.open(config.apiUrl + config.authProviders[provider].path);
            },
            requestCredentials: function(authWindow) {
              if (authWindow.closed) {
                return this.rejectDfd({
                  reason: 'unauthorized',
                  errors: ['User canceled login']
                });
              } else {
                authWindow.postMessage("requestCredentials", "*");
                return this.t = $timeout(((function(_this) {
                  return function() {
                    return _this.requestCredentials(authWindow);
                  };
                })(this)), 500);
              }
            },
            rejectDfd: function(reason) {
              if (this.dfd != null) {
                this.dfd.reject(reason);
                return $timeout(((function(_this) {
                  return function() {
                    return _this.dfd = null;
                  };
                })(this)));
              }
            },
            resolveDfd: function() {
              this.dfd.resolve({
                id: this.user.id
              });
              return $timeout(((function(_this) {
                return function() {
                  return _this.dfd = null;
                };
              })(this)), 0);
            },
            validateUser: function() {
              if (this.dfd == null) {
                this.dfd = $q.defer();
                if (!(this.token && this.email && this.user.id)) {
                  if ($location.search().token !== void 0) {
                    this.token = $location.search().token;
                    this.email = $location.search().email;
                  } else if ($cookieStore.get('auth_token')) {
                    this.token = $cookieStore.get('auth_token');
                    this.email = $cookieStore.get('auth_email');
                  }
                  if (this.token && this.email) {
                    this.validateToken();
                  } else {
                    this.rejectDfd({
                      reason: 'unauthorized',
                      errors: ['No credentials']
                    });
                  }
                } else {
                  this.resolveDfd();
                }
              }
              return this.dfd.promise;
            },
            validateToken: function() {
              return $http.post(config.apiUrl + config.tokenValidationPath, {
                auth_token: this.token,
                email: this.email
              }).success((function(_this) {
                return function(resp) {
                  console.log('validate token resp', resp);
                  return _this.handleValidAuth(resp.data);
                };
              })(this)).error((function(_this) {
                return function(data) {
                  _this.invalidateTokens();
                  _this.dfd.reject({
                    reason: 'unauthorized',
                    errors: ['Invalid/expired credentials']
                  });
                  return $timeout((function() {
                    return _this.dfd = null;
                  }), 0);
                };
              })(this));
            },
            invalidateTokens: function() {
              var key, val, _ref;
              _ref = this.user;
              for (key in _ref) {
                val = _ref[key];
                delete this.user[key];
              }
              this.token = null;
              this.email = null;
              delete $cookies['auth_token'];
              return delete $cookies['auth_email'];
            },
            persistTokens: function(u) {
              this.token = u.auth_token;
              this.email = u.email;
              $cookieStore.put('auth_token', this.token);
              $cookieStore.put('auth_email', this.email);
              return $http.defaults.headers.common['Authorization'] = this.buildAuthHeader();
            },
            buildAuthHeader: function() {
              return "token=" + this.token + " email=" + this.email;
            },
            signOut: function() {
              return $http.post(config.apiUrl + config.signOutUrl, {
                email: this.email,
                token: this.auth_token
              }).success((function(_this) {
                return function(resp) {
                  return _this.invalidateTokens();
                };
              })(this)).error((function(_this) {
                return function(resp) {
                  return _this.invalidateTokens();
                };
              })(this));
            },
            handleValidAuth: function(user) {
              _.extend(this.user, user);
              this.persistTokens(this.user);
              return this.resolveDfd();
            },
            cancelAuth: function() {
              $timeout.cancel(this.t);
              this.invalidateTokens();
              return this.rejectDfd();
            },
            apiUrl: function() {
              if (this._apiUrl == null) {
                if (config.useIEProxy && navigator.sayswho.match(/IE/)) {
                  this._apiUrl = '/proxy';
                } else {
                  this._apiUrl = config.apiUrl;
                }
              }
              return this._apiUrl;
            }
          };
        };
      })(this)
    ]
  };
}).run(function($auth, $timeout, $window, $rootScope) {
  $window.addEventListener("message", (function(_this) {
    return function(ev) {
      console.log('received message', ev);
      if (ev.data.message === 'deliverCredentials') {
        ev.source.close();
        $auth.handleValidAuth(_.omit(ev.data, 'message'));
        $rootScope.$digest();
      }
      if (ev.data.message === 'authFailure') {
        ev.source.close();
        return $auth.cancelAuth();
      }
    };
  })(this));
  $rootScope.user = $auth.user;
  $rootScope.githubLogin = function() {
    return $auth.authenticate('github');
  };
  $rootScope.facebookLogin = function() {
    return $auth.authenticate('facebook');
  };
  $rootScope.googleLogin = function() {
    return $auth.authenticate('google');
  };
  $rootScope.signOut = function() {
    return $auth.signOut();
  };
  return $auth.validateUser();
});
