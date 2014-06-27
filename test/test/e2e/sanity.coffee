chai = require('chai')
chaiAsPromised = require('chai-as-promised')

chai.use(chaiAsPromised)
expect = chai.expect

describe 'testing sanity', ->
  it 'should be sane', ->
    expect(1).to.equal(1)
    expect(true).to.equal(true)
    #expect(true).to.equal(false)

  describe 'protractor library', ->
    it 'should expose the correct global variables', ->
      expect(protractor).to.exist
      expect(browser).to.exist
      #expect(by).to.exist
      expect(element).to.exist
      expect($).to.exist

    it 'should wrap webdriver', ->
      browser.get('/')
      expect(browser.getTitle()).to.eventually.equal('Ng Token Auth Test')
