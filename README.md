# Simple, secure authentication for AngularJS.

 ![Serious Trust](https://raw.githubusercontent.com/lynndylanhurley/ng-token-auth/master/test/app/images/serious-trust.jpg "Serious Trust")

[![Bower version](https://badge.fury.io/bo/ng-token-auth.svg)](http://badge.fury.io/bo/ng-token-auth)
[![Build Status](https://travis-ci.org/lynndylanhurley/ng-token-auth.svg?branch=master)](https://travis-ci.org/lynndylanhurley/ng-token-auth)
[![Test Coverage](https://codeclimate.com/github/lynndylanhurley/ng-token-auth/coverage.png)](https://codeclimate.com/github/lynndylanhurley/ng-token-auth)

This module provides the following features:

* Oauth2 authentication
* Email authentication, including:
  * [User registration](#authsubmitregistration)
  * [Password reset](#authrequestpasswordreset)
  * [Account updates](#authupdateaccount)
  * [Account deletion](#authdestroyaccount)
* Seamless integration with the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) Rails gem
* Extensive [event notifications](#events)
* Allows for extensive [configuration](#configuration) to work with any API
* Session support using cookies or localStorage
* Tested with Chrome, Safari, Firefox and [IE8+](#internet-explorer)

# [Live Demo](http://ng-token-auth-demo.herokuapp.com/)

This project comes bundled with a test app. You can run the demo locally by following [these instructions](#development), or you can use it [here in production](http://ng-token-auth-demo.herokuapp.com/).


# Table of Contents

* [About this module](#about-this-module)
* [Installation](#installation)
* [Configuration](#configuration)
* [API](#api)
  * [`$auth.authenticate`](#authauthenticate)
  * [`$auth.validateUser`](#authvalidateuser)
  * [`$auth.submitRegistration`](#authsubmitregistration)
  * [`$auth.submitLogin`](#authsubmitlogin)
  * [`$auth.signOut`](#authsignout)
  * [`$auth.requestPasswordReset`](#authrequestpasswordreset)
  * [`$auth.updatePassword`](#authupdatepassword)
  * [`$auth.updateAccount`](#authupdateaccount)
  * [`$auth.destroyAccount`](#authdestroyaccount)
* [Events](#events)
  * [`auth:login-success`](#authlogin-success)
  * [`auth:login-error`](#authlogin-error)
  * [`auth:invalid`](#authinvalid)
  * [`auth:validation-success`](#authvalidation-success)
  * [`auth:validation-error`](#authvalidation-error)
  * [`auth:logout-success`](#authlogout-success)
  * [`auth:logout-error`](#authlogout-error)
  * [`auth:oauth-registration`](#authoauth-registration)
  * [`auth:registration-email-success`](#authregistration-email-success)
  * [`auth:registration-email-error`](#authregistration-email-error)
  * [`auth:email-confirmation-success`](#authemail-confirmation-success)
  * [`auth:email-confirmation-error`](#authemail-confirmation-error)
  * [`auth:password-reset-request-success`](#authpassword-reset-request-success)
  * [`auth:password-reset-request-error`](#authpassword-reset-request-error)
  * [`auth:password-reset-confirm-success`](#authpassword-reset-confirm-success)
  * [`auth:password-reset-confirm-error`](#authpassword-reset-confirm-error)
  * [`auth:password-change-success`](#authpassword-change-success)
  * [`auth:password-change-error`](#authpassword-change-error)
  * [`auth:account-update-success`](#authaccount-update-success)
  * [`auth:account-update-error`](#authaccount-update-error)
  * [`auth:account-destroy-success`](#authaccount-destroy-success)
  * [`auth:account-destroy-error`](#authaccount-destroy-error)
  * [`auth:session-expired`](#authsession-expired)
* [Using alternate response formats](#using-alternate-response-formats)
* [Multiple user types](#using-multiple-user-types)
* [File uploads](#file-uploads)
* [Conceptual Diagrams](#conceptual)
  * [OAuth2 Authentication](#oauth2-authentication-flow)
  * [Token Validation](#token-validation-flow)
  * [Email Registration](#email-registration-flow)
  * [Email Sign In](#email-sign-in-flow)
  * [Password Reset Request](#password-reset-flow)
* [Notes on Token Management](#about-token-management)
* [Notes on Batch Requests](#about-batch-requests)
* [Notes on Token Formatting](#identifying-users-on-the-server)
* [Internet Explorer Caveats](#internet-explorer)
* [FAQ](#faq)
* [Development](#development)
* [Contribution Guidelines](#contributing)
* [Alteratives to This Module](#alternatives)
* [Callouts](#callouts)

# About this module

This module relies on [token based authentication](http://stackoverflow.com/questions/1592534/what-is-token-based-authentication). This requires coordination between the client and the server. [Diagrams](#conceptual) are included to illustrate this relationship.

This module was designed to work out of the box with the outstanding [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem, but it's seen use in other environments as well ([go](http://golang.org/), [gorm](https://github.com/jinzhu/gorm) and [gomniauth](https://github.com/stretchr/gomniauth) for example).

Not using AngularJS? Use [jToker](https://github.com/lynndylanhurley/j-toker) instead!

**About security**: [read here](http://stackoverflow.com/questions/18605294/is-devises-token-authenticatable-secure) for more information on securing your token auth system. The [devise token auth](https://github.com/lynndylanhurley/devise_token_auth#security) gem has adequate security measures in place, and the gem works seamlessly with this module.




# Installation


* Download this module and its dependencies: 
  ~~~bash
  # from the terminal at the root of your project
  bower install ng-token-auth --save
  ~~~

* Ensure that [angularjs](https://github.com/angular/angular.js), [angular-cookie](https://github.com/ivpusic/angular-cookie), and ng-token-auth are included on your page: 
  ~~~html
  <!-- in your index.html file -->
  <script src="/js/angular/angular.js"></script>
  <script src="/js/angular-cookie/angular-cookie.js"></script>
  <script src="/js/ng-token-auth/dist/ng-token-auth.js"></script>
  ~~~

* Include `ng-token-auth` in your module's dependencies:
  ~~~javascript
  // in your js app's module definition
  angular.module('myApp', ['ng-token-auth'])
  ~~~

## Configuration

The `$authProvider` is available for injection during the app's configuration phase. Use `$authProvider.configure` to configure the module for use with your server.

The following settings correspond to the paths that are available when using the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth#usage) gem for Rails. If you're using this gem, you will only need to set the `apiUrl` option.

##### Example configuration when using devise token auth
~~~javascript
angular.module('myApp', ['ng-token-auth'])
	.config(function($authProvider) {
		$authProvider.configure({
			apiUrl: 'http://api.example.com'
		});
	});
~~~

##### Complete config example
~~~javascript
angular.module('myApp', ['ng-token-auth'])

  .config(function($authProvider) {

    // the following shows the default values. values passed to this method
    // will extend the defaults using angular.extend

    $authProvider.configure({
      apiUrl:                  '/api',
      tokenValidationPath:     '/auth/validate_token',
      signOutUrl:              '/auth/sign_out',
      emailRegistrationPath:   '/auth',
      accountUpdatePath:       '/auth',
      accountDeletePath:       '/auth',
      confirmationSuccessUrl:  window.location.href,
      passwordResetPath:       '/auth/password',
      passwordUpdatePath:      '/auth/password',
      passwordResetSuccessUrl: window.location.href,
      emailSignInPath:         '/auth/sign_in',
      storage:                 'cookies',
      proxyIf:                 function() { return false; },
      proxyUrl:                '/proxy',
      omniauthWindowType:      'sameWindow',
      authProviderPaths: {
        github:   '/auth/github',
        facebook: '/auth/facebook',
        google:   '/auth/google'
      },
      tokenFormat: {
        "access-token": "{{ token }}",
        "token-type":   "Bearer",
        "client":       "{{ clientId }}",
        "expiry":       "{{ expiry }}",
        "uid":          "{{ uid }}"
      },
      parseExpiry: function(headers) {
        // convert from UTC ruby (seconds) to UTC js (milliseconds)
        return (parseInt(headers['expiry']) * 1000) || null;
      },
      handleLoginResponse: function(response) {
        return response.data;
      },
      handleAccountResponse: function(response) {
        return response.data;
      },
      handleTokenValidationResponse: function(response) {
        return response.data;
      }
    });
  });
~~~

##### Config options:
| param | description |
|---|---|
| **apiUrl** | the base route to your api. Each of the following paths will be relative to this URL. Authentication headers will only be added to requests with this value as the base URL. |
| **authProviderPaths** | an object containing paths to auth endpoints. keys are names of the providers, values are their auth paths relative to the `apiUrl`. [Read more](#oauth2-authentication-flow). |
| **tokenValidationPath** | relative path to validate authentication tokens. [Read more](#token-validation-flow). |
| **signOutUrl** | relative path to sign user out. this will destroy the user's token both server-side and client-side. |
| **emailRegistrationPath** | path for submitting new email registrations. [Read more](#email-registration-flow). |
| **accountUpdatePath** | path for submitting account update requests. [Read more](#authupdateaccount). |
| **accountDeletePath** | path for submitting account deletion requests. [Read more](#authdestroyaccount). |
| **confirmationSuccessUrl** | the url to which the API should redirect after users visit the link contained in email-registration emails. [Read more](#email-registration-flow). |
| **emailSignInPath** | path for signing in using email credentials. [Read more](#email-sign-in-flow) |
| **passwordResetPath** | path for requesting password reset emails. [Read more](#password-reset-flow). |
| **passwordUpdatePath** | path for submitting new passwords for authenticated users. [Read more](#password-reset-flow) |
| **passwordResetSuccessUrl** | the URL to which the API should redirect after users visit the links contained in password-reset emails. [Read more](#password-reset-flow). |
| **storage** | the method used to persist tokens between sessions. cookies are used by default, but `window.localStorage` can be used as well. A custom object can also be used. Allowed strings are `cookies` and `localStorage`, otherwise an object implementing the interface defined below|
| **proxyIf** | older browsers have trouble with CORS ([read more](#internet-explorer)). pass a method here to determine whether or not a proxy should be used. example: `function() { return !Modernizr.cors }` |
| **proxyUrl** | proxy url if proxy is to be used |
| **tokenFormat** | a template for authentication tokens. the template will be provided a context with the following params:<br><ul><li>token</li><li>clientId</li><li>uid</li><li>expiry</li></ul>Defaults to the [RFC 6750 Bearer Token](http://tools.ietf.org/html/rfc6750) format. [Read more](#using-alternate-header-formats). |
| **parseExpiry** | a function that will return the token's expiry from the current headers. Returns null if no headers or expiry are found. [Read more](#using-alternate-header-formats). |
| **handleLoginResponse** | a function that will identify and return the current user's info (id, username, etc.) in the response of a successful login request. [Read more](#using-alternate-response-formats). |
| **handleAccountUpdateResponse** | a function that will identify and return the current user's info (id, username, etc.) in the response of a successful account update request. [Read more](#using-alternate-response-formats). |
| **handleTokenValidationResponse** | a function that will identify and return the current user's info (id, username, etc.) in the response of a successful token validation request. [Read more](#using-alternate-response-formats). |
| **omniauthWindowType** | Dictates the methodolgy of the OAuth login flow. One of: `sameWindow` (default), `newWindow`, `inAppBrowser` [Read more](#oauth2-authentication-flow). |

#### Custom Storage Object
Must implement the following interface:
```javascript
{
  function persistData(key, val) {}
  function retrieveData(key) {}
  function deleteData(key) {}
}
```

# Usage

## API

The `$auth` module is available for dependency injection during your app's run phase (for controllers, directives, filters, etc.). Each API method returns a [$q deferred promise](https://docs.angularjs.org/api/ng/service/$q) that will be resolved on success,


###$auth.authenticate
Initiate an OAuth2 authentication. This method accepts 2 arguments:

* **provider**: a string that is also the name of the target provider service. For example, to authenticate using github: 
  ~~~javascript
  $auth.authenticate('github')
  ~~~

* **options**: _(optional)_ an object containing the following params:
  *  **params**: additional params to be passed to the OAuth provider. For example, to pass the user's favorite color on sign up:

     ~~~javascript
     $auth.authenticate('github', {params: {favorite_color: 'green'})
     ~~~

This method is also added to the `$rootScope` for use in templates. [Read more](#oauth2-authentication-flow).

This method emits the following events:

* [`auth:login-success`](#authlogin-success)
* [`auth:login-error`](#authlogin-error)
* [`auth:oauth-registration`](#authoauth-registration)

#### Example use in a controller
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handleBtnClick = function() {
      $auth.authenticate('github')
        .then(function(resp) {
          // handle success
        })
        .catch(function(resp) {
          // handle errors
        });
    };
  });
~~~

#### Example use in a template
~~~html
<button ng-click="authenticate('github')">
  Sign in with Github
</button>
~~~

###$auth.validateUser
This method returns a promise that will resolve if a user's auth token exists and is valid. This method does not accept any arguments. [Read more](#token-validation-flow)

This method automatically is called on page load during the app's run phase so that returning users will not need to manually re-authenticate themselves.

This method will broadcast the following events:

* On page load:
  * [`auth:validation-success`](#authvalidation-success)
  * [`auth:validation-error`](#authvalidation-error)
  * [`auth:session-expired`](#authsession-expired)
* When visiting email confirmation links:
  * [`auth:email-confirmation-success`](#authemail-confirmation-success)
  * [`auth:email-confirmation-error`](#authemail-confirmation-error)
* When visiting password reset confirmation links:
  * [`auth:password-reset-confirm-success`](#authpassword-reset-confirm-success)
  * [`auth:password-reset-confirm-error`](#authpassword-reset-confirm-error)

The promise returned by this method can be used to prevent users from viewing certain pages when using [angular ui router](https://github.com/angular-ui/ui-router) [resolvers](http://angular-ui.github.io/ui-router/site/#/api/ui.router.util.$resolve).

#### Example using angular ui router

~~~coffeescript
angular.module('myApp', [
  'ui.router',
  'ng-token-auth'
])
  .config(function($stateProvider) {
    $stateProvider
      // this state will be visible to everyone
      .state('index', {
        url: '/',
        templateUrl: 'index.html',
        controller: 'IndexCtrl'
      })

      // only authenticated users will be able to see routes that are
      // children of this state
      .state('admin', {
        url: '/admin',
        abstract: true,
        template: '<ui-view/>',
        resolve: {
          auth: function($auth) {
            return $auth.validateUser();
          }
        }
      })

      // this route will only be available to authenticated users
      .state('admin.dashboard', {
        url: '/dash',
        templateUrl: '/admin/dash.html',
        controller: 'AdminDashCtrl'
      });
  });
~~~

This example shows how to implement access control on the client side, however access to restricted information should be limited on the server as well (using something like [pundit](https://github.com/elabs/pundit) if you're using Rails).

###$auth.submitRegistration
Users can register by email using this method. [Read more](#email-registration-flow). Accepts an object with the following params:

* **email**
* **password**
* **password_confirmation**

This method broadcasts the following events:

* [`auth:registration-email-success`](#authregistration-email-success)
* [`auth:registration-email-error`](#authregistration-email-error)

##### Example use in a controller:
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handleRegBtnClick = function() {
      $auth.submitRegistration($scope.registrationForm)
        .then(function(resp) {
          // handle success response
        })
        .catch(function(resp) {
          // handle error response
        });
    };
  });
~~~

##### Example use in a template:

~~~html
<form ng-submit="submitRegistration(registrationForm)" role="form" ng-init="registrationForm = {}">
  <div class="form-group">
    <label>email</label>
    <input type="email" name="email" ng-model="registrationForm.email" required="required" class="form-control"/>
  </div>

  <div class="form-group">
    <label>password</label>
    <input type="password" name="password" ng-model="registrationForm.password" required="required" class="form-control"/>
  </div>

  <div class="form-group">
    <label>password confirmation</label>
    <input type="password" name="password_confirmation" ng-model="registrationForm.password_confirmation" required="required" class="form-control"/>
  </div>

  <button type="submit" class="btn btn-primary btn-lg">Register</button>
</form>
~~~

###$auth.submitLogin
Authenticate a user that registered via email. [Read more](#email-sign-in-flow). Accepts an object with the following params:

* **email**
* **password**

This method broadcasts the following events:

* [`auth:login-success`](#authlogin-success)
* [`auth:login-error`](#authlogin-error)

##### Example use in a controller:
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handleLoginBtnClick = function() {
      $auth.submitLogin($scope.loginForm)
        .then(function(resp) {
          // handle success response
        })
        .catch(function(resp) {
          // handle error response
        });
    };
  });
~~~

##### Example use in a template:
~~~html
<form ng-submit="submitLogin(loginForm)" role="form" ng-init="loginForm = {}">
  <div class="form-group">
    <label>email</label>
    <input type="email" name="email" ng-model="loginForm.email" required="required" class="form-control"/>
  </div>

  <div class="form-group">
    <label>password</label>
    <input type="password" name="password" ng-model="loginForm.password" required="required" class="form-control"/>
  </div>

  <button type="submit" class="btn btn-primary btn-lg">Sign in</button>
</form>
~~~

###$auth.signOut
De-authenticate a user. This method does not take any arguments. This method will change the user's `auth_token` server-side, and it will destroy the `uid` and `auth_token` cookies saved client-side.

This method broadcasts the following events:

* [`auth:logout-success`](#authlogout-success)
* [`auth:logout-error`](#authlogout-error)

##### Example use in a controller:
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handleSignOutBtnClick = function() {
      $auth.signOut()
        .then(function(resp) {
          // handle success response
        })
        .catch(function(resp) {
          // handle error response
        });
    };
  });
~~~

##### Example use in a template:
~~~html
<button class="btn btn-primary btn-lg" ng-click='signOut()'>Sign out</button>
~~~

###$auth.requestPasswordReset
Send password reset instructions to a user. This only applies to users that have registered using email. This method accepts an object with the following param:

* **email**

This method broadcasts the following events:

* [`auth:password-reset-request-success`](#authpassword-reset-request-success)
* [`auth:password-reset-request-error`](#authpassword-reset-request-error)

##### Example use in a controller:
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handlePwdResetBtnClick = function() {
      $auth.requestPasswordReset($scope.pwdResetForm)
        .then(function(resp) {
          // handle success response
        })
        .catch(function(resp) {
          // handle error response
        });
    };
  });
~~~

##### Example use in a template:
~~~html
<form ng-submit="requestPasswordReset(passwordResetForm)" role="form" ng-init="passwordResetForm = {}">
  <div class="form-group">
    <label>email</label>
    <input type="email" name="email" ng-model="passwordResetForm.email" required="required" class="form-control"/>
  </div>

  <button type="submit" class="btn btn-primary btn-lg">Request password reset</button>
</form>
~~~

###$auth.updatePassword
Change an authenticated user's password. This only applies to users that have registered using email. This method accepts an object with the following params:

* **current_password**
* **password**
* **password_confirmation**

The `password` and `password_confirmation` params must match. `current_password` param is optional - depends on the server configuration. It might be checked before password update.

This method broadcasts the following events:

* [`auth:password-change-success`](#authpassword-change-success)
* [`auth:password-change-error`](#authpassword-change-error)

##### Example use in a controller:
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handleUpdatePasswordBtnClick = function() {
      $auth.updatePassword($scope.updatePasswordForm)
        .then(function(resp) {
          // handle success response
        })
        .catch(function(resp) {
          // handle error response
        });
    };
  });
~~~

##### Example use in a template
~~~html
<form ng-submit="updatePassword(changePasswordForm)" role="form" ng-init="changePasswordForm = {}">
  <div class="form-group">
    <label>password</label>
    <input type="password" name="password" ng-model="changePasswordForm.password" required="required" class="form-control">
  </div>

  <div class="form-group">
    <label>password confirmation</label>
    <input type="password" name="password_confirmation" ng-model="changePasswordForm.password_confirmation" required="required" class="form-control">
  </div>

  <button type="submit">Change your password</button>
</form>
~~~

###$auth.updateAccount
Change an authenticated user's account info. This method accepts an object that contains valid params for your API's user model. When `password` and `password_confirmation` params are supported it updates the password as well. Depending on the server configuration `current_password` param might be needed. The following shows how to update a user's `zodiac_sign` param:

##### Example use in a template:
~~~html
<form ng-submit="updateAccount(updateAccountForm)" role="form" ng-init="updateAccountForm = {zodiac_sign: null}">
  <fieldset ng-disabled="!user.signedIn">
    <div>
      <label>zodiac sign</label>
      <input type="text" name="text" ng-model="updateAccountForm.zodiac_sign">
    </div>

    <button type="submit">Update your zodiac sign</button>
  </fieldset>
</form>
~~~

This method broadcasts the following events:

* [`auth:account-update-success`](#authaccount-update-success)
* [`auth:account-update-error`](#authaccount-update-error)

##### Example use in a controller:
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handleUpdateAccountBtnClick = function() {
      $auth.updateAccount($scope.updateAccountForm)
        .then(function(resp) {
          // handle success response
        })
        .catch(function(resp) {
          // handle error response
        });
    };
  });
~~~



###$auth.destroyAccount
Destroy a logged in user's account. This method does not accept any params.

This method broadcasts the following events:

* [`auth:account-destroy-success`](#authaccount-destroy-success)
* [`auth:account-destroy-error`](#authaccount-destroy-error)

##### Example use in a controller:
~~~javascript
angular.module('ngTokenAuthTestApp')
  .controller('IndexCtrl', function($scope, $auth) {
    $scope.handleDestroyAccountBtnClick = function() {
      $auth.destroyAccount()
        .then(function(resp) {
          // handle success response
        })
        .catch(function(resp) {
          // handle error response
        });
    };
  });
~~~

##### Example use in a template:
~~~html
<button ng-click="destroyAccount()" ng-class="{disabled: !user.signedIn}">
  Close my account
</button>
~~~

## Events

This module broadcasts events after the success or failure of each API method. Using these events to build your app can result in more flexibility while reducing code spaghetti.

For example, any template can initiate an authentication, and any controller can subscribe to the `auth:login-success` event to provide success notifications, redirects, etc.

###auth:login-success
Broadcast after successful user authentication. Event message contains the user object. This event is broadcast by the following methods:

* [`$auth.submitLogin`](#authsubmitlogin)
* [`$auth.authenticate`](#authauthenticate)

##### Example:
~~~javascript
$rootScope.$on('auth:login-success', function(ev, user) {
    alert('Welcome ', user.email);
});
~~~

###auth:login-error
Broadcast after user fails authentication. This event is broadcast by the following methods:

* [`$auth.submitLogin`](#authsubmitlogin)
* [`$auth.authenticate`](#authauthenticate)

##### Example:
~~~javascript
$rootScope.$on('auth:login-error', function(ev, reason) {
    alert('auth failed because', reason.errors[0]);
});
~~~

###auth:oauth-registration
Broadcast when the message posted after an oauth login as the new_record attribute set to `true`. This event is broadcast by the following methods:

* [`$auth.authenticate`](#authauthenticate)

##### Example:
~~~javascript
$rootScope.$on('auth:oauth-registration', function(ev, user) {
    alert('new user registered through oauth:' + user.email);
});
~~~

###auth:validation-success
Broadcast when a user's token is successfully verified using the [`$auth.validateUser`](#authvalidateuser) method.

###auth:validation-error
Broadcast when the [`$auth.validateUser`](#authvalidateuser) method fails (network error, etc). Note that this does not indicate an invalid token, but an error in the validation process. See the [`auth:invalid`](#authinvalid) event for invalid token notification.

###auth:invalid
Broadcast when a user's token fails validation using the [`$auth.validateUser`](#authvalidateuser) method. This is different from the [`auth:validation-error`](#authvalidation-error) in that it indicates an invalid token, whereas the [`auth:validation-error`](#authvalidation-error) event indicates an error in the validation process.

###auth:logout-success
Broadcast after user is successfully logged out using the [`$auth.signOut`](#authsignout) method. This event does not contain a message.

##### Example:
~~~javascript
$rootScope.$on('auth:logout-success', function(ev) {
    alert('goodbye');
});
~~~

###auth:logout-error
Broadcast after failed logout attempts using the [`$auth.signOut`](#authsignout) method. Message contains the failed logout response.

##### Example:
~~~javascript
$rootScope.$on('auth:logout-error', function(ev, reason) {
    alert('logout failed because ' + reason.errors[0]);
});
~~~

###auth:registration-email-success
Broadcast after email registration requests complete successfully using the [`$auth.submitRegistration`](#authsubmitregistration) method. Message contains the params that were sent to the server.

##### Example:
~~~javascript
$scope.$on('auth:registration-email-success', function(ev, message) {
    alert("A registration email was sent to " + message.email);
});
~~~

###auth:registration-email-error
Broadcast after failed email registration requests using the `$auth.submitRegistration` method. Message contains the error response.

This event is broadcast by the [`$auth.submitRegistration`](#authsubmitregistration) method.

##### Example:
~~~javascript
$scope.$on('auth:registration-email-error', function(ev, reason) {
    alert("Registration failed: " + reason.errors[0]);
});
~~~

###auth:email-confirmation-success
Broadcast when users arrive from links contained in password-reset emails. This can be used to trigger "welcome" notifications to new users.

This event is broadcast by the [`$auth.validateUser`](#authvalidateuser) method.

##### Example:
~~~javascript
$scope.$on('auth:email-confirmation-success', function(ev, user) {
    alert("Welcome, "+user.email+". Your account has been verified.");
});
~~~

###auth:email-confirmation-error
Broadcast when a user arrives from a link contained in a confirmation email, but the confirmation token fails to validate.

This event is broadcast by the [`$auth.validateUser`](#authvalidateuser) method.

##### Example:
~~~javascript
$scope.$on('auth:email-confirmation-error', function(ev, reason) {
    alert("There was an error with your registration.");
});
~~~

###auth:password-reset-request-success
Broadcast when users successfully submit the password reset form using the [`$auth.requestPasswordReset`](#authrequestpasswordreset) method.

##### Password reset request example:
~~~javascript
$scope.$on('auth:password-reset-request-success', function(ev, data) {
    alert("Password reset instructions were sent to " + data.email);
});
~~~

###auth:password-reset-request-error
Broadcast after failed requests using the [`$auth.requestPasswordReset`](#authrequestpasswordreset) method. Message contains the error response.

##### Example:
~~~javascript
$scope.$on('auth:password-reset-request-error', function(ev, resp) {
    alert("Password reset request failed: " + resp.errors[0]);
});
~~~

###auth:password-reset-confirm-success
Broadcast when users arrive from links contained in password reset emails. This will be the signal for your app to prompt the user to reset their password. [Read more](#password-reset-flow).

This event is broadcast by the [`$auth.validateUser`](#authvalidateuser) method.

The following example demonstrates one way to handle an `auth:password-reset-confirm-success` event. This example assumes that [angular ui-router](https://github.com/angular-ui/ui-router) is used for routing, and that there is a state called `account.password-reset` that contains instructions for changing the user's password.

##### Password reset prompt example:
~~~javascript
angular.module('myApp')
  .run(function($rootScope, $state) {
    $rootScope.$on('auth:password-reset-confirm-success', function() {
      $state.go('account.password-reset');
    });
  });
~~~

You could also choose to display a modal, or you can ignore the event completely. What you do with the `auth:password-reset-confirm-success` event is entirely your choice.

###auth:password-reset-confirm-error
Broadcast when users arrive from links contained in password reset emails, but the server fails to validate their password reset token.

This event is broadcast by the [`$auth.validateUser`](#authvalidateuser) method.

##### Example:
~~~javascript
$scope.$on('auth:password-reset-confirm-error', function(ev, reason) {
    alert("Unable to verify your account. Please try again.");
});
~~~

###auth:password-change-success
Broadcast when users successfully update their password using the [`$auth.updatePassword`](#authupdatepassword) method. [Read more](#password-reset-flow).

##### Example:
~~~javascript
$scope.$on('auth:password-change-success', function(ev) {
  alert("Your password has been successfully updated!");
});
~~~

###auth:password-change-error
Broadcast when requests resulting from the [`$auth.updatePassword`](#authupdatepassword) method fail. [Read more](#password-reset-flow).

##### Example:
~~~javascript
$scope.$on('auth:password-change-error', function(ev, reason) {
  alert("Registration failed: " + reason.errors[0]);
});
~~~

###auth:account-update-success
Broadcast when users successfully update their account info using the [`$auth.updateAccount`](#authupdateaccount) method.

##### Example:
~~~javascript
$scope.$on('auth:account-update-success', function(ev) {
  alert("Your account has been successfully updated!");
});
~~~

###auth:account-update-error
Broadcast when requests resulting from the [`$auth.updateAccount`](#authupdateaccount) method fail.

##### Example:
~~~javascript
$scope.$on('auth:account-update-error', function(ev, reason) {
  alert("Registration failed: " + reason.errors[0]);
});
~~~

###auth:account-destroy-success
Broadcast when users successfully delete their account info using the [`$auth.destroyAccount`](#authdestroyaccount) method.

##### Example:
~~~javascript
$scope.$on('auth:account-destroy-success', function(ev) {
  alert("Your account has been successfully destroyed!");
});
~~~

###auth:account-destroy-error
Broadcast when requests resulting from the [`$auth.destroyAccount`](#authdestroyaccount) method fail.

##### Example:
~~~javascript
$scope.$on('auth:account-destroy-error', function(ev, reason) {
  alert("Account deletion failed: " + reason.errors[0]);
});
~~~

###auth:session-expired
Broadcast when the [`$auth.validateUser`](#authvalidateuser) method fails because a user's token has expired.

##### Example:
~~~javascript
$scope.$on('auth:session-expired', function(ev) {
  alert('Session has expired');
});
~~~

## Using alternate header formats

By default, this module (and the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem) use the [RFC 6750 Bearer Token](http://tools.ietf.org/html/rfc6750) format. You can customize this using the `tokenFormat` and `parseExpiry` config params.

The following example will provide support for this header format:
~~~
Authorization: token={{ token }} expiry={{ expiry }} uid={{ uid }}
~~~

##### Example with alternate token format**:
~~~javascript
angular.module('myApp', ['ng-token-auth'])
  .config(function($authProvider) {
    $authProvider.configure({
      apiUrl: 'http://api.example.com'

      // provide the header template
      tokenFormat: {
        "Authorization": "token={{ token }} expiry={{ expiry }} uid={{ uid }}"
      },

      // parse the expiry from the 'Authorization' param
      parseExpiry: function(headers) {
        return (parseInt(headers['Authorization'].match(/expiry=([^ ]+) /)[1], 10)) || null

      }
    });
  });
~~~

The `tokenFormat` param accepts an object as an argument. Each param of the object will be added as an auth header to requests made to the API url provided. Each value of the object will be interpolated using the following context:

* **token**: the user's valid access token
* **uid**: the user's id
* **expiry**: the expiration date of the token
* **clientId**: the id of the current device

The `parseExpiry` param accepts a method that will be used to parse the expiration date from the auth headers. The current valid headers will be provided as an argument.

### Using alternate response formats

By default, this module expects user info (`id`, `name`, etc.) to be contained within the `data` param of successful login / token-validation responses. The following example shows an example of an expected response:

##### Expected API login response example
~~~
HTTP/1.1 200 OK
Content-Type: application/json;charset=UTF-8
{
  "data": {
    "id":"123",
    "name": "Slemp Diggler",
    "etc": "..."
  }
}
~~~

The above example follows the format used by the [devise token gem](https://github.com/lynndylanhurley/devise_token_auth). This format requires no additional configuration.

But not all APIs use this format. Some APIs simply return the serialized user model with no container params:

##### Alternate API login response example
~~~
HTTP/1.1 200 OK
Content-Type: application/json;charset=UTF-8
{
  "id":"123",
  "name": "Slemp Diggler",
  "etc": "..."
}
~~~

Functions can be provided to identify and return the relevant user data from successful authentication responses. The above example response can be handled with the following configuration:

##### Example alternate login response handler format:

~~~javascript
angular.module('myApp', ['ng-token-auth'])
  .config(function($authProvider) {
    $authProvider.configure({
      apiUrl: 'http://api.example.com'

      handleLoginResponse: function(response) {
        return response;
      },

      handleAccountUpdateResponse: function(response) {
        return response;
      },

      handleTokenValidationResponse: function(response) {
        return response;
      }
    })
  });
~~~

## Using multiple user types

### [View Live Multi-User Demo](http://ng-token-auth-demo.herokuapp.com/multi-user)

This module allows for the use of multiple user authentication configurations. The following example assumes that the API supports two user classes, `User` an `EvilUser`. The following examples assume that `User` authentication routes are mounted at `/auth`, and the `EvilUser` authentication routes are mounted at `evil_user_auth`.

### Multiple user type configuration

To set up an application for multiple users, pass an array of configuration objects to the [`$auth.configure`](#configure) method. The keys of these configuration objects (`default` and `evilUser` in this example) will be used to select the desired configuration for authentication.

##### Multiple user configuration example
~~~javascript
$authProvider.configure([
  {
    default: {
      apiUrl:  CONFIG.apiUrl,
      proxyIf: function() { window.isOldIE() },
      authProviderPaths: {
        github:    '/auth/github',
        facebook:  '/auth/facebook',
        google:    '/auth/google_oauth2'
      }
    }
  }, {
    evilUser: {
      apiUrl:                CONFIG.apiUrl,
      proxyIf:               function() { window.isOldIE() },
      signOutUrl:            '/evil_user_auth/sign_out',
      emailSignInPath:       '/evil_user_auth/sign_in',
      emailRegistrationPath: '/evil_user_auth',
      accountUpdatePath:     '/evil_user_auth',
      accountDeletePath:     '/evil_user_auth',
      passwordResetPath:     '/evil_user_auth/password',
      passwordUpdatePath:    '/evil_user_auth/password',
      tokenValidationPath:   '/evil_user_auth/validate_token',
      authProviderPaths: {
        github:    '/evil_user_auth/github',
        facebook:  '/evil_user_auth/facebook',
        google:    '/evil_user_auth/google_oauth2'
      }
    }
  }
]);
~~~

### Multiple user type usage

The following API methods accept a `config` option that can be used to specify the desired configuration.

* [`$auth.authenticate`](#authauthenticate)
* [`$auth.validateUser`](#authvalidateuser)
* [`$auth.submitRegistration`](#authsubmitregistration)
* [`$auth.submitLogin`](#authsubmitlogin)
* [`$auth.requestPasswordReset`](#authrequestpasswordreset)

All other methods (`$auth.signOut`, `$auth.updateAccount`, etc.) derive the configuration type from the current signed-in user.

The first available configuration will be used if none is provided (`default` in this example).

##### Examples using an alternate user type

~~~javascript
// OAuth
$auth.authenticate('github', {
  config: 'evilUser',
  params: {
    favorite_color: $scope.favoriteColor
  }
});

// Email Registration
$auth.submitRegistration({
  email:                 $scope.email,
  password:              $scope.password,
  password_confirmation: $scope.passwordConfirmation,
  favorite_color:        $scope.favoriteColor
}, {
  config: 'evilUser'
});

// Email Sign In
$auth.submitLogin({
  email: $scope.email,
  password: $scope.password
}, {
  config: 'evilUser'
});

// Password reset request
$auth.requestPasswordReset({
  email: $scope.passwordResetEmail
}, {
  config: 'evilUser'
});
~~~

## File uploads

Some file upload libraries interfere with the authentication headers set by this module. Workarounds are documented below:

### [angular-file-upload](https://github.com/danialfarid/angular-file-upload)#

The `upload` method accepts a `headers` option. Manually pass the current auth headers to the `upload` method as follows:

~~~javascript
$scope.onFileSelect = function($files, $auth) {
    var file = $files[0];
    $scope.upload = $upload.upload({
        url:     'api/users/update_image',
        method:  'POST',
        headers: $auth.retrieveData('auth_headers'),
        file:    file
    });
}
~~~

# Conceptual

The following is a high-level overview of this module's implementation.

## Oauth2 authentication flow

The following diagram illustrates the steps necessary to authenticate a client using an oauth2 provider.

![oauth flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/omniauth-flow.jpg)

When authenticating with a 3rd party provider, the following steps will take place, assuming the backend server is configured appropriately. [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) already accounts for these flows.

- `sameWindow` Mode
  1. The existing window will be used to access the provider's authentication page.
  2. Once the user signs in, they will be redirected back to the API using the same window, with the user and authentication tokens being set.

- `newWindow` Mode
  1. An external window will be opened to the provider's authentication page.
  2. Once the user signs in, they will be redirected back to the API at the callback uri that was registered with the oauth2 provider.
  3. The API will send the user's info back to the client via `postMessage` event, and then close the external window.

- `inAppBrowser` Mode
  - This mode is virtually identical to the `newWindow` flow, except the flow varies slightly to account for limitations with the [Cordova inAppBrowser Plugin](https://github.com/apache/cordova-plugin-inappbrowser) and the `postMessage` API.

The `postMessage` event (utilized for both `newWindow` and `inAppBrowser` modes) must include the following a parameters:
* **message** - this must contain the value `"deliverCredentials"`
* **auth_token** - a unique token set by your server.
* **uid** - the id that was returned by the provider. For example, the user's facebook id, twitter id, etc.

Rails newWindow example: [controller](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/controllers/users/auth_controller.rb#L21), [layout](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/views/layouts/oauth_response.html.erb), [view](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/views/users/auth/oauth_success.html.erb).

##### Example newWindow redirect_uri destination:

~~~html
<!DOCTYPE html>
<html>
  <head>
    <script>
      window.addEventListener("message", function(ev) {

        // this page must respond to "requestCredentials"
        if (ev.data === "requestCredentials") {

          ev.source.postMessage({
             message: "deliverCredentials", // required
             auth_token: 'xxxx', // required
             uid: 'yyyy', // required

             // additional params will be added to the user object
             name: 'Slemp Diggler'
             // etc.

          }, '*');

          // close window after message is sent
          window.close();
        }
      });
    </script>
  </head>
  <body>
    <pre>
      Redirecting...
    </pre>
  </body>
</html>
~~~

## Token validation flow

The client's tokens are stored in cookies using the ipCookie module. This is done so that users won't need to re-authenticate each time they return to the site or refresh the page.

![validation flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/validation-flow.jpg)

## Email registration flow

This module also provides support for email registration. The following diagram illustrates this process.

![email registration flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-registration-flow.jpg)

## Email sign in flow

![email sign in flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-sign-in-flow.jpg)

## Password reset flow

The password reset flow is similar to the email registration flow.

![password reset flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/password-reset-flow.jpg)

When the user visits the link contained in the resulting email, they will be authenticated for a single session. An event will be broadcast that can be used to prompt the user to update their password. See the [`auth:password-reset-confirm-success`](#events) event for details.

## About token management

Tokens should be invalidated after each request to the API. The following diagram illustrates this concept:

![password reset flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/token-update-detail.jpg)

During each request, a new token is generated. The `access-token` header that should be used in the next request is returned in the `access-token` header of the response to the previous request. The last request in the diagram fails because it tries to use a token that was invalidated by the previous request.

The benefit of this measure is that if a user's token is compromised, the user will immediately be forced to re-authenticate. This will invalidate the token that is now in use by the attacker.

The only case where an expired token is allowed is during [batch requests](#about-batch-requests).

Token management is handled by default when using this module with the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem.

## About batch requests

By default, the API should update the auth token for each request ([read more](#about-token-management)). But sometimes it's neccessary to make several concurrent requests to the API, for example:

##### Batch request example
~~~javascript
$scope.getResourceData = function() {

  $http.get('/api/restricted_resource_1').success(function(resp) {
    // handle response
    $scope.resource1 = resp.data;
  });

  $http.get('/api/restricted_resource_2').success(function(resp) {
    // handle response
    $scope.resource2 = resp.data;
  });
};
~~~

In this case, it's impossible to update the `access-token` header for the second request with the `access-token` header of the first response because the second request will begin before the first one is complete. The server must allow these batches of concurrent requests to share the same auth token. This diagram illustrates how batch requests are identified by the server:

![batch request overview](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/batch-request-overview.jpg)

The "5 second" buffer in the diagram is the default used by the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem.

The following diagram details the relationship between the client, server, and access tokens used over time when dealing with batch requests:

![batch request detail](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/batch-request-detail.jpg)

Note that when the server identifies that a request is part of a batch request, the user's auth token is not updated. The auth token will be updated for the first request in the batch, and then that same token will be returned in the responses for each subsequent request in the batch (as shown in the diagram).

The [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem automatically manages batch requests, and it provides settings to fine-tune how batch request groups are identified.

# Identifying users on the server.

The user's authentication information is included by the client in the `access-token` header of each request. If you're using the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem, the header must follow the [RFC 6750 Bearer Token](http://tools.ietf.org/html/rfc6750) format:

~~~
"access-token": "wwwww",
"token-type":   "Bearer",
"client":       "xxxxx",
"expiry":       "yyyyy",
"uid":          "zzzzz"
~~~

Replace `xxxxx` with the user's `auth_token` and `zzzzz` with the user's `uid`. The `client` field exists to allow for multiple simultaneous sessions per user. The `client` field defaults to `default` if omitted. `expiry` is used by the client to invalidate expired tokens without making an API request. A more in depth explanation of these values is [here](https://github.com/lynndylanhurley/devise_token_auth#identifying-users-in-controllers).

This will all happen automatically when using this module.

**Note**: You can customize the auth headers however you like. [Read more](#using-alternate-header-formats).

# Internet Explorer

Internet Explorer (8, 9, 10, & 11) present the following obstacles:

* IE8 & IE9 don't really support cross origin requests (CORS).
* IE8+ `postMessage` implementations don't work for our purposes.
* IE8 & IE9 both try to cache ajax requests.

The following measures are necessary when dealing with these older browsers.

#### AJAX cache must be disabled for IE8 + IE9

IE8 + IE9 will try to cache ajax requests. This results in an issue where the request return 304 status with `Content-Type` set to `html` and everything goes haywire.

The solution to this problem is to set the `If-Modified-Since` headers to `'0'` on each of the request methods that we use in our app. This is done by default when using this module.

The solution was lifted from [this stackoverflow post](http://stackoverflow.com/questions/16098430/angular-ie-caching-issue-for-http).

#### IE8 and IE9 must proxy CORS requests

You will need to set up an API proxy if the following conditions are both true:

* your API lives on a different domain than your client
* you wish to support IE8 and IE9

##### Example proxy using express for node.js
~~~javascript
var express   = require('express');
var request   = require('request');
var httpProxy = require('http-proxy');
var CONFIG    = require('config');

// proxy api requests (for older IE browsers)
app.all('/proxy/*', function(req, res, next) {
  // transform request URL into remote URL
  var apiUrl = 'http:'+CONFIG.API_URL+req.params[0];
  var r = null;

  // preserve GET params
  if (req._parsedUrl.search) {
    apiUrl += req._parsedUrl.search;
  }

  // handle POST / PUT
  if (req.method === 'POST' || req.method === 'PUT') {
    r = request[req.method.toLowerCase()]({
      uri: apiUrl,
      json: req.body
    });
  } else {
    r = request(apiUrl);
  }

  // pipe request to remote API
  req.pipe(r).pipe(res);
});
~~~

The above example assumes that you're using [express](http://expressjs.com/), [request](https://github.com/mikeal/request), and [http-proxy](https://github.com/nodejitsu/node-http-proxy), and that you have set the API_URL value using [node-config](https://github.com/lorenwest/node-config).

#### IE8-11 / iOS 8.2 must use `sameWindow` for provider authentication

Most modern browsers can communicate across tabs and windows using [postMessage](https://developer.mozilla.org/en-US/docs/Web/API/Window.postMessage). This doesn't work for certain flawed browsers. In these cases the client must take the following steps when performing provider authentication (facebook, github, etc.):

1. navigate from the client site to the API
1. navigate from the API to the provider
1. navigate from the provider to the API
1. navigate from the API back to the client

If you prefer to use the `newWindow` mode, be sure to handle this in the configuration. Eg:

```javascript
      $authProvider.configure({
        omniauthWindowType: isIE ? `sameWindow` : `newWindow`
      })
```

---

# FAQ

### Why does this module use `ipCookies` instead of `ngCookies`?

It's impossible to control cookies' path values using `ngCookies`. This results in the creation of multiple auth tokens, and it becomes impossible to send the correct token to the API.

The only options were to re-implement cookie storage from scratch, or to use the [ipCookie module](https://github.com/ivpusic/angular-cookie). The ipCookie module seemed like the better choice, and it's been working well so far.

Please direct complaints regarding this problem to [this angular issue](https://github.com/angular/angular.js/issues/1786).

# Development

### Running the dev server

There is a test project in the `test` directory of this app. To start a dev server, perform the following steps.

1. `cd` to the root of this project.
1. `npm install`
1. `cd test && bower install`
1. `cd ..`
1. `gem install sass`
1. `gulp dev`

A dev server will start on [localhost:7777](http://localhost:7777).

### Running the tests

Assuming the [dev server](#running-the-dev-server) has already been set up, start karma using the following commands:

1. `sudo npm install -g karma-cli`
1. `karma start test/test/karma.conf.coffee`

### Testing against a live API

This module was built against [this API](https://github.com/lynndylanhurley/devise_token_auth_demo). You can use this, or feel free to use your own.

There are more detailed instructions in `test/README.md`.

# Contributing

Just send a pull request. You will be granted commit access if you send quality pull requests.

#### Contribution guidelines:

* Make sure that you make changes to the CoffeeScript source file (`src/ng-token-auth.coffee`) and not the compiled distribution file (`dist/ng-token-auth.js`). If the [dev server](#running-the-dev-server) is running, the coffescript will be compiled automatically. You can also run `gulp transpile` from the project root to compile the code.
* Pull requests that include tests will receive prioirity. Read how to run the tests [here](#running-the-tests).

# Alternatives

###[Satellizer](https://github.com/sahat/satellizer)

Satellizer occupies the same problem domain as ng-token-auth. Advantages of ng-token-auth (at the time of this writing) include:
  * [Events](#events).
  * Seamless, out-of-the-box integration with the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem. This gem provides a high level of security with minimal configuration.
  * [Auth header customization](#using-alternate-header-formats).
  * [Auth response customization](#using-alternate-response-formats).
  * Supports both cookies and localStorage for session persistence.
  * Supports [password reset](#authrequestpasswordreset) and [password update](#authupdatepassword) for users that registered by email.
  * Supports [account updates](#authupdateaccount) and [account deletion](#authdestroyaccount).
  * Supports [changing tokens with each request](#about-token-management).
  * Supports [multiple user types](#using-multiple-user-types).

# Callouts

Thanks to the following contributors:

* [@booleanbetrayal](https://github.com/booleanbetrayal)
* [@guilhermesimoes](https://github.com/guilhermesimoes)
* [@jasonswett](https://github.com/jasonswett)
* [@m2omou](https://github.com/m2omou)
* [@smarquez1](https://github.com/smarquez1)
* [@jartek](https://github.com/jartek)
* [@flaviogranero](https://github.com/flaviogranero)
* [@askobara](https://github.com/askobara)

Special thanks to [@jasonswett](https://github.com/jasonswett) for [this helpful guide](https://www.airpair.com/ruby-on-rails-4/posts/authentication-with-angularjs-and-ruby-on-rails)!

This module has been featured by [http://angular-js.in](http://angular-js.in/).

# License

This project uses the WTFPL

