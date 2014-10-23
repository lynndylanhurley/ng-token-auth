var Q       = require('q');
var spawn   = require('child_process').spawn;
var exec    = require('child_process').exec;
var sc      = require('sauce-connect-launcher');
var request = require('request');

// spawned processes
var testServerSpawn = null;
var scSpawn         = null;
var exitCode        = 0;

// recursively try until test server is ready. return promise.
var pingTestServer = function(host, port, dfd) {
  // ensure minimum values are provided
  if (!host) { throw "Error: test server host not provided."; }
  if (!port) { throw "Error: test server port not provided."; }

  // first run, init promise, start server
  if (!dfd) { var dfd = Q.defer(); }

  // poll dev server until it response, then resolve promise.
  request('http://'+host+':'+port, function(err) {
    if (err) {
      setTimeout(function() {
        console.log('test server failed, checking again in 100ms');
        pingTestServer(host, port, dfd);
      }, 100);
    } else {
      dfd.resolve()
    }
  });

  return dfd.promise;
};


var setSauceCreds = function() {
  var sauceConfig = {};
  try {
    var sauceConfig = require('./test/config/sauce.json')
  } catch (ex) {}

  if (!process.env.SAUCE_USERNAME) {
    if (sauceConfig.SAUCE_USERNAME) {
      process.env.SAUCE_USERNAME = sauceConfig.SAUCE_USERNAME;
    } else {
      throw "Cannot find SAUCE_USERNAME value in env or test/config/sauce.json";
    }
    }

  if (!process.env.SAUCE_ACCESS_KEY) {
    if (sauceConfig.SAUCE_ACCESS_KEY) {
      process.env.SAUCE_ACCESS_KEY = sauceConfig.SAUCE_ACCESS_KEY;
    } else {
      throw "Cannot find SAUCE_ACCESS_KEY value in env or test/config/sauce.json";
    }
  }
}

var startSauceConnect = function() {
  var dfd = Q.defer();

  setSauceCreds();

  sc({
    username:         process.env.SAUCE_USERNAME,
    accessKey:        process.env.SAUCE_ACCESS_KEY,
    verbose:          true,
    tunnelIdentifier: process.env.TRAVIS_JOB_NUMBER,
    build:            process.env.TRAVIS_BUILD_NUMBER
  }, function(err, scProcess) {
    if (err) {
      console.log('@-->sc err');
      dfd.reject();
      throw err.message;
    }

    console.log('@-->Sauce Connect ready...');
    scSpawn = scProcess;
    dfd.resolve();
  });

  return dfd.promise;
}

var startE2EServer = function(appPath, port) {
  var env = process.env;
  env.PORT = port;

  testServerSpawn = spawn('node', [appPath], {env: env});
  testServerSpawn.stdout.pipe(process.stdout);
  testServerSpawn.stderr.pipe(process.stderr);
}

var killE2EServer = function() {
  var dfd = Q.defer();

  console.log('killing e2e server');

  if (testServerSpawn) {
    testServerSpawn.on('close', function(code, signal) {
      console.log('e2e server is dead.');
      dfd.resolve();
    });
    testServerSpawn.kill('SIGTERM');
  } else {
    dfd.resolve();
  }

  return dfd.promise;
}


var runE2ETest = function(conf, browser) {
  var dfd = Q.defer();
  var env = JSON.parse(JSON.stringify(process.env));

  env.CAPABILITIES = JSON.stringify(browser);

  var protractorSpawn = spawn('protractor', [conf], {env: env});

  console.log('@-->starting e2e test for', browser.browserName, browser.version);

  // pipe output to this process
  protractorSpawn.stdout.pipe(process.stdout);
  protractorSpawn.stderr.pipe(process.stderr);

  protractorSpawn.on('exit', function(code, signal) {
    console.log('killing protractor spawn, code =', code);
    if (code !== 0) {
      console.log('@-->setting exit code to', code);
      exitCode = code;
    }

    protractorSpawn.kill(0);
    dfd.resolve();
  });

  protractorSpawn.on('close', function(code, signal) {
    console.log('protractor spawn is dead.');
  });

  return dfd.promise;
}


var killSCSpawn = function() {
  var dfd = Q.defer();
  if (scSpawn) {
    console.log('@-->Closing Sauce Connect process.');
    scSpawn.close(function() {
      console.log('@-->Sauce Connect is dead.');
      cb();
    });
    scSpawn.kill('SIGTERM');
  } else {
    console.log('@-->No Sauce Connect to kill.');
    dfd.resolve();
  }

  return dfd.promise;
}


var runE2ETestSuite = function(browsers, conf) {
  var dfd = Q.defer();

  var tests = browsers.map(function(b) {
    return function(prev) {
      return runE2ETest(conf, b);
    }
  });

  tests.push(function() {
    dfd.resolve();
  });

  tests.reduce(Q.when, Q());

  return dfd.promise;
}

var partial = function(func) {
  var args = Array.prototype.slice.call(arguments, 1);
  return function() {
    var allArguments = args.concat(Array.prototype.slice.call(arguments));
    return func.apply(this, allArguments);
  };
}

process.on('exit', function () {
  console.log('@-->exiting with code', exitCode);
  killE2EServer().then(function() { process.exit(exitCode); });
});

var testE2E = function(opts) {
  var dfd = Q.defer();

  var chain = [
    partial(startE2EServer, opts.nodeApp, opts.nodePort),
    partial(pingTestServer, opts.nodeHost, opts.nodePort),
    partial(runE2ETestSuite, opts.browsers, opts.e2EConfig),
    killE2EServer,
    killSCSpawn,
    function() { dfd.resolve(); }
  ]

  chain.reduce(Q.when, Q());

  return dfd.promise;
};

module.exports = {
  testE2E: testE2E,
  startSauceConnect: startSauceConnect
};
