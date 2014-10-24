describe "ng-token-auth", ->
  it 'should be sane', ->
    expect(true).toBe true

  it 'should have a title', ->
    browser.get '/'
    expect(browser.getTitle()).toEqual('Ng Token Auth Test')

  describe "email registrations", ->
    beforeEach ->
      browser.get('#/')
      @demoPage = require('../pages/demo-page')

      @newUserEmail    = 'test+'+(new Date().getTime())+'@test.com'
      @newUserPassword = 'secret123'

      @duplicateUserEmail    = 'dupe+'+(new Date().getTime())+'@test.com'
      @duplicateUserPassword = @newUserPassword

    it "should broadcast event when user registers by email", ->
      @demoPage.fillRegEmailForm({
        email:           @newUserEmail
        password:        @newUserPassword
        passwordConfirm: @newUserPassword
        submit:          true
      })

      # should show "email sent" alert
      expect(element(`by`.id('alert-registration-email-sent')).isPresent()).toBe(true)


    xit "should show an error if user already exists", ->
      @demoPage.fillRegEmailForm({
        email:           @duplicateUserEmail
        password:        @duplicateUserPassword
        passwordConfirm: @duplicateUserPassword
        submit:          true
      })

      # should show "email sent" alert
      expect(@demoPage.alertEmailSuccess().isPresent()).toBe(true)

      # close modal so form is accessible
      @demoPage.dismissModal()

      # submit same information as earlier - should fail this time
      @demoPage.fillRegEmailForm({
        email:           @duplicateUserEmail
        password:        @duplicateUserPassword
        passwordConfirm: @duplicateUserPassword
        submit:          true
      })

      # should show "email failed" alert
      expect(@demoPage.alertEmailFailed().isPresent()).toBe(true)

    it "should show an error if passwords don't match", ->
      @demoPage.fillRegEmailForm({
        email:           @duplicateUserEmail
        password:        @duplicateUserPassword
        passwordConfirm: 'bogus'
        submit:          true
      })

      # should show "email sent" alert
      expect(@demoPage.alertEmailFailed().isPresent()).toBe(true)
