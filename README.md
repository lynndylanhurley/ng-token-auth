# Angular Token Auth

[![Build Status](https://travis-ci.org/lynndylanhurley/ng-token-auth.svg?branch=master)](https://travis-ci.org/lynndylanhurley/ng-token-auth)

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
      apiUrl:                 '/api',
      tokenValidationPath:    '/auth/validate_token',
      signOutUrl:             '/auth/sign_out',
      emailRegistrationPath:  '/auth',
      confirmationSuccessUrl: window.location.href,
      emailSignInPath:        '/auth/sign_in',
      proxyIf:                function() { return false; },
      proxyUrl:               '/proxy',
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
* **authProviderPaths**: an object containing paths to auth endpoints. keys are names of the providers, values are their auth paths relative to the `apiUrl`.
* **tokenValidationPath**: relative path to validate authentication tokens.
* **signOutUrl**: relative path to sign user out. this will destroy the user's token both server-side and client-side.
* **emailRegistrationPath**: path for submitting new email registrations.
* **confirmationSuccessUrl**: this value is passed to the API for email registration. I use it to redirect after email registration, but that can also be set server-side or ignored. this is useful when working with APIs that have multiple client domains.
* **emailSignInPath**: path for signing in using email credentials.
* **proxyIf**: older browsers have trouble with CORS ([read more](#proxy-cors-requests)). pass a method here to determine whether or not a proxy should be used. example: `function() { return !Modernizr.cors }`
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

  Note that this is not secure, and that access to any restricted content should be limited by the server as well.

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

### Events

The following events are broadcast by the rootscope:

* **auth:login** - broadcast after successful user authentication. event message contains the user object.
  
  **Example**:
  ~~~javascript
  $rootScope.$on('auth:login', function(ev, user) {
      alert('Welcome ', user.email);
  });
  ~~~

* **auth:failure** - broadcast after user fails authentication.
  
  **Example**:
  ~~~javascript
  $rootScope.$on('auth:failure', function(ev, reason) {
      alert('auth failed because', reason.errors[0]);
  });
  ~~~

* **auth:logout-success** - broadcast after user is successfully logged out. This event does not contain a message.

  **Example**:
  ~~~javascript
  $rootScope.$on('auth:logout-success', function(ev) {
      alert('goodbye');
  });
  ~~~

* **auth:logout-failure** - broadcast after failed logout attempts. Message contains the failed logout response.

  **Example**:
  ~~~javascript
  $rootScope.$on('auth:logout-success', function(ev, reason) {
      alert('logout failed because ' + reason.errors[0]);
  });
  ~~~

* **auth:registration-email-sent** - broadcast after email registration request completes successfully. Message contains the params that were sent to the server.

  **Example**:
  ~~~javascript
  $scope.$on('auth:registration-email-sent', function(ev, message) {
      alert("A registration email was sent to " + message.email);
  });
  ~~~

* **auth:registration-email-failed** - broadcast after email registration request fails. Message contains the error response.

  **Example**:
  ~~~javascript
  $scope.$on('auth:registration-email-failed', function(ev, reason) {
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

# Identifying users on the server.

The user's authentication information is included by the client in the `Authorization` header of each request. If you're using the [devise token auth](https://github.com/lynndylanhurley/devise_token_auth) gem, the header must follow this format:

~~~
token=xxxxx client=yyyyy uid=zzzzz
~~~

Replace `xxxxx` with the user's `auth_token` and `zzzzz` with the user's `uid`. The `client` field exists to allow for multiple simultaneous sessions per user. The `client` field defaults to `default` if omitted.

This will all happen automatically when using this module.

**Note**: If you require a different authorization header format, post an issue. I will make it a configuration option if there is a demand.

# Proxy CORS requests
Older browsers (IE8, IE9) have trouble with CORS requests. You will need to set up a proxy to support them.

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

---

# Development

There is a test project in the `test` directory of this app. To start a dev server, perform the following steps.

1. `cd` to the root of this project.
1. `npm install`
1. `cd test && bundle install`
1. `cd ..`
1. `gulp dev`

A dev server will start on [localhost:7777](http://localhost:7777).

This module was built against [this API](https://github.com/lynndylanhurley/ng-token-auth-api-rails). You can use this, or feel free to use your own.

There are more detailed instructions in `test/README.md`.

# Contributing

Just send a pull request. You will be granted commit access if you send quality pull requests.

Guidelines will be posted if the need arises.

# TODO

* Only verify tokens that have not expired.
* Add interceptor to catch 401 responses, hold http requests until user has been authenticated.
* Only add the auth header if request url matches api url.
* IE8 + IE9 support just landed in master. Expect a release within the next day or two.
* Tests.

# License

This project uses the WTFPL

