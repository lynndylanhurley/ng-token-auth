var Q       = require('q');
var spawn   = require('child_process').spawn;
var exec    = require('child_process').exec;
var sc      = require('sauce-connect-launcher');
var request = require('request');
var t       = require('gulp-util')
var nock    = require('nock');
var fs      = require('fs');
var path    = require('path');

// spawned processes
var testServerSpawn = null;
var scSpawn         = null;
var exitCode        = 0;
var mockApi         = null;

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
        t.log('test server failed, checking again in 100ms');
        pingTestServer(host, port, dfd);
      }, 100);
    } else {
      t.log('test server verified.');
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

  t.log('Starting', t.colors.cyan('Sauce Connect'), '...');

  sc({
    username:         process.env.SAUCE_USERNAME,
    accessKey:        process.env.SAUCE_ACCESS_KEY,
    verbose:          true,
    tunnelIdentifier: process.env.TRAVIS_JOB_NUMBER,
    build:            process.env.TRAVIS_BUILD_NUMBER
  }, function(err, scProcess) {
    if (err) {
      t.log(t.colors.red('Error:'), 'Sauce connect failed to start:', t.colors.cyan(err.message));
      dfd.reject();
      throw err.message;
    }

    t.log(t.colors.cyan('Sauce Connect'), 'started.');
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

  t.log('Killing',  t.colors.cyan('E2E Server'));

  if (testServerSpawn) {
    testServerSpawn.on('close', function(code, signal) {
      t.log(t.colors.cyan('E2E server'), 'is dead.');
      dfd.resolve();
    });
    testServerSpawn.kill('SIGTERM');
  } else {
    dfd.resolve();
  }

  return dfd.promise;
}


var runE2ETest = function(conf, browser, specs, port) {
  var dfd = Q.defer();
  var env = JSON.parse(JSON.stringify(process.env));

  env.CAPABILITIES = JSON.stringify(browser);
  env.SPECS        = JSON.stringify(specs);
  env.TEST_PORT    = JSON.stringify(port);

  var protractorSpawn = spawn('protractor', [conf], {env: env});

  // pipe output to this process
  protractorSpawn.stdout.pipe(process.stdout);
  protractorSpawn.stderr.pipe(process.stderr);

  protractorSpawn.on('exit', function(code, signal) {
    t.log('Killing protractor spawn with exit code', t.colors.red(code));
    if (code !== 0) {
      t.log(t.colors.red('Failure detected.'), 'This process will fail with code', t.colors.red(code));
      exitCode = code;
    }

    protractorSpawn.kill(0);
    dfd.resolve();
  });

  protractorSpawn.on('close', function(code, signal) {
    t.log('protractor spawn is dead.');
  });

  return dfd.promise;
}


var killSCSpawn = function() {
  var dfd = Q.defer();
  if (scSpawn) {
    t.log('@-->Closing Sauce Connect process.');
    scSpawn.close(function() {
      t.log('@-->Sauce Connect is dead.');
      cb();
    });
    scSpawn.kill('SIGTERM');
  } else {
    t.log('@-->No Sauce Connect to kill.');
    dfd.resolve();
  }

  return dfd.promise;
}


var runE2ETestSuite = function(browsers, conf, specs, port) {
  var dfd = Q.defer();
  var tests = [];

  if (browsers) {
    tests = tests.concat(browsers.map(function(b) {
      return function(prev) {
        return runE2ETest(conf, b, specs, port);
      }
    }));
  } else {
    tests.push(function(prev) {
      return runE2ETest(conf, null, specs, port)
    });
  }

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


var testE2E = function(opts) {
  var dfd = Q.defer();

  var chain = [
    partial(pingTestServer, opts.nodeHost, opts.nodePort),
    partial(runE2ETestSuite, opts.browsers, opts.e2EConfig, opts.specs, opts.nodePort),
    killE2EServer,
    killSCSpawn,
    function() { dfd.resolve(); }
  ];


  // start sauce connect?
  if (opts.startSauceConnect) {
    chain.unshift(startSauceConnect);
  } else {
    t.log(t.colors.cyan('startSauceConnect'), 'is false. Bypassing sauce connect server.');
  }

  // start node server if defined
  if (opts.nodeApp) {
    chain.unshift(partial(startE2EServer, opts.nodeApp, opts.nodePort));
  } else {
    t.log(t.colors.cyan('nodeApp'), 'option not found. Bypassing node server.');
  }

  // TODO: define condition for this
  // record API calls for CI mocks
  if (true) {
    nock.recorder.rec({
      output_objects: true
    });

    chain.push(function() {
      var dfd = Q.defer();
      var fpath = path.resolve(process.cwd(), 'mock-api.json');

      console.log('@-->fpath', fpath);

      fs.writeFile(fpath, JSON.stringify(nock.recorder.play()), function(err) {
        if (err) {
          throw err.message;
        } else {
          console.log('@-->nock file saved');
          dfd.resolve();
        }
      });

      return dfd.promise;
    });
  }

  chain.reduce(Q.when, Q());

  return dfd.promise;
};


process.on('exit', function () {
  t.log('@-->exiting with code', exitCode);
  killE2EServer().then(function() { process.exit(exitCode); });
});


module.exports = {
  testE2E:           testE2E,
  startSauceConnect: startSauceConnect
};
