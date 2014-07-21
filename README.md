# Angular Token Auth

[![Bower version](https://badge.fury.io/bo/ng-token-auth.svg)](http://badge.fury.io/bo/ng-token-auth)
[![Build Status](https://travis-ci.org/lynndylanhurley/ng-token-auth.svg?branch=master)](https://travis-ci.org/lynndylanhurley/ng-token-auth)
[![Test Coverage](https://codeclimate.com/github/lynndylanhurley/ng-token-auth/coverage.png)](https://codeclimate.com/github/lynndylanhurley/ng-token-auth)

This module provides a simple method of client authentication that can be configured to work with any api.

This module was designed to work out of the box with the outstanding [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem, but I've been able to use it in other environments as well ([go](http://golang.org/), [gorm](https://github.com/jinzhu/gorm) and [gomniauth](https://github.com/stretchr/gomniauth) for example).

Token based authentication requires coordination between the client and the server. Diagrams are included to illustrate this relationship.

**About security**: [read here](http://stackoverflow.com/questions/18605294/is-devises-token-authenticatable-secure) for more information on securing your token auth system. The [devise token auth](https://github.com/lynndylanhurley/devise_token_auth#security) gem has adequate security measures in place, and the gem works seamlessly with this module.

# Demo

This project comes bundled with a test app. You can run the demo locally by following [these instructions](#development), or you can use it [here in production](http://ng-token-auth-demo.herokuapp.com/).


# Installation

* `bower install ng-token-auth --save`
* include `ng-token-auth` in your app.

##### Example module inclusion:
~~~javascript
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
      confirmationSuccessUrl:  window.location.href,
      passwordResetPath:       '/auth/password'
      passwordUpdatePath:      '/auth/password'
      passwordResetSuccessUrl: window.location.href
      emailSignInPath:         '/auth/sign_in',
      proxyIf:                 function() { return false; },
      proxyUrl:                '/proxy',
      authProviderPaths: {
        github:   '/auth/github',
        facebook: '/auth/facebook',
        google:   '/auth/google'
      }
    });
  });
~~~

##### Config options:
* **apiUrl**: the base route to your api. Each of the following paths will be relative to this URL.
* **authProviderPaths**: an object containing paths to auth endpoints. keys are names of the providers, values are their auth paths relative to the `apiUrl`. [Read more](#oauth2-authentication-flow).
* **tokenValidationPath**: relative path to validate authentication tokens. [Read more](#token-validation-flow).
* **emailRegistrationPath**: path for submitting new email registrations. [Read more](#email-registration-flow).
* **signOutUrl**: relative path to sign user out. this will destroy the user's token both server-side and client-side.
* **confirmationSuccessUrl**: the url to which the API should redirect after users visit the link contained in email-registration emails. [Read more](#email-registration-flow).
* **emailSignInPath**: path for signing in using email credentials. [Read more](#email-sign-in-flow).
* **passwordResetPath**: path for requesting password reset emails. [Read more](#password-reset-flow).
* **passwordUpdatePath**: path for submitting new passwords for authenticated users. [Read more](#password-reset-flow).
* **passwordResetSuccessUrl**: the URL to which the API should redirect after users visit the links contained in password-reset emails. [Read more](#password-reset-flow).
* **proxyIf**: older browsers have trouble with CORS ([read more](#ie8-and-ie9)). pass a method here to determine whether or not a proxy should be used. example: `function() { return !Modernizr.cors }`
* **proxyUrl**: proxy url if proxy is to be used


# Usage

The `$auth` module is available for dependency injection during your app's run phase (for controllers, directives, filters, etc.). The following methods are available.

* **$auth.authenticate**: initiate on oauth2 authentication. takes 1 argument, a string that is also the name of the target provider service. This method is also added to the `$rootScope` for use in templates. [Read more](#oauth2-authentication-flow).

  ##### Example use in a controller
  ~~~javascript
  angular.module('ngTokenAuthTestApp')
    .controller('IndexCtrl', function($auth) {
      $scope.handleBtnClick = function() {
        $auth.authenticate('github')
      };

    });
  ~~~

  ##### Example use in a template
  ~~~html
  <button ng-click="authenticate('github')">
    Sign in with Github
  </button>
  ~~~

* **$auth.validateUser**: return a promise that will resolve if a user's auth token exists and is valid. This method does not take any arguments. [Read more](#token-validation-flow)

  This method is called on page load during the app's run phase so that returning users will not need to manually re-authenticate themselves.

  The promise returned by this method can be used to prevent users from viewing certain pages when using [angular ui router](https://github.com/angular-ui/ui-router) [resolvers](http://angular-ui.github.io/ui-router/site/#/api/ui.router.util.$resolve).

  ##### Example using angular ui router

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

* **$auth.submitRegistration**: Users can register by email using this method. [Read more](#email-registration-flow). Accepts an object with the following params:
  * **email**
  * **password**
  * **password_confirmation**

  This method is also available in the `$rootScope` for use in templates.

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

* **$auth.submitLogin**: authenticate a user who has registered by email. [Read more](#email-sign-in-flow). Accepts an object with the following params:
  * **email**
  * **password**

  This method is also available in the `$rootScope` for use in templates.

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

* **$auth.signOut**: de-authenticate a user. This method does not take any arguments. This method will change the user's `auth_token` server-side, and it will destroy the `uid` and `auth_token` cookies saved client-side. This method is also available in the `$rootScope` for use in templates.

  ##### Example use in a template:
  ~~~html
  <button class="btn btn-primary btn-lg" ng-click='signOut()'>Sign out</button>
  ~~~

* **$auth.requestPasswordReset**: send password reset instructions to a user. This only applies to users that have registered using email. This method accepts an object with the following param:
  * **email**

  This method is also available in the `$rootScope` for use in templates.

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

* **$auth.updatePassword**: change an authenticated user's password. This only applies to users that have registered using email. This method accepts an object with the following params:
  * **password**
  * **password_confirmation**

  The two params must match. This method is also available in the `$rootScope` for use in templates.

  ##### Example use in a template
  ~~~html
  <form ng-submit="updatePassword(changePasswordForm)" role="form" ng-init="changePasswordForm = {}">
    <div class="form-group">
      <label>password</label>
      <input type="password" name="password" ng-model="changePasswordForm.password" required="required" class="form-control"/>
    </div>

    <div class="form-group">
      <label>password confirmation</label>
      <input type="password" name="password_confirmation" ng-model="changePasswordForm.password_confirmation" required="required" class="form-control"/>
    </div>

    <button type="submit" class="btn btn-primary btn-lg">Change your password</button>
  </form>
  ~~~

### Events

The following events are broadcast by the `$rootScope`:

* **auth:login-success** - broadcast after successful user authentication. event message contains the user object.

  **Example**:
  ~~~javascript
  $rootScope.$on('auth:login-success', function(ev, user) {
      alert('Welcome ', user.email);
  });
  ~~~

* **auth:login-error** - broadcast after user fails authentication.

  **Example**:
  ~~~javascript
  $rootScope.$on('auth:login-error', function(ev, reason) {
      alert('auth failed because', reason.errors[0]);
  });
  ~~~

* **auth:logout-success** - broadcast after user is successfully logged out using the `$auth.signOut` method. This event does not contain a message.

  **Example**:
  ~~~javascript
  $rootScope.$on('auth:logout-success', function(ev) {
      alert('goodbye');
  });
  ~~~

* **auth:logout-error** - broadcast after failed logout attempts using the `$auth.signOut` method. Message contains the failed logout response.

  **Example**:
  ~~~javascript
  $rootScope.$on('auth:logout-error', function(ev, reason) {
      alert('logout failed because ' + reason.errors[0]);
  });
  ~~~

* **auth:registration-email-success** - broadcast after email registration requests complete successfully using the `$auth.submitRegistration` method. Message contains the params that were sent to the server.

  **Example**:
  ~~~javascript
  $scope.$on('auth:registration-email-success', function(ev, message) {
      alert("A registration email was sent to " + message.email);
  });
  ~~~

* **auth:registration-email-error** - broadcast after failed email registration requests using the `$auth.submitRegistration` method. Message contains the error response.

  **Example**:
  ~~~javascript
  $scope.$on('auth:registration-email-error', function(ev, reason) {
      alert("Registration failed: " + reason.errors[0]);
  });
  ~~~

* **auth:email-confirmation-success** - broadcast when users arrive from links contained in password reset emails. You can use this to trigger "welcome" notifications to new users if you like.

  **Example**:
  ~~~javascript
  $scope.$on('auth:email-confirmation-success', function(ev, user) {
      alert("Welcome, "+user.email+". Your account has been verified.");
  });
  ~~~

* **auth:email-confirmation-error** - broadcast when users arrive from links contained in password reset emails and their confirmation tokens fail to validate.

  **Example**:
  ~~~javascript
  $scope.$on('auth:email-confirmation-error', function(ev, reason) {
      alert("There was an error with your registration.");
  });
  ~~~

* **auth:password-reset-request-success** - broadcast when users successfully submit the password reset form using the `$auth.requestPasswordReset` method.

  **Password reset request example**:
  ~~~javascript
  $scope.$on('auth:password-reset-request-success', function(ev, data) {
      alert("Password reset instructions were sent to " + data.email);
  });
  ~~~

* **auth:password-reset-request-error** - broadcast after failed requests using the `$auth.requestPasswordReset` method. Message contains the error response.

  **Example**:
  ~~~javascript
  $scope.$on('auth:password-reset-request-error', function(ev, resp) {
      alert("Password reset request failed: " + resp.errors[0]);
  });
  ~~~

* **auth:password-reset-confirm-success** - broadcast when users arrive from links contained in password reset emails. This will be the signal for your app to prompt the user to reset their password. [Read more](#password-reset-flow).

  The following example demonstrates one way to handle an `auth:password-reset-confirm-success` event. This example assumes that [angular ui-router](https://github.com/angular-ui/ui-router) is used for routing, and that there is a state called `account.password-reset` that contains instructions for changing the user's password.

  **Password reset prompt example**:
  ~~~javascript
  angular.module('myApp')
    .run(function($rootScope, $state) {
      $rootScope.$on('auth:password-reset-confirm-success', function() {
        $state.go('account.password-reset');
      });
    });
  ~~~

  You could also choose to display a modal, or you can ignore the event completely. What you do with the `auth:password-reset-prompt` event is entirely your choice.


* **auth:password-reset-confirm-error** - broadcast when users arrive from links contained in password reset emails, but the server fails to validate their password reset token.

  **Example**:
  ~~~javascript
  $scope.$on('auth:password-reset-confirm-error', function(ev, reason) {
      alert("Unable to verify your account. Please try again.");
  });
  ~~~

* **auth:password-change-success** - broadcast when users successfully update their password using the `$auth.updatePassword` method. [Read more](#password-reset-flow).

  **Example**:
  ~~~javascript
  $scope.$on('auth:password-change-success', function(ev) {
    alert("Your password has been successfully updated!");
  });
  ~~~

* **auth:password-change-error** - broadcast when requests resulting from the `$auth.updatePassword` method fail. [Read more](#password-reset-flow).

  **Example**:
  ~~~javascript
  $scope.$on('auth:registration-change-error', function(ev, reason) {
    alert("Registration failed: " + reason.errors[0]);
  });
  ~~~

# Conceptual

## Oauth2 authentication flow

The following diagram illustrates the steps necessary to authenticate a client using an oauth2 provider.

![oauth flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/omniauth-flow.jpg)

When authenticating with a 3rd party provider, the following steps will take place.

1. An external window will be opened to the provider's authentication page.
1. Once the user signs in, they will be redirected back to the API at the callback uri that was registered with the oauth2 provider.
1. The API will send the user's info back to the client via `postMessage` event, and then close the external window.

The postMessage event must include the following a parameters:
* **message** - this must contain the value `"deliverCredentials"`
* **auth_token** - a unique token set by your server.
* **uid** - the id that was returned by the provider. For example, the user's facebook id, twitter id, etc.

Rails example: [controller](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/controllers/users/auth_controller.rb#L21), [layout](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/views/layouts/oauth_response.html.erb), [view](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/views/users/auth/oauth_success.html.erb).

##### Example redirect_uri destination:

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

The client's tokens are stored in cookies using the ngCookie module. This is done so that users won't need to re-authenticate each time they return to the site or refresh the page.

![validation flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/validation-flow.jpg)

Rails example [here](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/controllers/users/auth_controller.rb#L5)


## Email registration flow

This module also provides support for email registration. The following diagram illustrates this process.

![email registration flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-registration-flow.jpg)

## Email sign in flow

![email sign in flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-sign-in-flow.jpg)

## Password reset flow

The password reset flow is similar to the email registration flow.

![password reset flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/password-reset-flow.jpg)

When the user visits the link contained in the resulting email, they will be authenticated for a single session. An event will be broadcast that can be used to prompt the user to update their password. See the [`auth:password-reset-prompt`](#events) event for details.

## About token management

Tokens should be invalidated after each request to the API. The following diagram illustrates this concept:

![password reset flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/token-update-detail.jpg)

During each request, a new token is generated. The `Authorization` header that should be used in the next request is returned in the `Authorization` header of the response to the previous request. The last request in the diagram fails because it tries to use a token that was invalidated by the previous request.

The only case where an expired token is allowed is during [batch requests](#about-batch-requests).

Token management is handled by default when using this module with the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem.

## About batch requests

By default, the API should update the auth token for each request ([read more](#about-token-management)). But sometimes it's neccessary to make several concurrent requests to the API, for example:

#####Batch request example
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

In this case, it's impossible to update the `Authorization` header for the second request with the `Authorization` header of the first response because the second request will begin before the first one is complete. The server must allow these batches of concurrent requests to share the same auth token. This diagram illustrates how batch requests are identified by the server:

![batch request overview](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/batch-request-overview.jpg)

The "5 second" buffer in the diagram is the default used by the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem.

The following diagram details the relationship between the client, server, and access tokens used over time when dealing with batch requests:

![batch request detail](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/batch-request-detail.jpg)

Note that when the server identifies that a request is part of a batch request, the user's auth token is not updated. The auth token will be updated for the first request in the batch, and then that same token will be returned in the responses for each subsequent request in the batch (as shown in the diagram).

The [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem automatically manages batch requests, and it provides settings to fine-tune how batch request groups are identified.

# Identifying users on the server.

The user's authentication information is included by the client in the `Authorization` header of each request. If you're using the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem, the header must follow this format:

~~~
token=wwwww client=xxxxx expiry=yyyyy uid=zzzzz
~~~

Replace `xxxxx` with the user's `auth_token` and `zzzzz` with the user's `uid`. The `client` field exists to allow for multiple simultaneous sessions per user. The `client` field defaults to `default` if omitted. `expiry` is used by the client to invalidate expired tokens without making an API request. A more in depth explanation of these values is [here](https://github.com/lynndylanhurley/devise_token_auth#identifying-users-in-controllers).

This will all happen automatically when using this module.

**Note**: If you require a different authorization header format, post an issue. I will make it a configuration option if there is a demand.

# IE8 and IE9

IE8 and IE9 present the following obstacles:

* They don't really support cross origin requests (CORS).
* Their `postMessage` implementations don't work for our purposes.
* They both try to cache ajax requests.

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

#### IE8 and IE9 must use hard redirects for provider authentication

Modern browsers can communicate across tabs and windows using [postMessage](https://developer.mozilla.org/en-US/docs/Web/API/Window.postMessage). This doesn't work for older browsers such as IE8 and IE9. In these cases the client must take the following steps when performing provider authentication (facebook, github, etc.):

1. navigate from the client site to the API
1. navigate from the API to the provider
1. navigate from the provider to the API
1. navigate from the API back to the client

These steps are taken automatically when using this module with IE8 and IE9. I am currently investigating several `postMessage` polyfills. Hopefully this issue will be resolved shortly.

---

# Development

There is a test project in the `test` directory of this app. To start a dev server, perform the following steps.

1. `cd` to the root of this project.
1. `npm install`
1. `cd test && bundle install`
1. `cd ..`
1. `gulp dev`

A dev server will start on [localhost:7777](http://localhost:7777).

This module was built against [this API](https://github.com/lynndylanhurley/devise_token_auth_demo). You can use this, or feel free to use your own.

There are more detailed instructions in `test/README.md`.

# Contributing

Just send a pull request. You will be granted commit access if you send quality pull requests.

Guidelines will be posted if the need arises.

# TODO

* Only verify tokens that have not expired.
* Add interceptor to catch 401 responses, hold http requests until user has been authenticated.
* Only add the auth header if request url matches api url.
* Tests.

# License

This project uses the WTFPL

