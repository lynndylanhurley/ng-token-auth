# global injectors
$locationProvider = null
$authProvider     = null
ipCookie          = null
$httpBackend      = null
$rootScope        = null
$location         = null
$interval         = null
$provider         = null
$timeout          = null
$window           = null
$http             = null
$auth             = null
$q                = null

# global mock vars
validToken      = '123xyz'
validClient     = 'abc123'
validUid        = 123
validExpiry     = (new Date().getTime() / 1000) + 500 | 0
validAuthHeader = {
  'access-token': validToken
  'token-type':   'Bearer'
  client:         validClient
  expiry:         validExpiry
  uid:            validUid
}

validEmail        = 'test@test.com'
existingUserEmail = 'testExisting@test.com'
invalidEmail      = 'gyahhh'

validUser =
  id:    666
  email: validEmail
  uid:   validUid


# run before each test
setup ->
  module 'ng-token-auth', (_$authProvider_, _$locationProvider_, $provide) ->
    $authProvider     = _$authProvider_
    $locationProvider = _$locationProvider_
    $authProvider.configure({
      validateOnPageLoad: false
    })
    return false

  inject ($injector) ->
    $httpBackend = $injector.get('$httpBackend')
    ipCookie     = $injector.get('ipCookie')
    $rootScope   = $injector.get('$rootScope')
    $location    = $injector.get('$location')
    $interval    = $injector.get('$interval')
    $timeout     = $injector.get('$timeout')
    $window      = $injector.get('$window')
    $http        = $injector.get('$http')
    $auth        = $injector.get('$auth')
    $q           = $injector.get('$q')

  # listen for broadcast events
  sinon.spy($rootScope, '$broadcast')


# run after each test
teardown ->
  $httpBackend.verifyNoOutstandingExpectation()
  $httpBackend.verifyNoOutstandingRequest()
  $auth.deleteData('auth_headers')
  $auth.deleteData('currentConfigName')
  $auth.destroy()


### helper methods ###

setValidAuthQS = ->
  $location.search('token',     validToken)
  $location.search('client_id', validClient)
  $location.search('uid',       validUid)
  $location.search('expiry',    validExpiry)

setValidEmailConfirmQS = ->
  setValidAuthQS()
  $location.search('account_confirmation_success', true)

setValidOauthRegistrationQS = ->
  setValidAuthQS()
  $location.search('oauth_registration', true)

setValidEmailConfirmQSForAdminUser = ->
  setValidEmailConfirmQS()
  $location.search('config', 'admin')


setValidPasswordConfirmQS = ->
  setValidAuthQS()
  $location.search('reset_password', true)


setValidPasswordConfirmQSForAdminUser = ->
  setValidPasswordConfirmQS()
  $location.search('config', 'admin')
