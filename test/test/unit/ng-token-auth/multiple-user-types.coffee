suite 'multiple concurrent auth configurations', ->
  successResp = validUser

  suite 'single unnamed config', ->
    defaultConfig =
      signOutUrl:              '/vega/sign_out'
      emailSignInPath:         '/vega/sign_in'
      emailRegistrationPath:   '/vega'
      accountUpdatePath:       '/vega'
      accountDeletePath:       '/vega'
      passwordResetPath:       '/vega/password'
      passwordUpdatePath:      '/vega/password'
      tokenValidationPath:     '/vega/validate_token'
      omniauthWindowType:      'newWindow'
      createPopup:             (url) ->
                                 closed: false
                                 postMessage: -> null
      authProviderPaths:
        github:    '/vega/github'


    setup ->
      $authProvider.configure(defaultConfig)


    test 'getConfig returns "default" config when no params specified', ->
      assert.equal(defaultConfig.signOutUrl, $auth.getConfig().signOutUrl)
      assert.equal(defaultConfig.emailSignInPath, $auth.getConfig().emailSignInPath)
      assert.equal(defaultConfig.emailRegistrationPath, $auth.getConfig().emailRegistrationPath)
      assert.equal(defaultConfig.accountUpdatePath, $auth.getConfig().accountUpdatePath)
      assert.equal(defaultConfig.accountDeletePath, $auth.getConfig().accountDeletePath)
      assert.equal(defaultConfig.accountResetPath, $auth.getConfig().accountResetPath)
      assert.equal(defaultConfig.accountUpdatePath, $auth.getConfig().accountUpdatePath)
      assert.equal(defaultConfig.tokenValidationPath, $auth.getConfig().tokenValidationPath)

    test 'authenticate uses only config by default', ->

      sinon.stub(defaultConfig, 'createPopup').returns({
        closed: false
        postMessage: -> null
      })

      $authProvider.configure(defaultConfig)

      expectedRoute = "/api/vega/github"
      $auth.authenticate('github')

      assert($auth.getConfig().createPopup.calledWithMatch(expectedRoute))


    test 'submitLogin uses only config by default', ->
      args =
        email: validUser.email
        password: 'secret123'

      $httpBackend
        .expectPOST('/api/vega/sign_in')
        .respond(201, {
          success: true
          data: validUser
        })

      $rootScope.submitLogin(args)
      $httpBackend.flush()


    test 'validateUser uses only config by default', ->
      $httpBackend
        .expectGET('/api/vega/validate_token')
        .respond(201, successResp, validAuthHeader)

      ipCookie('auth_headers', validAuthHeader, {path: '/'})
      $auth.validateUser()
      $httpBackend.flush()


  suite 'multiple configs', ->
    userConfig =
      user:
        signOutUrl:              '/rigel/sign_out'
        emailSignInPath:         '/rigel/sign_in'
        emailRegistrationPath:   '/rigel'
        accountUpdatePath:       '/rigel'
        accountDeletePath:       '/rigel'
        passwordResetPath:       '/rigel/password'
        passwordUpdatePath:      '/rigel/password'
        tokenValidationPath:     '/rigel/validate_token'
        omniauthWindowType:      'newWindow'
        createPopup:             (url) ->
                                   closed: false
                                   postMessage: -> null
        authProviderPaths:
          github: '/rigel/github'

    adminConfig =
      admin:
        signOutUrl:              '/cygni/sign_out'
        emailSignInPath:         '/cygni/sign_in'
        emailRegistrationPath:   '/cygni'
        accountUpdatePath:       '/cygni'
        accountDeletePath:       '/cygni'
        passwordResetPath:       '/cygni/password'
        passwordUpdatePath:      '/cygni/password'
        tokenValidationPath:     '/cygni/validate_token'
        omniauthWindowType:      'newWindow'
        createPopup:             (url) ->
                                   closed: false
                                   postMessage: -> null
        authProviderPaths:
          github: '/cygni/github'


    test 'getConfig returns first ("user") config when no params specified', ->
      cs = $authProvider.configure([userConfig, adminConfig])
      assert.equal(userConfig.user.signOutUrl, $auth.getConfig().signOutUrl)
      assert.equal(userConfig.user.emailSignInPath, $auth.getConfig().emailSignInPath)
      assert.equal(userConfig.user.emailRegistrationPath, $auth.getConfig().emailRegistrationPath)
      assert.equal(userConfig.user.accountUpdatePath, $auth.getConfig().accountUpdatePath)
      assert.equal(userConfig.user.accountDeletePath, $auth.getConfig().accountDeletePath)
      assert.equal(userConfig.user.accountResetPath, $auth.getConfig().accountResetPath)
      assert.equal(userConfig.user.accountUpdatePath, $auth.getConfig().accountUpdatePath)
      assert.equal(userConfig.user.tokenValidationPath, $auth.getConfig().tokenValidationPath)


    test 'getConfig returns "admin" config when specified', ->
      cs = $authProvider.configure([userConfig, adminConfig])
      assert.equal(adminConfig.admin.signOutUrl, $auth.getConfig("admin").signOutUrl)
      assert.equal(adminConfig.admin.emailSignInPath, $auth.getConfig("admin").emailSignInPath)
      assert.equal(adminConfig.admin.emailRegistrationPath, $auth.getConfig("admin").emailRegistrationPath)
      assert.equal(adminConfig.admin.accountUpdatePath, $auth.getConfig("admin").accountUpdatePath)
      assert.equal(adminConfig.admin.accountDeletePath, $auth.getConfig("admin").accountDeletePath)
      assert.equal(adminConfig.admin.accountResetPath, $auth.getConfig("admin").accountResetPath)
      assert.equal(adminConfig.admin.accountUpdatePath, $auth.getConfig("admin").accountUpdatePath)
      assert.equal(adminConfig.admin.tokenValidationPath, $auth.getConfig("admin").tokenValidationPath)


    suite 'authenticate', ->
      setup ->
        sinon.stub(userConfig.user, 'createPopup').returns({
          closed: false
          postMessage: -> null
        })
        sinon.stub(adminConfig.admin, 'createPopup').returns({
          closed: false
          postMessage: -> null
        })
        cs = $authProvider.configure([userConfig, adminConfig])

      teardown ->
        userConfig.user.createPopup.restore()
        adminConfig.admin.createPopup.restore()

      test 'uses first config by default', ->
        expectedRoute = "/api/rigel/github"
        $auth.authenticate('github')
        assert($auth.getConfig().createPopup.calledWithMatch(expectedRoute))

      test 'uses second config when specified', ->
        expectedRoute = "/api/cygni/github"
        $auth.authenticate('github', {config: 'admin'})
        assert($auth.getConfig('admin').createPopup.calledWithMatch(expectedRoute))


    suite 'submitLogin', ->

      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'uses first config by default', ->
        args =
          email: validUser.email
          password: 'secret123'

        $httpBackend
          .expectPOST('/api/rigel/sign_in')
          .respond(201, {
            success: true
            data: validUser
          })

        $rootScope.submitLogin(args)
        $httpBackend.flush()

      test 'uses second config when specified', ->
        args =
          email: validUser.email
          password: 'secret123'

        $httpBackend
          .expectPOST('/api/cygni/sign_in')
          .respond(201, {
            success: true
            data: validUser
          })

        $rootScope.submitLogin(args, {config: 'admin'})
        $httpBackend.flush()


      test 'config name is persisted locally when not using the default config', ->
        args =
          email: validUser.email
          password: 'secret123'

        $httpBackend
          .expectPOST('/api/cygni/sign_in')
          .respond(201, {
            success: true
            data: validUser
          })

        $rootScope.submitLogin(args, {config: 'admin'})
        $httpBackend.flush()
        assert.equal('admin', $auth.getCurrentConfigName())


    suite 'signOut', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])
        # ensure that user is signed in, named config is set
        args =
          email: validUser.email
          password: 'secret123'

        $httpBackend
          .expectPOST('/api/cygni/sign_in')
          .respond(201, {
            success: true
            data: validUser
          })

        $rootScope.submitLogin(args, {config: 'admin'})
        $httpBackend.flush()

        $httpBackend
          .expectDELETE('/api/cygni/sign_out')
          .respond(201, {success: true})

        $rootScope.signOut()
        $httpBackend.flush()


      test 'saved config name ref is deleted', ->
        assert.equal(null, $auth.currentConfigName)


      test 'saved config name cookie is deleted', ->
        assert.equal(undefined, $auth.retrieveData('currentConfigName'))


    suite 'validateUser', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'uses saved config if present', ->
        $auth.setConfigName('admin')

        $httpBackend
          .expectGET('/api/cygni/validate_token')
          .respond(201, successResp, validAuthHeader)

        ipCookie('auth_headers', validAuthHeader, {path: '/'})
        $auth.validateUser()
        $httpBackend.flush()


      test 'uses first config as fallback', ->
        $httpBackend
          .expectGET('/api/rigel/validate_token')
          .respond(201, successResp, validAuthHeader)

        ipCookie('auth_headers', validAuthHeader, {path: '/'})
        $auth.validateUser()
        $httpBackend.flush()


      test 'uses named config when specified', ->
        $httpBackend
          .expectGET('/api/rigel/validate_token')
          .respond(201, successResp, validAuthHeader)

        ipCookie('auth_headers', validAuthHeader, {path: '/'})
        $auth.validateUser('admin')
        $httpBackend.flush()


    suite 'submitRegistration', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'uses first config by default', ->
        $httpBackend
          .expectPOST('/api/rigel')
          .respond(201, {success: true})

        $auth.submitRegistration({
          email: validEmail
          password: 'secret123'
          password_confirmation: 'secret123'
        })

        $httpBackend.flush()


      test 'uses stored named config when present', ->
        $httpBackend
          .expectPOST('/api/cygni')
          .respond(201, {success: true})

        $auth.submitRegistration({
          email: validEmail
          password: 'secret123'
          password_confirmation: 'secret123'
        }, {
          config: 'admin'
        })

        $httpBackend.flush()


    suite 'registration confirmation', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'admin user is validated using the correct configuration', ->
        setValidEmailConfirmQSForAdminUser()
        $httpBackend
          .expectGET('/api/cygni/validate_token')
          .respond(201, successResp, validAuthHeader)

        $auth.validateUser()
        $httpBackend.flush()


    suite 'password change request confirmation', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'admin user is validated using the correct configuration', ->
        setValidPasswordConfirmQSForAdminUser()
        $httpBackend
          .expectGET('/api/cygni/validate_token')
          .respond(201, successResp, validAuthHeader)

        $auth.validateUser()
        $httpBackend.flush()


    suite 'destroyAccount', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'uses stored named config when present', ->
        $auth.setConfigName('admin')

        $httpBackend
          .expectDELETE('/api/cygni/sign_out')
          .respond(201, successResp)

        $auth.signOut()

        $httpBackend.flush()


      test 'falls back to default config name', ->
        $httpBackend
          .expectDELETE('/api/rigel/sign_out')
          .respond(201, successResp)

        $auth.signOut()

        $httpBackend.flush()


    suite 'requestPasswordReset', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'uses first config by default', ->
        $httpBackend
          .expectPOST('/api/rigel/password')
          .respond(201, {success: true})

        $auth.requestPasswordReset({
          email: validUser.email
        })

        $httpBackend.flush()


      test 'uses stored named config when present', ->
        $httpBackend
          .expectPOST('/api/cygni/password')
          .respond(201, {success: true})

        $auth.requestPasswordReset({
          email: validUser.email
        }, {
          config: 'admin'
        })

        $httpBackend.flush()


    suite 'updatePassword', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'uses stored named config', ->
        $auth.setConfigName('admin')

        $httpBackend
          .expectPUT('/api/cygni/password')
          .respond(201, {success: true})

        $auth.updatePassword({
          password: 'secret123'
          password_confirmation: 'secret123'
        })

        $httpBackend.flush()


      test 'falls back to default config name', ->
        $httpBackend
          .expectPUT('/api/rigel/password')
          .respond(201, {success: true})

        $auth.updatePassword({
          password: 'secret123'
          password_confirmation: 'secret123'
        })

        $httpBackend.flush()


    suite 'updateAccount', ->
      setup ->
        cs = $authProvider.configure([userConfig, adminConfig])

      test 'uses stored named config', ->
        $auth.setConfigName('admin')

        $httpBackend
          .expectPUT('/api/cygni')
          .respond(201, successResp)

        $auth.updateAccount({
          operating_thetan: 123
        })

        $httpBackend.flush()


      test 'falls back to default config name', ->
        $httpBackend
          .expectPUT('/api/rigel')
          .respond(201, successResp)

        $auth.updateAccount({
          operating_thetan: 123
        })

        $httpBackend.flush()
