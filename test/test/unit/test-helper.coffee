# global injectors
$authProvider = null
$httpBackend  = null
$rootScope    = null
$location     = null
$provider     = null
$timeout      = null
$window       = null
$auth         = null
$q            = null

# global mock vars
validToken      = '123xyz'
validClient     = 'abc123'
validUid        = 123
validAuthHeader = "token=#{validToken} client=#{validClient} expiry=12345 uid=#{validUid}"

validEmail        = 'test@test.com'
existingUserEmail = 'testExisting@test.com'
invalidEmail      = 'gyahhh'

validUser =
  id:    666
  email: validEmail
  uid:   validUid


# run before each test
setup ->
  module 'ng-token-auth', (_$authProvider_, $provide) ->
    $authProvider = _$authProvider_
    $authProvider.configure({
      validateOnPageLoad: false
    })
    return false

  inject ($injector) ->
    $httpBackend = $injector.get('$httpBackend')
    $rootScope   = $injector.get('$rootScope')
    $location    = $injector.get('$location')
    $timeout     = $injector.get('$timeout')
    $window      = $injector.get('$window')
    $auth        = $injector.get('$auth')
    $q           = $injector.get('$q')

  # listen for broadcast events
  sinon.spy($rootScope, '$broadcast')


# run after each test
teardown ->
  $httpBackend.verifyNoOutstandingExpectation()
  $httpBackend.verifyNoOutstandingRequest()
  $auth.destroy()


### helper methods ###

setValidAuthQS = ->
  $location.search('token', validToken)
  $location.search('client_id', validClient)
  $location.search('uid', validUid)

setValidEmailConfirmQS = ->
  setValidAuthQS()
  $location.search('account_confirmation_success', true)

setValidPasswordConfirmQS = ->
  setValidAuthQS()
  $location.search('reset_password', true)
