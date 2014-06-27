# Angular Token Auth

## Configuration

~~~javascript
angular.module('myApp'), ['ng-token-auth'])

	// configure the module in a config block
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
			// to me when working with APIs that have multiple
			// client domains.
			confirmationSuccessUrl: window.location.href,

			// path for signing in using email credentials. this
			// will be done via a post request.
			emailSignInPath: '/auth/sign_in',

			// older browsers have trouble with CORS. pass a method
			// here to determine whether or not to use a proxy.
			// example: function() { Modernizr.cors }
			proxyIf: function() { false; },

			// proxy url if proxy is used
			proxyUrl: '/proxy'

		});
	});
~~~

## Oauth2 Authentication

### How do I sign a user in via facebook, twitter, github, etc.?

The following diagram illustrates the steps necessary to authenticate a client using an oauth2 provider.

![oauth flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/omniauth-flow.jpg)




![validation flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/validation-flow.jpg)

![email registration flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-registration-flow.jpg)

![email sign in flow](https://github.com/lynndylanhurley/ng-token-auth/raw/master/test/app/images/flow/email-sign-in-flow.jpg)
