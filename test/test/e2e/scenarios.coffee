describe "my app", ->
  browser.get "#/"

  it 'should be sane', ->
    expect(true).toBe true

  it "should show the demo page", ->
    expect(browser.getLocationAbsUrl()).toMatch "/"

  describe "ng token auth demo", ->
    beforeEach ->
      browser.get "#/"
