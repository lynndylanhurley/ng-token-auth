describe 'email registration', ->
  beforeEach module('ng-token-auth')

  describe 'sanity', ->
    it 'should be sane', inject ($auth) ->
      assertEqual true, true
