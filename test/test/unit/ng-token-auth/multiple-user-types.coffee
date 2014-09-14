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
      $cookieStore.put('auth_headers', validAuthHeader)
      $httpBackend
        .expectGET('/api/vega/validate_token')
        .respond(201, successResp, validAuthHeader)

      $auth.validateUser()
      $httpBackend.flush()

    test 'signIn uses only config by default', ->
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

      $cookieStore.put('auth_headers', validAuthHeader)
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

    setup ->
      cs = $authProvider.configure([userConfig, adminConfig])

    test 'getConfig returns first ("user") config when no params specified', ->
      assert.equal(userConfig.user.signOutUrl, $auth.getConfig().signOutUrl)
      assert.equal(userConfig.user.emailSignInPath, $auth.getConfig().emailSignInPath)
      assert.equal(userConfig.user.emailRegistrationPath, $auth.getConfig().emailRegistrationPath)
      assert.equal(userConfig.user.accountUpdatePath, $auth.getConfig().accountUpdatePath)
      assert.equal(userConfig.user.accountDeletePath, $auth.getConfig().accountDeletePath)
      assert.equal(userConfig.user.accountResetPath, $auth.getConfig().accountResetPath)
      assert.equal(userConfig.user.accountUpdatePath, $auth.getConfig().accountUpdatePath)
      assert.equal(userConfig.user.tokenValidationPath, $auth.getConfig().tokenValidationPath)

    test 'getConfig returns "admin" config when specified', ->
      assert.equal(adminConfig.admin.signOutUrl, $auth.getConfig("admin").signOutUrl)
      assert.equal(adminConfig.admin.emailSignInPath, $auth.getConfig("admin").emailSignInPath)
      assert.equal(adminConfig.admin.emailRegistrationPath, $auth.getConfig("admin").emailRegistrationPath)
      assert.equal(adminConfig.admin.accountUpdatePath, $auth.getConfig("admin").accountUpdatePath)
      assert.equal(adminConfig.admin.accountDeletePath, $auth.getConfig("admin").accountDeletePath)
      assert.equal(adminConfig.admin.accountResetPath, $auth.getConfig("admin").accountResetPath)
      assert.equal(adminConfig.admin.accountUpdatePath, $auth.getConfig("admin").accountUpdatePath)
      assert.equal(adminConfig.admin.tokenValidationPath, $auth.getConfig("admin").tokenValidationPath)

    test 'default methods still work'

    suite 'authenticate', ->
      test 'uses first config by default'
      test 'uses second config when specified'

    suite 'signIn', ->
      test 'uses first config by default'
      test 'uses second config when specified'

    suite 'validateUser', ->
      test 'uses first config by default'
      test 'uses second config when specified'
      test 'uses cached named config when present'
