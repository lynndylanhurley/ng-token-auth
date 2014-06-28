# Angular Token Auth

## Project goals

This module aims to provide a simple method of client authentication that can be configured to work with a wide variety of server stacks.

This module was built against [Rails](https://github.com/rails/rails), [devise](https://github.com/plataformatec/devise) and [omniauth](https://github.com/intridea/omniauth), but I've been able to use it with [go](http://golang.org/), [gorm](https://github.com/jinzhu/gorm) and [gomniauth](https://github.com/stretchr/gomniauth) as well. Note that none of these projects work with this module out of the box. 
Links to server-side (Rails) code have been provided. The examples are taken from [this project](https://github.com/lynndylanhurley/ng-token-auth-api-rails), which was designed to work with this module.

Token based authentication requires coordination between the client and the server. Diagrams are included to illustrate this relationship. 


## Configuration
### $authProvider.configure

The `$authProvider` is available for injection during the app's configuration phase. Configure this module for use with the API server using a `config` block. [Read more about configuring providers](https://github.com/angular/angular.js/wiki/Understanding-Dependency-Injection#configuring-providers)

### Config example
~~~javascript
angular.module('myApp'), ['ng-token-auth'])

	.config(function($authProvider) {

		// the following uses the default values. values passed
		// to this method will extend the defaults using
		// angular.extend
		$authProvider.configure({
			
			// the base route to your api
			apiUrl: '/api',

			// object containing paths to auth endpoints.
			authProviderPaths: {
        		github:   '/auth/github',
        		facebook: '/auth/facebook',
        		google:   '/auth/google'
			},

			// path to validate authentication tokens
			tokenValidationPath: '/auth/validate_token',

			// path to sign user out. this will destroy the
			// user's token both server-side and client-side
			signOutUrl: '/auth/sign_out',

			// path for submitting new email registrations. this
			// will be done via a post request.
			emailRegistrationPath: '/auth',
			
			// this value is passed to the API for email registration.
			// I use it to redirect after email registration, but that
			// can also be set server-side or ignored. this is useful
			// when working with APIs that have multiple client domains.
			confirmationSuccessUrl: window.location.href,

			// path for signing in using email credentials. this
			// will be done via a post request.
			emailSignInPath: '/auth/sign_in',
			
			// older browsers have trouble with CORS. pass a method
			// here to determine whether or not a proxy should be used.
			// example: function() { return !Modernizr.cors }
			proxyIf: function() { return false; },

			// proxy url if proxy is used
			proxyUrl: '/proxy'

		});
	});
~~~

## Oauth2 authentication

### Conceptual

The following diagram illustrates the steps necessary to authenticate a client using an oauth2 provider.

![oauth flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/omniauth-flow.jpg)

When authenticating with a 3rd party provider, the following steps will take place.

1. An external window will be opened to the provider's authentication page. 
1. Once the user signs in, they will be redirected back to api API at the callback uri that was registered with the oauth2 provider.
1. The API will send the user's info back to the client via `postMessage` event, and then close the external window.

The postMessage event must include the following a parameters:
* `message` - this must contain the value `"deliverCredentials"`
* `auth_token` - a unique token set by your server.
* `uid` - the id that was returned by the provider. For example, the user's facebook id, twitter id, etc.

Rails example: [controller](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/controllers/users/auth_controller.rb#L21), [layout](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/views/layouts/oauth_response.html.erb), [view](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/views/users/auth/oauth_success.html.erb).

#### Example redirect_uri destination:

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

### Oauth2 Service methods

The `$auth` service is available for injection during the app's run phase.

### $auth.authenticate

This method is available as part of the `$auth` service, and it is also attached to the `$rootScope` for use in templates.

#### Example use in a controller
~~~javascript
angular.module('ngTokenAuthTestApp')
	.controller('IndexCtrl', function($auth) {

		$auth.authenticate('github')

	});
~~~

#### Example use in a template
~~~html
<button ng-click="authenticate('github')">
  Sign in with Github
</button>
~~~

## Token validation

The client's tokens are stored in cookies using the ngCookie module. This is done so that users won't need to re-authenticate each time they return to the site or refresh the page.

### Conceptual

![validation flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/validation-flow.jpg)

Rails example [here](https://github.com/lynndylanhurley/ng-token-auth-api-rails/blob/master/app/controllers/users/auth_controller.rb#L5)

### $auth.validateUser

`$auth.validateUser()` is called on page load during the app's run phase.

This method returns a `$q` promise. These promises can be used to prevent users from viewing certain pages when using angular ui router resolvers.

#### Example

~~~coffeescript
angular.module('ngTokenAuthTestApp', [
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

Note that this is not secure, and that any restricted content should be limited by the server as well.

## Email registration

This module also provides support for email registration. The following diagram illustrates this process.

![email registration flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-registration-flow.jpg)

### $auth.submitRegistration

The `$auth.submitRegistration` method is provided to the `$rootScope` to facilitate email registraiton submission.

#### Example
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

## Email sign in

### Conceptual

![email sign in flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-sign-in-flow.jpg)

### $auth.submitLogin

For users that signed up via email, the `$auth.submitLogin` method allows them to authenticate using the email and password they used to register their account.

#### Example

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