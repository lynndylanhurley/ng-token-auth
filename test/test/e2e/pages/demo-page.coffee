class DemoPage
  alertEmailFailed:  -> element(`by`.id('alert-registration-email-failed'))
  alertEmailSuccess: -> element(`by`.id('alert-registration-email-sent'))
  modalCloseBtn:     -> element(`by`.css('.modal-footer button'))

  constructor: ->
    @regEmailField           = element(`by`.model('registrationForm.email'))
    @regPasswordField        = element(`by`.model('registrationForm.password'))
    @regPasswordConfirmField = element(`by`.model('registrationForm.password_confirmation'))
    @regSubmitBtn            = element(`by`.id('reg-submit'))

  fillRegEmailForm: (params) ->
    @regEmailField.sendKeys(params.email)
    @regPasswordField.sendKeys(params.password)
    @regPasswordConfirmField.sendKeys(params.passwordConfirm)

    if params.submit
      @regSubmitBtn.click()

  dismissModal: ->
    @modalCloseBtn().click()

module.exports = new DemoPage()
