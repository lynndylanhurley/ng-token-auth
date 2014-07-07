describe "my app", ->
  browser.get "#/"

  it "should show the demo page", ->
    expect(browser.getLocationAbsUrl()).toMatch "/"

  describe "ng token auth demo", ->
    beforeEach ->
      browser.get "#/"
